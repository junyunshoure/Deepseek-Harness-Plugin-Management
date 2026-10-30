'use strict';
/**
 * DeepSeek Harness 插件整合包 v2.1.2 —— 安装器核心（Windows）
 *
 * 设计原则
 *  1. 绝不联网：所有插件依赖已在 payload/node_modules 里，逐个用官方 `plugin add --offline` 挂载。
 *  2. 绝不覆盖用户在用的东西：默认 --mode merge，已存在的同名包一律跳过；配置默认只补缺。
 *  3. 一切可回滚：每次安装都在 store/backups/<时间戳>/ 留配置与依赖快照，ROLLBACK.cmd 可原样退回。
 *  4. 失败可见：任何一步失败都打印中文原因 + 已完成的步骤 + 备份路径，并写 last-result.json。
 *
 * 用法（一般由 INSTALL.cmd / VERIFY.cmd / DOCTOR.cmd / ROLLBACK.cmd 调用）：
 *   node install-helper.cjs --desktop-dir <目录> [--mode new|merge|backup|upgrade|repair] [--with-services]
 *        [--no-launch] [--force-config] [--check-only] [--rollback <备份目录>] [--yes]
 *        [--doctor] [--uninstall] [--services-only] [--prune-old [--keep-days N]]
 *        [--write-appendix] [--skip-appendix] [--skip-cleanup]
 *
 * v2.1.0 一键行为：install / upgrade / repair 装完会**自动**把「深度档位 + 对齐协议」
 * 写进 <DSH_HOME>/AGENTS.md（幂等、保留用户已设的 DEPTH_MODE、写前备份），
 * 并做与数据无关的安全清理。不需要用户再手动跑 MAINTAIN.cmd。
 *
 * v2.1.0 新增两种模式（依据 _probe-v2.1.0 的实测结论，见 docs/升级与维护.md）：
 *   upgrade  —— 已装过旧版整合包时用：把 6 个本地插件从旧载荷目录重指向新载荷目录。
 *               实测结论：同名包二次 add 就是就地覆盖，不需要先 remove；旧链接残留不删，
 *               所以本模式在收尾时逐个核对 profile/node_modules 链接指向并给出重定向表。
 *   repair   —— 链接断了 / 载荷被移动后用：只重挂已声明的包，不新增、不删除任何依赖。
 *
 * v2.1.2 修的是 v2.1.1 里一处「自毁式断言」：启停状态快照 dsh-migration-plugin-state 被并进
 * 统一的 targets 列表后，两处收尾校验（挂载后校验 / upgrade 后 bundle 核对）拿它去比
 * profile.bundles，而它按设计不进 bundles —— 于是 33/33 全挂好、条目组合也通过，收尾仍判
 * 「bundle 未启用」并以 exit 1 结束：用户看到「升级失败」，载荷却已经是新目录。
 * 本版把真插件与状态快照分开存（pluginTargets / stateTargets），断言各看各的数组。
 * 另外三处顺手修：① 在持久目录里原地 repair 被「目录重叠」检查挡住；② EPERM 技能写入
 * 失败只说「没能写入」、不给动作；③ GUI 已在运行时安装器仍死等 120 秒端口。
 */
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { spawn, spawnSync } = require('node:child_process');
const { pathToFileURL } = require('node:url');

const ROOT = __dirname;
const readJson = p => JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
const sha256 = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const log = (...a) => console.log(...a);
const warn = (...a) => console.warn(...a);
const die = m => { throw new Error(m); };
const stamp = () => new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);

const argv = process.argv.slice(2);
const flag = k => argv.includes(k);
const opt = (k, d) => { const i = argv.indexOf(k); return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : d; };

function copyTree(from, to) {
  fs.mkdirSync(to, { recursive: true });
  for (const e of fs.readdirSync(from, { withFileTypes: true })) {
    const s = path.join(from, e.name), d = path.join(to, e.name);
    if (e.isSymbolicLink()) continue;
    if (e.isDirectory()) copyTree(s, d);
    else if (e.isFile()) fs.copyFileSync(s, d);
  }
}

/**
 * 把一份 patch 文件切成顶层条目块。
 * 顶层条目 = 行首 `- `（不含缩进）；`- insert:` 这类块整体算一条，内部 id 一起收集。
 * 注释与空行跟随其后的条目，保持原格式，不重写用户已有的文字。
 */
function splitPatchBlocks(text) {
  const lines = text.replace(/^\uFEFF/, '').split(/\r?\n/);
  const blocks = [];
  let cur = null;
  for (const line of lines) {
    if (/^- /.test(line)) {
      if (cur) blocks.push(cur);
      cur = { lines: [line], ids: [] };
    } else if (cur) {
      cur.lines.push(line);
    }
  }
  if (cur) blocks.push(cur);
  for (const b of blocks) {
    for (const l of b.lines) {
      const m = /^\s*-\s*id:\s*['"]?([^'"\s]+)['"]?\s*$/.exec(l) || /^\s*id:\s*['"]?([^'"\s]+)['"]?\s*$/.exec(l);
      if (m) b.ids.push(m[1]);
    }
    b.text = b.lines.join('\n').replace(/\s+$/, '');
    // 顶层 `- id: x` 条目只看它自己的 id；`- insert:` 这类块看内部全部 id
    b.key = /^- id:/.test(b.text) && b.ids.length ? [b.ids[0]] : b.ids;
  }
  return blocks;
}

/**
 * v2.1.1：这些 id 的 config 是「别人机器上的状态」，合并进用户 profile 会覆盖掉他自己的配置。
 *  - llm-pi-ai / llm-deepseek / agent-default-model：模型通道与默认模型，占位骨架会把用户能用的模型顶掉
 *  - ui-theme / web-ui-pet / ui-settings-account / ui-chat / ui-settings：外观、宠物坐标、界面进度状态
 */
const SENSITIVE_PATCH_IDS = new Set([
  'llm-pi-ai', 'llm-deepseek', 'agent-default-model',
  'ui-theme', 'web-ui-pet', 'ui-settings-account', 'ui-chat', 'ui-settings',
]);

/** 把 src 里 dst 还没有的条目追加到 dst 末尾；返回追加的 id 列表。 */
function mergePatchFile(srcFile, dstFile) {
  const src = splitPatchBlocks(fs.readFileSync(srcFile, 'utf8'));
  const dstText = fs.existsSync(dstFile) ? fs.readFileSync(dstFile, 'utf8') : '';
  const dst = splitPatchBlocks(dstText);
  const have = new Set(dst.flatMap(b => b.key));
  // v2.1.1：模型 / 外观 / 个人状态类条目一律不追加（见 SENSITIVE_PATCH_IDS 注释）。
  const sensitive = src.filter(b => b.key.length && b.key.some(id => SENSITIVE_PATCH_IDS.has(id)));
  const missing = src.filter(b => b.key.length && b.key.every(id => !have.has(id)) && b.key.every(id => !SENSITIVE_PATCH_IDS.has(id)));
  const added = missing.flatMap(b => b.key);
  if (sensitive.length) {
    warn('· 跳过 ' + sensitive.length + ' 条模型/外观类条目（合并会覆盖你自己的配置）：' + sensitive.map(b => b.key.join('+')).join('、'));
  }
  if (!missing.length) return added;
  const header = [
    '',
    '# === 以下条目由插件整合包 v2.1.2 追加（你的原有条目一条没动） ===',
    '# 想撤销：删掉这一整段，或跑 ROLLBACK.cmd 回到安装前。',
    '',
  ].join('\n');
  const body = missing.map(b => b.text).join('\n');
  const next = (dstText.replace(/\s*$/, '') + '\n' + header + body + '\n');
  fs.writeFileSync(dstFile, next, 'utf8');
  return added;
}

function verifyFiles(base, quiet) {
  const sums = readJson(path.join(base, 'checksums.json'));
  let n = 0;
  const rootAbs = path.resolve(base);
  for (const item of sums.files) {
    const f = path.resolve(rootAbs, item.path);
    if (!f.startsWith(rootAbs + path.sep)) die('校验清单里出现越界路径：' + item.path);
    if (!fs.existsSync(f)) die('缺少文件（包可能没有完整解压，或解压工具丢了长路径文件）：' + item.path);
    if (sha256(f) !== item.sha256) die('文件内容与校验清单不符（下载或解压损坏）：' + item.path);
    n++;
  }
  if (!quiet) log('✓ SHA-256 完整性校验通过：' + n + ' 个文件');
  return n;
}

function assertPayloadDeps(store) {
  const nmRoot = path.join(store, 'payload', 'node_modules');
  if (!fs.existsSync(nmRoot)) return 0;
  const pkgs = [];
  for (const ent of fs.readdirSync(nmRoot, { withFileTypes: true })) {
    const p = path.join(nmRoot, ent.name);
    if (ent.name.startsWith('@')) {
      let subs = [];
      try { subs = fs.readdirSync(p, { withFileTypes: true }); } catch { subs = []; }
      for (const s2 of subs) pkgs.push({ name: ent.name + '/' + s2.name, dir: path.join(p, s2.name) });
    } else if (ent.isDirectory()) {
      pkgs.push({ name: ent.name, dir: p });
    }
  }
  const resolvable = (fromDir, dep) => {
    let cur = fromDir;
    for (let i = 0; i < 8; i++) {
      if (fs.existsSync(path.join(cur, 'node_modules', ...dep.split('/')))) return true;
      const up = path.dirname(cur);
      if (up === cur) break;
      cur = up;
    }
    return fs.existsSync(path.join(nmRoot, ...dep.split('/')));
  };
  const missing = [];
  for (const it of pkgs) {
    const pj = path.join(it.dir, 'package.json');
    if (!fs.existsSync(pj)) continue;
    let meta;
    try { meta = JSON.parse(fs.readFileSync(pj, 'utf8').replace(/^\uFEFF/, '')); } catch { continue; }
    for (const dep of Object.keys(meta.dependencies || {})) {
      if (!resolvable(it.dir, dep)) missing.push(it.name + ' → ' + dep);
    }
  }
  if (missing.length) {
    die('载荷依赖不完整（' + missing.length + ' 处缺失，装上也会在运行时报 MODULE_NOT_FOUND）：\n  '
      + missing.slice(0, 12).join('\n  ')
      + (missing.length > 12 ? '\n  …另有 ' + (missing.length - 12) + ' 处' : '')
      + '\n这通常是解压时丢了长路径文件：请用 7-Zip 重新解压整个包后再装。');
  }
  log('✓ 载荷依赖闭包完整（' + pkgs.length + ' 个包全部可解析）');
  return pkgs.length;
}

function semverOk(version, range) {
  const m = /^(\d+)\.(\d+)\./.exec(String(version));
  if (!m) return false;
  const maj = Number(m[1]), min = Number(m[2]);
  const r = /^>=(\d+)\.(\d+)\.\d+\s+<(\d+)\.(\d+)\.\d+$/.exec(range);
  if (!r) return true;
  const cmp = (a, b, c, d) => (maj > a || (maj === a && min >= b)) && (maj < c || (maj === c && min < d));
  return cmp(Number(r[1]), Number(r[2]), Number(r[3]), Number(r[4]));
}

function locate(desktop) {
  const exe = path.join(desktop, 'DeepSeek Harness.exe');
  const app = path.join(desktop, 'resources', 'app.asar', 'dsh');
  const bootPkg = path.join(app, 'node_modules', '@deepseek-ai', 'dsh-app-boot', 'package.json');
  const cli = path.join(app, 'node_modules', '@deepseek-ai', 'dsh-desktop-host', 'lib', 'cli.js');
  if (!fs.existsSync(exe)) die('这个目录里没有 DeepSeek Harness.exe，请选择 Desktop 的安装目录（不是 resources 目录）。');
  if (!fs.existsSync(bootPkg)) die('没有找到 Desktop 内核文件（resources/app.asar/dsh）。请确认安装的是 DeepSeek Harness 桌面版 0.2.x。');
  if (!fs.existsSync(cli)) die('没有找到官方插件安装器（dsh-desktop-host/lib/cli.js），内核版本可能不匹配。');
  return { exe, app, cli, version: readJson(bootPkg).version };
}

function findDesktopDir(given, required = true) {
  if (given && fs.existsSync(given)) return path.resolve(given);
  const cands = [
    path.join(process.env.LOCALAPPDATA || '', 'Programs', 'DeepSeek Harness'),
    path.join(process.env.PROGRAMFILES || '', 'DeepSeek Harness'),
    path.join(os.homedir(), 'AppData', 'Local', 'Programs', 'DeepSeek Harness'),
  ].filter(Boolean);
  for (const c of cands) if (fs.existsSync(path.join(c, 'DeepSeek Harness.exe'))) return c;
  if (!required) return '';
  die('没有自动找到 DeepSeek Harness 安装目录。请用 INSTALL.cmd 的“手动指定目录”方式，或加 --desktop-dir 参数。');
}

function writeResult(payload) {
  try {
    const dir = path.join(process.env.LOCALAPPDATA || os.tmpdir(), 'DSHPluginsPack');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'last-result.json'), JSON.stringify(payload, null, 2));
  } catch { /* 写不了就算了，不影响安装 */ }
}

// ======================================================================
// v2.1.0 一键：AGENTS.md 对齐协议自动写入 + 安全清理
//   目标：INSTALL / UPGRADE / REPAIR 装完自动把「深度档位 + 对齐协议」写进
//   <DSH_HOME>/AGENTS.md，不需要用户再手动跑 MAINTAIN.cmd。
//   也可用 --write-appendix 单独执行（macOS 侧复用同一实现）。
//   设计约束（见 docs/新功能说明.md）：
//     1. 幂等：同一输入跑两遍，文件字节不变，不产生第二个块。
//     2. 尊重用户：块内 DEPTH_MODE 的值从旧文件里读出来沿用，不被重置成默认值。
//     3. 迁移：老版本把档位段写在块外时，收进块内，避免出现两份 DEPTH_MODE。
//     4. 可回滚：内容有变化才写；写前留 .bak-<时间戳>；写后自检标记各 1 个，不合格自动回退。
// ======================================================================
const DEPTH_MODES = ['ask', 'auto', 'deep', 'fast'];
const APPX_START_RE = /^\s*<!--\s*ALIGNMENT_PROTOCOL\s+v1\.0\s+START/;
const APPX_END_RE = /^\s*<!--\s*ALIGNMENT_PROTOCOL\s+v1\.0\s+END\s*-->\s*$/;
const DEPTH_H1 = '# 全局指令：深度档位';
const PROTECTED_DIR_RE = /[\\/](node_modules|\.git|skills|sessions|services|cache|storage|data|extensions|bin)([\\/]|$)/i;

function appendixTemplate() {
  const f = path.join(ROOT, 'appendix', 'AGENTS.appendix.md');
  if (!fs.existsSync(f)) die('包里缺少 appendix/AGENTS.appendix.md，无法写入对齐协议（可加 --skip-appendix 跳过）。');
  return fs.readFileSync(f, 'utf8').replace(/^\uFEFF/, '');
}

function findAppxBlock(lines) {
  let start = -1, end = -1, startCount = 0, endCount = 0;
  for (let i = 0; i < lines.length; i++) {
    if (APPX_START_RE.test(lines[i])) { startCount++; if (start < 0) start = i; }
    if (APPX_END_RE.test(lines[i])) { endCount++; if (end < 0) end = i; }
  }
  return { start, end, startCount, endCount };
}

function pickDepthMode(text) {
  const m = text.match(/^[ \t]*##[ \t]*DEPTH_MODE:[ \t]*([A-Za-z]+)[ \t]*$/m);
  if (m) {
    const v = m[1].toLowerCase();
    if (DEPTH_MODES.includes(v)) return v;
  }
  return 'ask';
}

// 老版本把「深度档位」整段写在标记块外（段内没有第二个一级标题），
// 这里把它从块外剪掉，值随后并入块内。剪的范围绝不跨进标记块。
function stripOutsideDepthSection(lines, block) {
  const inBlock = i => (block.start >= 0 && block.end >= block.start && i >= block.start && i <= block.end);
  let h1 = -1;
  for (let i = 0; i < lines.length; i++) {
    if (inBlock(i)) continue;
    if (lines[i].trimStart().startsWith(DEPTH_H1)) { h1 = i; break; }
  }
  if (h1 < 0) return { lines, removed: 0 };
  const limit = (block.start >= 0 && block.start > h1) ? block.start : lines.length;
  let stop = limit;
  for (let i = h1 + 1; i < limit; i++) {
    if (inBlock(i)) continue;
    if (lines[i].startsWith('# ')) { stop = i; break; }
  }
  return { lines: lines.slice(0, h1).concat(lines.slice(stop)), removed: stop - h1 };
}

function writeAgentsAppendix(opts) {
  const o = opts || {};
  if (!o.home) die('内部错误：writeAgentsAppendix 缺少 home。');
  const home = path.resolve(o.home);
  const file = path.join(home, 'AGENTS.md');
  const tpl = appendixTemplate();
  const res = {
    ok: true, file, mode: 'none', depthMode: 'ask', linesBefore: 0, linesAfter: 0,
    changed: false, backup: null, migratedOutsideLines: 0, hint: '',
  };

  let raw = '', hadBom = false;
  if (fs.existsSync(file)) {
    raw = fs.readFileSync(file, 'utf8');
    if (raw.charCodeAt(0) === 0xFEFF) { hadBom = true; raw = raw.slice(1); }
  }
  const eol = raw === '' ? '\r\n' : (raw.includes('\r\n') ? '\r\n' : '\n');
  res.linesBefore = raw === '' ? 0 : raw.split(/\r?\n/).length;
  res.depthMode = pickDepthMode(raw);

  let lines = raw === '' ? [] : raw.split(/\r?\n/);
  let block = findAppxBlock(lines);
  if (block.startCount !== block.endCount || block.startCount > 1) {
    res.ok = false;
    res.mode = 'skipped-multi-block';
    res.hint = 'AGENTS.md 里有 ' + block.startCount + ' 个 START 标记、' + block.endCount + ' 个 END 标记（应当各 1 个）：'
      + '请手工清理到各 1 个后重跑，或加 --skip-appendix 跳过这一步。';
    return res;
  }

  const stripped = stripOutsideDepthSection(lines, block);
  if (stripped.removed > 0) {
    lines = stripped.lines;
    res.migratedOutsideLines = stripped.removed;
    block = findAppxBlock(lines);
  }

  const blockLines = tpl.replace(/\{\{DEPTH_MODE\}\}/g, res.depthMode).split(/\r?\n/);
  while (blockLines.length && blockLines[blockLines.length - 1].trim() === '') blockLines.pop();
  if (!blockLines.length) die('appendix 模板是空的，无法写入。');

  let mode;
  if (block.start >= 0 && block.end > block.start) {
    lines = lines.slice(0, block.start).concat(blockLines, lines.slice(block.end + 1));
    mode = 'replaced';
  } else {
    while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();
    lines = (lines.length ? lines.concat(['']) : []).concat(blockLines);
    mode = 'appended';
  }
  while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();

  const out = lines.join(eol) + eol;
  res.linesAfter = lines.length;
  if (out === raw) {
    res.mode = 'unchanged';
    return res;
  }
  res.changed = true;
  res.mode = mode;

  if (fs.existsSync(file)) {
    const bk = file + '.bak-' + stamp();
    fs.copyFileSync(file, bk);
    res.backup = bk;
  }
  fs.mkdirSync(home, { recursive: true });
  fs.writeFileSync(file, (hadBom ? '\uFEFF' : '') + out, 'utf8');

  const back = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/);
  const vb = findAppxBlock(back);
  if (vb.startCount !== 1 || vb.endCount !== 1) {
    if (res.backup) fs.copyFileSync(res.backup, file);
    else fs.rmSync(file, { force: true });
    res.ok = false;
    res.mode = 'verify-failed';
    res.changed = false;
    res.hint = '写完自检发现标记不是各 1 个，已回退到原文件（备份：' + (res.backup || '无') + '）。';
    return res;
  }
  return res;
}

// 只做与数据无关的安全清理：临时文件、轮转日志残留、第一层空目录。
// 废弃包 / 用户环境变量一律只报告不删（删包会误伤仍在用的依赖）。
function safeCleanup(opts) {
  const o = opts || {};
  const home = path.resolve(o.home);
  const out = { tmpRemoved: [], rotatedLogs: [], emptyDirs: [], bigLogs: [], failed: [], bytesReclaimed: 0 };
  const DAY = 86400000, now = Date.now();

  const scanFiles = (dir, depth) => {
    if (depth > 3) return;
    let ents;
    try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of ents) {
      const p = path.join(dir, e.name);
      if (e.isSymbolicLink()) continue;
      if (e.isDirectory()) { if (!PROTECTED_DIR_RE.test(p)) scanFiles(p, depth + 1); continue; }
      if (!e.isFile()) continue;
      let st;
      try { st = fs.statSync(p); } catch { continue; }
      const isTmp = /\.tmp$/i.test(e.name) && now - st.mtimeMs > DAY;
      const isRot = /\.log\.\d+$/i.test(e.name) && st.size > 10 * 1048576 && now - st.mtimeMs > DAY;
      if (isTmp || isRot) {
        try {
          fs.rmSync(p, { force: true });
          out.bytesReclaimed += st.size;
          (isTmp ? out.tmpRemoved : out.rotatedLogs).push(p);
        } catch { out.failed.push(p); }
      } else if (/\.log$/i.test(e.name) && st.size > 100 * 1048576) {
        out.bigLogs.push(p + '（' + (st.size / 1048576).toFixed(1) + ' MB）');
      }
    }
  };
  scanFiles(home, 0);

  const bases = [home];
  const profilesDir = path.join(home, 'profiles');
  if (fs.existsSync(profilesDir)) {
    for (const e of fs.readdirSync(profilesDir, { withFileTypes: true })) {
      if (e.isDirectory()) bases.push(path.join(profilesDir, e.name));
    }
  }
  for (const base of bases) {
    if (out.emptyDirs.length >= 20) break;
    let ents;
    try { ents = fs.readdirSync(base, { withFileTypes: true }); } catch { continue; }
    for (const e of ents) {
      if (!e.isDirectory() || e.isSymbolicLink()) continue;
      const p = path.join(base, e.name);
      if (PROTECTED_DIR_RE.test(p)) continue;
      try {
        if (fs.readdirSync(p).length === 0) { fs.rmdirSync(p); out.emptyDirs.push(p); }
      } catch { /* 占用或权限不足，跳过 */ }
    }
  }
  return out;
}

function writeAppendixMode() {
  const home = path.resolve(process.env.DSH_HOME || path.join(os.homedir(), '.dsh'));
  if (!fs.existsSync(home)) {
    die('没有找到 DSH 数据目录：' + home + '\n请先打开一次 DeepSeek Harness 让它初始化，再重试。');
  }
  const r = writeAgentsAppendix({ home });
  log('AGENTS 文件：' + r.file);
  if (!r.ok) { warn('! ' + (r.hint || '写入失败')); process.exitCode = 1; return; }
  log('✓ 对齐协议：' + (r.mode === 'unchanged' ? '已是最新内容（未改动）' : r.mode === 'replaced' ? '已更新标记块' : '已追加标记块'));
  log('· DEPTH_MODE：' + r.depthMode + '（可选 ask / auto / deep / fast，直接改那一行即可）');
  log('· 当前 ' + r.linesAfter + ' 行' + (r.migratedOutsideLines ? '，块外 ' + r.migratedOutsideLines + ' 行旧档位段已并入块内' : ''));
  if (r.backup) log('· 原文件已备份：' + r.backup);
  log('· 新开一个 DSH 会话即生效（当前会话不会重读 AGENTS.md）。');
}

// ------------------------------------------------------------------ 主流程
(async () => {
  const spec = readJson(path.join(ROOT, 'migration.json'));
  const result = { pack: spec.version, id: spec.id, startedAt: new Date().toISOString(), steps: [], ok: false };

  // ---------- 分派：诊断 / 回滚 / 卸载 / 只装服务 ----------
  if (flag('--doctor')) return doctorMode(spec);
  if (flag('--rollback')) return rollbackMode(spec, opt('--backup', ''));
  if (flag('--uninstall')) return uninstallMode(spec);
  if (flag('--services-only')) return servicesMode(spec);
  if (flag('--prune-old')) return pruneOldStores(spec);
  if (flag('--write-appendix')) return writeAppendixMode();

  // ---------- 平台 ----------
  if (process.platform !== 'win32' || process.arch !== 'x64') {
    die('本包是 Windows x64 版。macOS 请使用 macos/install.command（见 macos/INSTALL-MAC.md）。');
  }

  // ---------- 校验包 ----------
  if (!flag('--skip-verify')) verifyFiles(ROOT, flag('--check-only'));
  if (flag('--check-only')) {
    const target = findDesktopDir(opt('--desktop-dir'), false);
    if (target) {
      const d = locate(target);
      log('✓ 目标内核版本：' + d.version);
    } else {
      log('✓ 没有找到 DeepSeek Harness（不影响包校验；安装时再指定安装目录即可）。');
    }
    const inv = readJson(path.join(ROOT, 'inventory.json'));
    log('✓ 本包版本：' + spec.version + '，插件包数：' + spec.packages.length + '，技能：' + (spec.skills || []).length);
    log('✓ 载荷：' + inv.counts.payloadFiles + ' 个文件 / ' + (inv.counts.payloadBytes / 1048576).toFixed(2) + ' MB（完整载荷：只跳过 ' +
      inv.counts.trimmedFiles + ' 个构建缓存文件 / ' + (inv.counts.trimmedBytes / 1048576).toFixed(2) + ' MB，依赖一个都没裁）');
    log('✓ 内核门禁：' + spec.kernel.required + '（0.2.x / 0.3.x 均放行，与本包基准不同只提示不阻断）');
    log('✓ 只做校验，未改动任何文件。');
    return;
  }

  const desktop = findDesktopDir(opt('--desktop-dir'));
  const k = locate(desktop);
  log('目标 Desktop：' + desktop);
  log('内核版本：' + k.version + '（本包构建基准 ' + spec.kernel.recorded + '）');

  if (!semverOk(k.version, spec.kernel.required) && !flag('--force-kernel')) {
    die('内核版本 ' + k.version + ' 不在本包支持范围（' + spec.kernel.required + '）内。\n' +
      '· 若你的内核更新/更旧：把本包与 docs/AI-agent-适配指南.md 一起交给 DSH 里的 AI agent，让它自主适配。\n' +
      '· 强行尝试可加 --force-kernel，但不保证插件全部可用。');
  }
  if (k.version !== spec.kernel.recorded) {
    warn('⚠ 内核与构建基准不同（' + k.version + ' ≠ ' + spec.kernel.recorded + '）：安装会继续，个别插件可能需要 AI agent 适配。');
  }

  // ---------- 目标 profile ----------
  const home = path.resolve(process.env.DSH_HOME || path.join(os.homedir(), '.dsh'));
  const profile = path.join(home, 'profiles', 'desktop');
  const manifestFile = path.join(profile, 'package.json');
  if (!fs.existsSync(manifestFile)) {
    die('没有找到 Desktop 的 profile（' + profile + '）。\n请先双击打开一次 DeepSeek Harness，等主界面出来后从托盘完全退出，再重新运行本安装器。');
  }
  const before = readJson(manifestFile);
  const beforeBundles = (before.dsh && before.dsh.profile && before.dsh.profile.bundles) || [];
  if (!['@deepseek-ai/dsh-base', '@deepseek-ai/dsh-web-app'].every(n => beforeBundles.includes(n))) {
    die('这个 profile 不是标准 Desktop profile（缺少基础 bundle）。请先打开一次同版 Desktop 完成初始化。');
  }
  const packNames = spec.packages.map(p => p.name).concat(spec.stateBundle);
  const existingBundles = beforeBundles.filter(n => !spec.builtinBundles.includes(n));
  const existingDeps = Object.keys(before.dependencies || {});
  const foreignDeps = existingDeps.filter(n => !packNames.includes(n));
  const foreignBundles = existingBundles.filter(n => !packNames.includes(n));

  // ---------- 安装模式 ----------
  let mode = opt('--mode');
  const hasForeign = foreignDeps.length > 0 || foreignBundles.length > 0;
  if (!mode) {
    if (!hasForeign) mode = 'new';
    else if (flag('--yes')) mode = 'merge';
    else {
      log('');
      log('目标 profile 里已经有别的东西：');
      if (foreignBundles.length) log('  · bundle：' + foreignBundles.join(', '));
      if (foreignDeps.length) log('  · 依赖：' + foreignDeps.join(', '));
      log('');
      die('请先选择安装方式：A 全新安装（要求空壳） / B 智能合并（推荐） / C 备份后覆盖。\n' +
        '用 INSTALL.cmd 会出现选择菜单；直接运行时加 --mode new|merge|backup。');
    }
  }
  if (!['new', 'merge', 'backup', 'upgrade', 'repair'].includes(mode)) die('未知安装模式：' + mode);
  if (mode === 'new' && hasForeign) {
    die('选的是“全新安装”，但目标 profile 已有其他插件（' + foreignDeps.length + ' 个依赖 / ' + foreignBundles.length + ' 个 bundle）。\n' +
      '请改用 B 智能合并（--mode merge）或 C 备份后覆盖（--mode backup）。');
  }
  log('安装模式：' + ({ new: 'A 全新安装', merge: 'B 智能合并', backup: 'C 备份后覆盖', upgrade: 'D 升级（重指向新载荷）', repair: 'E 修复（重挂已声明插件）' })[mode]);
  result.mode = mode;

  // ---------- 持久目录 ----------
  const defaultStore = path.join(process.env.LOCALAPPDATA || os.tmpdir(), 'DSHPluginsPack', 'v' + spec.version + '-windows');
  const store = path.resolve(opt('--store', defaultStore));
  // v2.1.2：ROOT === store 是「在持久目录里原地 repair」的合法形态（下面复制分支会整段跳过），
  // 旧判断把它和「解压目录套在持久目录里」混为一谈，导致升级失败后再也救不回来。
  if (ROOT !== store && (store.startsWith(ROOT + path.sep) || ROOT.startsWith(store + path.sep))) die('持久安装目录不能与解压目录重叠，请换一个目录。');
  if (store === home || store.startsWith(home + path.sep)) die('持久安装目录不能放在 DSH 数据目录里，请换一个目录。');

  // ---------- 旧载荷探测（v2.1.0） ----------
  // 载荷目录名带版本号，换版本后 6 个本地插件的 link: 会指向不存在的旧路径 —— 这就是升级失效的根因。
  // 这里先把找到的旧载荷列出来，upgrade 模式据此给出「旧 → 新」重定向表。
  const oldStores = listStores().filter(s => path.resolve(s.dir) !== path.resolve(store));
  if (oldStores.length) {
    log('');
    log('发现其它版本的载荷目录（旧载荷不会自动删，保留 ' + (opt('--keep-days', '7')) + ' 天可用 --prune-old 清理）：');
    for (const s of oldStores) log('  · ' + s.name + '  ' + s.dir + '  （' + s.files + ' 个文件）');
  }
  if (mode === 'upgrade' && !oldStores.length) {
    warn('· 没找到旧版本载荷目录，upgrade 会按「重新指向本包载荷」执行，效果等同于 repair。');
  }

  for (const [name, value] of Object.entries(before.dependencies || {})) {
    if (!spec.packages.some(p => p.name === name) && name !== spec.stateBundle) continue;
    const expect = path.join(store, 'payload', 'node_modules', ...name.split('/'));
    const okTarget = value === 'link:' + expect.replaceAll('\\', '/') || value === 'link:' + expect;
    if (!okTarget && mode !== 'backup') {
      // 已存在同名包但指向别处（例如另一份整合包 / 用户自己装的）。这里只是预演提示，措辞按模式区分，
      // 免得 upgrade 模式下打印「跳过」让人误以为不会重指向（实际下面会逐个重挂）。
      const verb = (mode === 'upgrade' || mode === 'repair') ? '将重指向载荷' : '本模式下跳过';
      warn('· 已存在同名包指向其他目录，' + verb + '：' + name);
    }
  }

  // ---------- 复制到持久目录 ----------
  if (path.resolve(ROOT) !== store) {
    log('复制到持久目录：' + store);
    fs.mkdirSync(store, { recursive: true });
    const marker = path.join(store, 'migration.json');
    if (fs.existsSync(marker) && readJson(marker).id !== spec.id) die('这个持久目录属于另一个整合包，请换目录或先清理。');
    // 已存在的 payload 先删掉，避免新旧混装
    const oldPayload = path.join(store, 'payload');
    if (fs.existsSync(oldPayload)) {
      try {
        fs.rmSync(oldPayload, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
      } catch (e) {
        const park = path.join(store, 'payload.old-' + Date.now());
        warn('· 旧 payload 删不干净（' + (e && e.code) + '），先改名让路：' + park);
        fs.renameSync(oldPayload, park);
      }
    }
    for (const e of fs.readdirSync(ROOT, { withFileTypes: true })) {
      if (e.name === 'backups' || e.name === 'payload') continue;
      const s = path.join(ROOT, e.name), d = path.join(store, e.name);
      if (e.isDirectory()) copyTree(s, d); else if (e.isFile()) fs.copyFileSync(s, d);
    }
    copyTree(path.join(ROOT, 'payload'), path.join(store, 'payload'));
    verifyFiles(store, true);
    assertPayloadDeps(store);
    log('✓ 复制完成并通过校验');
  } else {
    log('已在持久目录内运行：' + store);
    assertPayloadDeps(store);
  }
  result.store = store;
  result.steps.push('copy-payload');

  // ---------- 备份 ----------
  const backup = path.join(store, 'backups', stamp());
  fs.mkdirSync(backup, { recursive: true });
  const cfgFiles = ['package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml', 'cordis.yml', 'cordis.patch.yml'];
  for (const f of cfgFiles) if (fs.existsSync(path.join(profile, f))) fs.copyFileSync(path.join(profile, f), path.join(backup, f));
  fs.writeFileSync(path.join(backup, 'deps-before.json'), JSON.stringify({
    at: new Date().toISOString(), mode,
    dependencies: before.dependencies || {},
    bundles: beforeBundles,
  }, null, 2));
  log('✓ 安装前备份：' + backup);
  result.backup = backup;

  // ---------- 挂载内核自带的 4 个 bundle ----------
  const boot = await import(pathToFileURL(path.join(k.app, 'node_modules', '@deepseek-ai', 'dsh-app-boot', 'lib', 'index.js')).href);
  const missingBuiltin = spec.builtinBundles.filter(n => !beforeBundles.includes(n));
  const nextBundles = [
    ...spec.builtinBundles,
    ...beforeBundles.filter(n => !spec.builtinBundles.includes(n)),
  ];
  const bootPkg = path.join(k.app, 'node_modules', '@deepseek-ai', 'dsh-app-boot', 'package.json');
  const composedBefore = boot.loadProfileDirectory('dsh', profile, bootPkg);
  void composedBefore;
  boot.writeProfileBundles(profile, before, nextBundles);
  if (missingBuiltin.length) log('✓ 启用内核自带 bundle：' + missingBuiltin.join(', '));

  // ---------- 逐个挂载插件包 ----------
  const env = { ...process.env, ELECTRON_RUN_AS_NODE: '1', DSH_HOME: home };
  const runCli = (args, cwd) => {
    const r = spawnSync(k.exe, ['--expose-internals', k.cli, 'plugin', '--profile', 'desktop', ...args], { cwd, env, stdio: 'inherit', windowsHide: true });
    if (r.error) throw r.error;
    return r.status;
  };

  const installed = [], skipped = [], failed = [], warned = [], redirects = [];
  // v2.1.2：真插件与「启停状态快照 bundle」分开存。v2.1.1 只在这一行写了 kind: 'state'，
  // 下游两处收尾断言都没读它（全文件仅此一处 kind 赋值、零处读取），于是 state bundle
  // 被当成第 33 个插件去比 profile.bundles —— 它按设计不进 bundles，必然缺 1 条。
  // 分开存之后，断言各看各的数组，以后再加新 kind 也不会被误判。
  const pluginTargets = spec.packages.map(p => ({ ...p, isState: false, dir: path.join(store, 'payload', 'node_modules', ...p.name.split('/')) }));
  const stateTargets = [{ name: spec.stateBundle, version: spec.version, isState: true, dir: path.join(store, 'payload', 'migration-state') }];
  // 挂载阶段仍然全挂：state bundle 也要 add 进 profile 依赖，只是它不参与 bundle 启停断言。
  const targets = [...pluginTargets, ...stateTargets];

  for (let i = 0; i < targets.length; i++) {
    const p = targets[i];
    const cur = (before.dependencies || {})[p.name];
    const curTarget = typeof cur === 'string' ? cur.replace(/^link:/, '') : null;
    const sameTarget = curTarget && path.resolve(curTarget).toLowerCase() === path.resolve(p.dir).toLowerCase();
    const pkgJson = path.join(p.dir, 'package.json');
    if (!fs.existsSync(pkgJson)) { failed.push(p.name + '（payload 里没有这个包）'); continue; }
    const meta = readJson(pkgJson);
    if (mode === 'repair' && !cur) { skipped.push(p.name + '（repair 不新增未声明依赖）'); continue; }
    if (mode === 'merge' && cur && !sameTarget) { skipped.push(p.name + '（已有他人版本）'); log('· 跳过 ' + p.name + '：已存在且不是本包版本'); continue; }
    if (mode === 'merge' && sameTarget) { skipped.push(p.name + '（已装同版本）'); continue; }
    if ((mode === 'upgrade' || mode === 'repair') && sameTarget) {
      // 已指向本包载荷：upgrade 仍然重挂一次（幂等，实测 0.6 秒），保证 node_modules 链接实体与 package.json 一致
      if (mode === 'repair') { skipped.push(p.name + '（链接已正确，repair 跳过）'); continue; }
    }
    if ((mode === 'upgrade' || mode === 'repair') && cur && !sameTarget) {
      const wasLink = typeof cur === 'string' && cur.startsWith('link:');
      if (wasLink) {
        redirects.push({ name: p.name, from: curTarget || String(cur), to: p.dir });
        log('· 重指向 ' + p.name + '：' + (curTarget || cur) + '  →  ' + p.dir);
      } else {
        log('· 改由载荷挂载 ' + p.name + '：' + cur + '  →  ' + p.dir);
      }
    }

    // ---------- 三级回退挂载（v2.1.0） ----------
    // ① 纯离线；② 离线但禁用 lockfile —— profile 里若存在 git 依赖（如 treg-dsh 的 codeload tarball）
    // 且离线 store 里没有该 tarball，pnpm 会因为在「整张 lockfile 依赖图」上解析失败而连 link 包一起报
    // ERR_PNPM_NO_OFFLINE_TARBALL；禁读 lockfile 后只按当前 dependencies 解析 link 目标，实测 0.8 秒通过且全程不联网。
    // ③ 前两者都失败才联网。
    const linkSpec = 'link:' + p.dir.replaceAll('\\', '/');
    log('\n[' + (i + 1) + '/' + targets.length + '] 挂载 ' + p.name + '@' + meta.version);
    let status = runCli(['add', '--offline', '--ignore-scripts', '--save-exact', linkSpec], store);
    if (status !== 0) {
      warn('  纯离线挂载失败，改用「离线 + 禁用 lockfile」重试（仍然不联网）…');
      status = runCli(['add', '--offline', '--config.lockfile=false', '--ignore-scripts', '--save-exact', linkSpec], store);
    }
    if (status !== 0) {
      // 正常整合包路径不该走到这里：空壳 profile 里没有 git 依赖，1 级就过。
      // 只有「profile 里还留着 github:/git+ 依赖、且离线 store 缺对应 tarball」时，
      // pnpm 解析整张依赖图会连带把 link 包一起判失败。此时**默认不联网**：
      // 联网会把 200+ 个实体包真装进 profile，破坏「全部 link 到载荷」的离线语义。
      // 记入 warned 继续跑后面的包，最后统一提示；要联网补装请显式加 --allow-network。
      if (!flag('--allow-network')) {
        warned.push(p.name + '（离线解析失败，未联网）');
        warn('  ! 挂载失败（离线解析被 profile 里的 git 依赖挡住）：' + p.name);
        continue;
      }
      warn('  离线方式都失败，按 --allow-network 改用普通模式重试（需要能访问 npm 源）…');
      status = runCli(['add', '--ignore-scripts', '--save-exact', linkSpec], store);
    }
    if (status !== 0) { failed.push(p.name); warn('  ✗ 挂载失败：' + p.name); continue; }
    installed.push(p.name + '@' + meta.version);
  }

  // 升级/修复是「在已有 profile 上作业」：里面可能留着 github:/git+ 依赖，离线解析会挡住个别包的 link 挂载。
  // 这种情况只告警、不中断（其余包已正确重指向），把手工补挂命令打出来；安装类模式则一律失败即停。
  if (warned.length && (mode === 'new' || mode === 'merge' || mode === 'backup')) {
    for (const w of warned) failed.push(w);
    warned.length = 0;
  }
  if (failed.length) {
    result.failed = failed;
    die('有 ' + failed.length + ' 个插件挂载失败：' + failed.join(', ') + '\n备份在：' + backup + '\n可以先用 ROLLBACK.cmd 退回，再重试。');
  }
  if (warned.length) {
    result.warned = warned;
    warn('');
    warn('! 以下 ' + warned.length + ' 个插件没能挂载（profile 里的 git 依赖挡住了离线解析，本包没有联网）：');
    for (const w of warned) warn('   · ' + w);
    warn('  补挂办法（任选其一）：');
    warn('   1) 先把那个 git 依赖替换成本包载荷（例如 dsh plugin remove treg-dsh 后重跑 upgrade），再重跑本安装器；');
    warn('   2) 手动补挂：dsh plugin --profile desktop add link:' + path.join(store, 'payload', 'node_modules').replaceAll('\\', '/') + '/<包名>');
    warn('   3) 愿意联网时加 --allow-network 重跑（会从 npm 源补拉缺失 tarball）。');
  }

  // ---------- 校验挂载结果 ----------
  const finalManifest = readJson(manifestFile);
  const finalBundles = finalManifest.dsh.profile.bundles;
  // v2.1.2：只校验真插件（state bundle 按设计不进 profile.bundles，见挂载清单处的说明）。
  // 同时去掉上游遗留的 @junyunshoure/ 前缀过滤 —— 本地插件早已改名成 @local/ 与裸名，
  // 那条过滤会让这里一个包都不检查，断言等于没写。
  for (const p of pluginTargets) {
    if (skipped.some(s => s.startsWith(p.name + '（'))) continue; // 本次被跳过的包没有动过，不参与「必须存在」断言
    const linked = path.join(profile, 'node_modules', ...p.name.split('/'));
    if (!fs.existsSync(linked)) { failed.push(p.name + '（没生成链接）'); continue; }
    // v2.1.2：只有自己声明了 dsh.bundle.patch 的包才应该出现在 profile.bundles 里。
    // 硬要求「每个包都在 bundles」会在遇到纯依赖包时误报，声明式判断更准。
    if (!finalBundles.includes(p.name) && declaresBundle(p.dir)) { failed.push(p.name + '（bundle 未启用）'); }
  }
  if (failed.length) die('挂载后的校验没通过：' + failed.join(', ') + '\n备份：' + backup);

  // ---------- 升级/修复收尾：逐个核对 profile/node_modules 链接指向（v2.1.0） ----------
  if (mode === 'upgrade' || mode === 'repair') {
    const dangling = [];
    for (const p of targets) {
      const linkPath = path.join(profile, 'node_modules', ...p.name.split('/'));
      const expect = path.resolve(p.dir);
      if (!fs.existsSync(linkPath)) { dangling.push(p.name + '（链接不存在）'); continue; }
      let real = '';
      try { real = fs.realpathSync(linkPath); } catch { dangling.push(p.name + '（断链）'); continue; }
      if (path.resolve(real).toLowerCase() !== expect.toLowerCase()) dangling.push(p.name + '（指向 ' + real + '）');
    }
    if (dangling.length) {
      die('重指向后仍有 ' + dangling.length + ' 个插件没指到本包载荷：\n  ' + dangling.join('\n  ') +
        '\n备份：' + backup + '\n可以先 ROLLBACK.cmd 退回，或手动删除 profile/node_modules 下对应链接后重跑 --mode repair。');
    }
    const afterBundles = (readJson(manifestFile).dsh.profile.bundles || []);
    // v2.1.2：这里原本用 targets（含 state bundle）去比 afterBundles，state 必然缺 1 条 →
    // 每次 upgrade 都以「升级后这些 bundle 没启用」exit 1 收场。只用真插件比。
    const missingB = pluginTargets.map(t => t.name).filter(n => !afterBundles.includes(n));
    if (missingB.length) die('升级后这些 bundle 没启用：' + missingB.join(', ') + '\n备份：' + backup);
    log('✓ 重指向核对通过：' + pluginTargets.length + ' 个插件全部指到 ' + path.join(store, 'payload', 'node_modules')
      + '（另有启停状态快照 ' + spec.stateBundle + ' 一并重指向，它不参与 bundle 启停）');
    if (redirects.length) {
      log('✓ 本次重定向 ' + redirects.length + ' 个：');
      for (const r of redirects) log('   · ' + r.name + '：' + r.from + '  →  ' + r.to);
    }
  }

  const composed = boot.loadProfileDirectory('dsh', profile, bootPkg);
  if (composed.skippedBundles.length) warn('⚠ 有 bundle 被跳过：' + composed.skippedBundles.join(', '));
  const rows = boot.composeEntries([...composed.layers.map(l => l.patches), composed.patches]);
  const inv = readJson(path.join(store, 'inventory.json'));
  const rowProblems = [];
  for (const exp of inv.pluginRows) {
    const act = rows.find(r => r.id === exp.id);
    if (!act) { rowProblems.push('缺少条目 ' + exp.id); continue; }
    // v2.1.2：判定与文案共用同一个 normalize。旧代码判定用 (act.disabled === true)、文案用
    // 真值判断，遇到字符串 'true' 就打印「期望 停用，实际 停用」这种自相矛盾的结果。
    const normDisabled = (v) => v === true || v === 'true' || v === 1 || v === '1';
    if (exp.disabled !== undefined && !exp.disabledExpression) {
      const want = normDisabled(exp.disabled), got = normDisabled(act.disabled);
      if (want !== got) {
        rowProblems.push((want ? '应停用但实际在启用 ' : '应启用但实际被停用 ') + exp.id
          + '（快照 ' + JSON.stringify(exp.disabled) + '，实际 ' + JSON.stringify(act.disabled) + '）');
      }
    }
  }
  const missingRows = rowProblems.filter(p => p.startsWith('缺少条目'));
  if (missingRows.length) die('插件条目缺失（' + missingRows.length + ' 条）：\n' + missingRows.slice(0, 15).join('\n') + '\n备份：' + backup);
  const stateDiff = rowProblems.filter(p => !p.startsWith('缺少条目'));
  if (stateDiff.length) warn('⚠ 有 ' + stateDiff.length + ' 个条目启停状态与快照不同（合并模式下正常，可自行在 GUI 里调整）：\n  ' + stateDiff.slice(0, 10).join('\n  '));
  log('✓ 插件组合校验通过：' + rows.length + ' 个条目，' + finalBundles.length + ' 个 bundle');

  // ---------- 配置文件（cordis.patch.yml 按条目补缺，其余只补缺失文件） ----------
  const cfgSrc = path.join(store, 'config');
  const cfgWritten = [], cfgKept = [], cfgMerged = [];
  const KERNEL_OWNED = ['package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml'];
  if (fs.existsSync(cfgSrc)) {
    const patchName = 'cordis.patch.yml';
    const srcPatch = path.join(cfgSrc, patchName);
    const dstPatch = path.join(profile, patchName);
    if (fs.existsSync(srcPatch)) {
      if (!fs.existsSync(dstPatch)) {
        fs.copyFileSync(srcPatch, dstPatch);
        cfgWritten.push(patchName);
      } else if (flag('--force-config')) {
        fs.copyFileSync(dstPatch, path.join(backup, patchName + '.before'));
        fs.copyFileSync(srcPatch, dstPatch);
        cfgWritten.push(patchName + '（--force-config 覆盖，原文件已备份）');
      } else {
        fs.copyFileSync(dstPatch, path.join(backup, patchName + '.before'));
        const added = mergePatchFile(srcPatch, dstPatch);
        if (added.length) cfgMerged.push(patchName + ' 追加 ' + added.length + ' 条：' + added.join(', '));
        else cfgKept.push(patchName + '（你的条目已覆盖本包全部内容，未改动）');
      }
    }
    for (const f of fs.readdirSync(cfgSrc)) {
      if (f === 'feature-profiles' || f === patchName || KERNEL_OWNED.includes(f)) continue;
      const s = path.join(cfgSrc, f), d = path.join(profile, f);
      if (!fs.existsSync(d) || flag('--force-config')) {
        if (fs.existsSync(d)) fs.copyFileSync(d, path.join(backup, f + '.before'));
        fs.copyFileSync(s, d);
        cfgWritten.push(f);
      } else {
        fs.copyFileSync(s, path.join(profile, f + '.pack-sample'));
        cfgKept.push(f + '（已存在，样本另存为 .pack-sample）');
      }
    }
  }
  if (cfgWritten.length) log('✓ 写入配置：' + cfgWritten.join(', '));
  if (cfgMerged.length) log('✓ 合并配置：' + cfgMerged.join('; '));
  if (cfgKept.length) log('· 保留你原有配置：' + cfgKept.join('; '));

  // ---------- feature-profiles 文档 ----------
  const fpHint = [];
  const fpSrc = path.join(cfgSrc, 'feature-profiles');
  if (fs.existsSync(fpSrc)) {
    const fpDst = path.join(profile, 'feature-profiles');
    if (!fs.existsSync(fpDst)) { copyTree(fpSrc, fpDst); fpHint.push('已安装 ' + fs.readdirSync(fpDst).length + ' 个功能 profile 说明到 profile/feature-profiles'); }
    else fpHint.push('profile/feature-profiles 已存在，未覆盖（新版样本见 config/feature-profiles）');
  }

  // ---------- 技能 ----------
  const skillRes = { installed: [], skipped: [] };
  const skSrc = path.join(store, 'payload', 'skills');
  // --skills-root 只给演练/自定义用；正常安装保持两个默认根不变。
  const skillsRootOverride = opt('--skills-root', '');
  const skTargets = skillsRootOverride
    ? { dsh: path.join(skillsRootOverride, 'dsh'), agents: path.join(skillsRootOverride, 'agents') }
    : { dsh: path.join(home, 'skills'), agents: path.join(os.homedir(), '.agents', 'skills') };
  if (fs.existsSync(skSrc)) {
    for (const tier of fs.readdirSync(skSrc)) {
      const dst = skTargets[tier];
      if (!dst) continue;
      fs.mkdirSync(dst, { recursive: true });
      for (const name of fs.readdirSync(path.join(skSrc, tier))) {
        const s = path.join(skSrc, tier, name), d = path.join(dst, name);
        // 单个技能失败不能拖垮整个安装（真机实测过 .agents\skills 下的 mkdir 偶发 EPERM：
        // 多是安全软件/索引器瞬时占用）。这里最多重试 3 次，仍失败就告警并继续。
        let lastErr = null, done = false;
        for (let attempt = 1; attempt <= 3 && !done; attempt++) {
          try {
            if (fs.existsSync(d) || (() => { try { fs.lstatSync(d); return true; } catch { return false; } })()) {
              const bk = path.join(backup, 'skills', tier, name);
              if (fs.existsSync(d)) copyTree(d, bk);
              fs.rmSync(d, { recursive: true, force: true });
              if (!skillRes.skipped.some(x => x.startsWith(name))) skillRes.skipped.push(name + '（已存在，旧版备份到 backups）');
            } else if (!skillRes.installed.includes(name)) {
              skillRes.installed.push(name);
            }
            copyTree(s, d);
            done = true;
          } catch (e) {
            lastErr = e;
            Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 300 * attempt);
          }
        }
        if (!done) {
          warn('  ! 技能没能写入：' + name + '（' + (lastErr && lastErr.message) + '）');
          // v2.1.2：外部用户实测就是 EPERM（%APPDATA%\DeepSeek Harness 的文件锁被另一个实例/
          // 索引器/杀软握着）。只报「没能写入」，用户不知道下一步做什么。
          warn('    多半是另一个 DeepSeek Harness 还在运行，或被杀软/索引器占用：');
          warn('    先完全退出 DSH（托盘图标与后台进程都要退），再重跑 VERIFY.cmd 即可；已装好的插件不受影响。');
          skillRes.failed = skillRes.failed || [];
          skillRes.failed.push(name);
        }
      }
    }
  }
  if (skillRes.installed.length) log('✓ 安装技能：' + skillRes.installed.join(', '));
  if (skillRes.skipped.length) log('· 技能覆盖（旧版已备份）：' + skillRes.skipped.join(', '));
  if (skillRes.failed && skillRes.failed.length) warn('! 有 ' + skillRes.failed.length + ' 个技能没能写入（不阻断安装，可关掉安全软件后重跑 upgrade 补上）：' + skillRes.failed.join(', '));

  // ---------- 本地记忆服务（可选） ----------
  let servicesInfo = null;
  const svcManifest = path.join(store, 'payload', 'services', 'manifest.json');
  if (fs.existsSync(svcManifest)) {
    if (flag('--with-services')) {
      log('\n检测到服务本体，开始安装本地记忆服务…');
      const code = installServicesAt(store, home);
      servicesInfo = { attempted: true, exitCode: code };
      if (code !== 0) warn('⚠ 服务安装没全部成功（插件部分不受影响）。详见 docs/服务部署指南.md。');
    } else {
      log('\n· 检测到服务本体（ReMe / OpenViking / Hindsight / WeKnora），本次未安装。需要时运行 SETUP-SERVICES.cmd。');
      servicesInfo = { present: true, installed: false };
    }
  }

  // ---------- 一键：对齐协议自动写入 + 安全清理（v2.1.0 起默认执行） ----------
  let appendixRes = null;
  if (!flag('--skip-appendix')) {
    try { appendixRes = writeAgentsAppendix({ home }); }
    catch (e) { appendixRes = { ok: false, hint: e.message }; warn('! 对齐协议没有写成功（不阻断安装）：' + e.message); }
  } else {
    log('');
    log('· 按 --skip-appendix 跳过 AGENTS.md 写入。');
  }
  let cleanupRes = null;
  if (!flag('--skip-cleanup')) {
    try { cleanupRes = safeCleanup({ home }); }
    catch (e) { warn('! 安全清理出错（不阻断安装）：' + e.message); }
  }
  if (appendixRes && appendixRes.ok) {
    log('');
    log((appendixRes.mode === 'unchanged' ? '✓ 对齐协议：已是最新内容（未改动，' : '✓ 对齐协议已写入：') + (appendixRes.mode === 'unchanged' ? appendixRes.linesAfter + ' 行，DEPTH_MODE: ' + appendixRes.depthMode + '）' : appendixRes.file + '（DEPTH_MODE: ' + appendixRes.depthMode + '，' + appendixRes.linesAfter + ' 行）'));
    if (appendixRes.migratedOutsideLines) log('· 块外 ' + appendixRes.migratedOutsideLines + ' 行旧档位段已并入块内（之后只会有这一份 DEPTH_MODE）');
    if (appendixRes.backup) log('· 原 AGENTS.md 已备份：' + appendixRes.backup);
    log('· 新开一个 DSH 会话即生效 —— 不需要再运行 MAINTAIN.cmd。');
  } else if (appendixRes) {
    warn('! 对齐协议没写成功：' + (appendixRes.hint || '未知原因') + '（稍后可运行 MAINTAIN.cmd 重试）');
  }
  if (cleanupRes) {
    const cleaned = cleanupRes.tmpRemoved.length + cleanupRes.rotatedLogs.length;
    if (cleaned || cleanupRes.emptyDirs.length) log('✓ 安全清理：临时/轮转日志 ' + cleaned + ' 个、空目录 ' + cleanupRes.emptyDirs.length + ' 个，释放 ' + (cleanupRes.bytesReclaimed / 1048576).toFixed(2) + ' MB');
    else log('· 安全清理：没有需要清理的东西');
    if (cleanupRes.bigLogs.length) warn('! 有 ' + cleanupRes.bigLogs.length + ' 个超过 100 MB 的日志没有自动删（留作排障证据）：' + cleanupRes.bigLogs.join('；'));
  }

  // ---------- 结果 ----------
  result.ok = true;
  result.packVersion = spec.version;
  result.redirects = redirects;
  result.oldStores = oldStores.map(s => ({ name: s.name, dir: s.dir }));
  result.finishedAt = new Date().toISOString();
  result.kernelVersion = k.version;
  result.home = home;
  result.profile = profile;
  result.installed = installed;
  result.skipped = skipped;
  result.configWritten = cfgWritten;
  result.configKept = cfgKept;
  result.skills = skillRes;
  result.featureProfiles = fpHint;
  result.services = servicesInfo;
  result.rowCount = rows.length;
  result.bundleCount = finalBundles.length;
  result.rowStateWarnings = stateDiff.length;
  result.appendix = appendixRes;
  result.cleanup = cleanupRes;
  result.nextSteps = [
    '打开 DeepSeek Harness：左侧栏应出现「技能融合 / 记忆融合 / 功能说明 / Ollama / 清理 / 工作台」等入口。',
    '对齐协议：' + (appendixRes && appendixRes.ok
      ? (appendixRes.mode === 'unchanged' ? '已是最新内容 ' : '已写入 ') + appendixRes.file + '（DEPTH_MODE: ' + appendixRes.depthMode + '，' + appendixRes.linesAfter + ' 行），新开一个会话即生效，不需要再跑 MAINTAIN.cmd。'
      : '这次没写成功，可稍后运行 MAINTAIN.cmd 重试。'),
    '旧版本载荷目录不再需要时：VERIFY.cmd 里会提示，或用 --prune-old 清理（默认只删 7 天前的，且会跳过仍被引用的目录）。',
    '设置 → 模型：把 config/cordis.patch.yml 里的 https://YOUR-ENDPOINT.example.com 换成你自己的中转站或官方接口地址，填入密钥。',
    '需要本地记忆服务时运行 SETUP-SERVICES.cmd；需要撤回时运行 ROLLBACK.cmd。',
  ];
  fs.writeFileSync(path.join(store, 'installation-result.json'), JSON.stringify(result, null, 2));
  writeResult(result);

  log('\n================ 安装完成 ================');
  log('插件包：已挂载 ' + installed.length + ' 个，跳过 ' + skipped.length + ' 个');
  log('技能：' + skillRes.installed.length + ' 个新增');
  log('插件条目：' + rows.length + ' 个，bundle：' + finalBundles.length + ' 个');
  log('持久目录：' + store);
  log('安装前备份：' + backup + '（ROLLBACK.cmd 可回退）');
  log('详细报告：' + path.join(store, 'installation-result.json'));
  if (appendixRes && appendixRes.ok) log('对齐协议：' + (appendixRes.mode === 'unchanged' ? '已是最新 ' : '已写入 ') + appendixRes.file + '（' + appendixRes.linesAfter + ' 行，新会话生效）');
  else if (appendixRes) log('对齐协议：未写入（详见上面的提示）');
  if (fpHint.length) log('功能说明：' + fpHint.join('；'));
  log('下一步：打开 DeepSeek Harness，并把中转站地址/密钥填进设置 → 模型。');
  if (redirects.length) log('本次重指向了 ' + redirects.length + ' 个本地插件（旧载荷目录可以留几天再清）。');
  log('==========================================');

  // ---------- 可选：自动启动并等待 GUI ----------
  if (!flag('--no-launch')) {
    try {
      log('\n正在启动 DeepSeek Harness（首次加载插件约 20–60 秒）…');
      const child = spawn(k.exe, [], { detached: true, stdio: 'ignore', windowsHide: false });
      child.unref();
      // v2.1.2：先看是不是已经有实例在跑（升级/修复场景最常见）。DSH 是单实例应用，
      // 新 spawn 出来的进程会自己退出、端口只挂在旧进程上，按 child.pid 死等 120 秒纯属空耗。
      const already = guiPort();
      if (already && already.port) {
        log('✓ 检测到 DeepSeek Harness 已在运行：http://127.0.0.1:' + already.port + '（重启它即可加载新插件）');
      } else {
        const port = await waitForPort(child.pid, 20000);
        if (port) log('✓ 主界面已就绪：http://127.0.0.1:' + port);
        else warn('⚠ 没能在 20 秒内探测到界面端口，请手动从桌面图标打开；插件已装好，不影响使用。');
      }
      if (port) log('✓ 主界面已就绪：http://127.0.0.1:' + port);
      else warn('⚠ 没能在 2 分钟内探测到界面端口，请手动从桌面图标打开；插件已装好，不影响使用。');
    } catch (e) {
      warn('⚠ 自动启动失败：' + (e.message || e) + '；请手动双击桌面图标打开。');
    }
  }
})().catch(e => {
  const msg = String((e && (e.message || e.stack)) || e);
  console.error('\n✗ 安装未完成：' + msg);
  if (/--mode|空壳|安装方式/.test(msg)) console.error('提示：双击 INSTALL.cmd 会给你 A/B/C 三种安装方式的选择。');
  writeResult({ ok: false, error: msg, at: new Date().toISOString() });
  process.exitCode = 1;
});

// 轮询子进程的监听端口（只在本机回环上探测）
// v2.1.2：双通道 —— 既认新子进程的监听口，也认「已经在运行的那个实例」的监听口。
// 单实例锁让后者成为升级场景的唯一真相来源，只看 pid 会白等到超时。
function waitForPort(pid, timeoutMs) {
  const script = `$p=${pid}; try { (Get-NetTCPConnection -State Listen -OwningProcess $p -ErrorAction Stop | Where-Object { $_.LocalAddress -in @('127.0.0.1','0.0.0.0','::1') } | Select-Object -First 1 -ExpandProperty LocalPort) } catch { '' }`;
  const start = Date.now();
  return new Promise(resolve => {
    const tick = () => {
      try {
        const r = spawnSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', script], { encoding: 'utf8', windowsHide: true, timeout: 8000 });
        const n = String(r.stdout || '').trim();
        if (n && /^\d+$/.test(n)) return resolve(Number(n));
        const ex = guiPort();
        if (ex && ex.port) return resolve(ex.port);
      } catch { /* ignore */ }
      if (Date.now() - start > timeoutMs) return resolve(null);
      setTimeout(tick, 2000);
    };
    setTimeout(tick, 5000);
  });
}

// ==================================================================== 工具
function resolveProfile() {
  const home = path.resolve(process.env.DSH_HOME || path.join(os.homedir(), '.dsh'));
  return { home, profile: path.join(home, 'profiles', 'desktop'), manifest: path.join(home, 'profiles', 'desktop', 'package.json') };
}
/** v2.1.2：这个包自己是否声明了 dsh.bundle.patch（声明了才该出现在 profile.bundles 里）。 */
function declaresBundle(dir) {
  try {
    const pj = readJson(path.join(dir, 'package.json'));
    return !!(pj.dsh && pj.dsh.bundle && pj.dsh.bundle.patch);
  } catch { return false; }
}

function defaultStore(spec) {
  return path.join(process.env.LOCALAPPDATA || os.tmpdir(), 'DSHPluginsPack', 'v' + spec.version + '-windows');
}
// 列出 %LOCALAPPDATA%\\DSHPluginsPack 下所有 v*-windows 载荷目录（v2.1.0）
function listStores() {
  const base = path.join(process.env.LOCALAPPDATA || os.tmpdir(), 'DSHPluginsPack');
  if (!fs.existsSync(base)) return [];
  const out = [];
  for (const e of fs.readdirSync(base, { withFileTypes: true })) {
    if (!e.isDirectory() || !/^v.+-windows$/.test(e.name)) continue;
    const dir = path.join(base, e.name);
    const pj = path.join(dir, 'payload', 'node_modules');
    if (!fs.existsSync(pj)) continue;
    let files = 0;
    const stack = [dir];
    while (stack.length) {
      const cur = stack.pop();
      let ents = [];
      try { ents = fs.readdirSync(cur, { withFileTypes: true }); } catch { continue; }
      for (const x of ents) {
        const q = path.join(cur, x.name);
        if (x.isDirectory()) { stack.push(q); continue; }
        files++;
      }
    }
    out.push({ name: e.name, dir, files, mtime: fs.statSync(dir).mtimeMs });
  }
  return out.sort((a, b) => a.mtime - b.mtime);
}

// 清理旧载荷：默认只删 keep-days 天前的，且跳过仍被 profile 引用的目录（v2.1.0）
async function pruneOldStores(spec) {
  const keepDays = Number(opt('--keep-days', '7')) || 7;
  const { manifest } = resolveProfile();
  const deps = fs.existsSync(manifest) ? (readJson(manifest).dependencies || {}) : {};
  const inUse = new Set();
  for (const v of Object.values(deps)) {
    if (typeof v === 'string' && v.startsWith('link:')) inUse.add(path.resolve(v.slice(5)).toLowerCase());
  }
  const stores = listStores();
  const cut = Date.now() - keepDays * 86400000;
  const del = [], keep = [];
  for (const s of stores) {
    const used = [...inUse].some(p => p.startsWith(path.resolve(s.dir).toLowerCase()));
    if (used) { keep.push(s.name + '（仍被 profile 引用）'); continue; }
    if (s.mtime > cut) { keep.push(s.name + '（未满 ' + keepDays + ' 天）'); continue; }
    del.push(s);
  }
  log('\n================ 旧载荷清理 ================');
  log('保留 ' + keepDays + ' 天内的载荷；仍被引用的永不删。');
  for (const k of keep) log('  · 保留 ' + k);
  for (const s of del) log('  · 删除 ' + s.name + '  ' + s.dir + '（' + s.files + ' 个文件）');
  if (!del.length) { log('没有可清理的目录。'); }
  else if (flag('--yes')) {
    for (const s of del) { fs.rmSync(s.dir, { recursive: true, force: true }); log('  ✓ 已删 ' + s.name); }
  } else {
    log('以上只是预演。确认无误后加 --yes 执行：node install-helper.cjs --prune-old --yes');
  }
  log('==========================================');
  writeResult({ mode: 'prune-old', ok: true, deleted: del.map(s => s.name), kept: keep, applied: flag('--yes'), at: new Date().toISOString() });
}

function listBackups(store) {
  const dir = path.join(store, 'backups');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).filter(e => e.isDirectory()).map(e => path.join(dir, e.name)).sort();
}
function readResult(store) {
  const p = path.join(store, 'installation-result.json');
  return fs.existsSync(p) ? readJson(p) : null;
}
function guiPort() {
  try {
    const ps = "Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id";
    const r = spawnSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', ps], { encoding: 'utf8', windowsHide: true, timeout: 15000 });
    const pids = String(r.stdout || '').trim().split(/\s+/).filter(Boolean);
    for (const pid of pids) {
      const q = "try { (Get-NetTCPConnection -State Listen -OwningProcess " + pid + " -ErrorAction Stop | Where-Object { $_.LocalAddress -in @('127.0.0.1','::1','0.0.0.0') } | Select-Object -First 1 -ExpandProperty LocalPort) } catch { }";
      const r2 = spawnSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', q], { encoding: 'utf8', windowsHide: true, timeout: 15000 });
      const n = String(r2.stdout || '').trim();
      if (/^\d+$/.test(n)) return { pid: Number(pid), port: Number(n) };
    }
  } catch { /* ignore */ }
  return null;
}
function portOpen(port) {
  try {
    const r = spawnSync('powershell', ['-NoProfile', '-NonInteractive', '-Command',
      "try { (Test-NetConnection -ComputerName 127.0.0.1 -Port " + port + " -InformationLevel Quiet -WarningAction SilentlyContinue) } catch { $false }"],
      { encoding: 'utf8', windowsHide: true, timeout: 20000 });
    return /true/i.test(String(r.stdout || ''));
  } catch { return false; }
}

// ==================================================================== 体检
async function doctorMode(spec) {
  log('\n================ 环境体检 ================');
  const ok = [], bad = [], warnList = [];
  let desktop = '';
  try { desktop = findDesktopDir(opt('--desktop-dir')); ok.push('Desktop 安装目录：' + desktop); }
  catch (e) { bad.push('找不到 Desktop 安装目录（' + e.message + '）'); }

  let k = null;
  if (desktop) {
    try { k = locate(desktop); ok.push('内核版本：' + k.version + '（本包基准 ' + spec.kernel.recorded + '）'); if (!semverOk(k.version, spec.kernel.required)) warnList.push('内核不在 ' + spec.kernel.required + ' 范围，部分插件可能需要 AI agent 适配'); }
    catch (e) { bad.push('内核文件不完整：' + e.message); }
  }

  const { home, profile, manifest } = resolveProfile();
  let manifestData = null;
  if (!fs.existsSync(manifest)) bad.push('DSH 数据目录里没有 desktop profile（' + profile + '）：请先打开一次 DSH 再退出');
  else {
    manifestData = readJson(manifest);
    const bundles = (manifestData.dsh && manifestData.dsh.profile && manifestData.dsh.profile.bundles) || [];
    const deps = Object.keys(manifestData.dependencies || {});
    ok.push('profile：' + profile);
    ok.push('已启用 bundle：' + bundles.length + ' 个；依赖：' + deps.length + ' 个');
    const mine = spec.packages.filter(p => deps.includes(p.name));
    const missing = spec.packages.filter(p => !deps.includes(p.name));
    ok.push('本包插件已挂载：' + mine.length + '/' + spec.packages.length);
    if (missing.length) warnList.push('本包还有 ' + missing.length + ' 个插件没挂载：' + missing.slice(0, 8).map(m => m.name).join(', ') + (missing.length > 8 ? ' …' : ''));
    const brokenLinks = [];
    for (const p of mine) {
      const t = path.join(profile, 'node_modules', ...p.name.split('/'));
      if (!fs.existsSync(t)) brokenLinks.push(p.name);
    }
    if (brokenLinks.length) bad.push('这些插件的链接断了（持久目录被移动或删除）：' + brokenLinks.join(', '));
    if (!bundles.includes(spec.stateBundle) && mine.length === spec.packages.length) warnList.push('启停状态快照 bundle（' + spec.stateBundle + '）没启用，界面开关可能和整合包快照不一致');
  }

  // 插件条目组合
  if (k && manifestData) {
    try {
      const boot = await import(pathToFileURL(path.join(k.app, 'node_modules', '@deepseek-ai', 'dsh-app-boot', 'lib', 'index.js')).href);
      const bootPkg = path.join(k.app, 'node_modules', '@deepseek-ai', 'dsh-app-boot', 'package.json');
      const composed = boot.loadProfileDirectory('dsh', profile, bootPkg);
      if (composed.skippedBundles.length) warnList.push('加载时被跳过的 bundle：' + composed.skippedBundles.join(', '));
      const rows = boot.composeEntries([...composed.layers.map(l => l.patches), composed.patches]);
      ok.push('插件条目组合：' + rows.length + ' 个');
      const inv = readJson(path.join(ROOT, 'inventory.json'));
      const missingRows = inv.pluginRows.filter(e => !rows.find(r => r.id === e.id));
      if (missingRows.length) warnList.push('有 ' + missingRows.length + ' 个快照条目当前不存在：' + missingRows.slice(0, 8).map(r => r.id).join(', '));
    } catch (e) { warnList.push('无法组合插件条目（' + (e.message || e) + '）'); }
  }

  // 运行状态
  const g = guiPort();
  if (g) ok.push('DSH 正在运行：http://127.0.0.1:' + g.port + '（进程 ' + g.pid + '）');
  else warnList.push('没有探测到正在运行的 DSH 界面（可能没开，或端口被改了）');

  const svc = [['ReMe', 2333], ['OpenViking', 1933], ['Hindsight', 8888], ['WeKnora', 8080]];
  const svcState = svc.map(([n, p]) => n + '(' + p + ')=' + (portOpen(p) ? '在线' : '离线'));
  ok.push('本地记忆服务：' + svcState.join('  '));

  const store = path.resolve(opt('--store', defaultStore(spec)));
  const res = readResult(store);
  if (res) ok.push('上次安装结果：' + (res.ok ? '成功' : '失败') + ' @ ' + (res.finishedAt || res.at) + (res.ok ? '（挂载 ' + (res.installed || []).length + ' 个）' : '（' + res.error + '）'));
  else warnList.push('持久目录里没有安装记录：' + store);
  const bks = listBackups(store);
  ok.push('可回滚备份：' + bks.length + ' 个' + (bks.length ? '（最新 ' + path.basename(bks[bks.length - 1]) + '）' : ''));

  // v2.1.0：旧载荷目录体检
  const stores = listStores();
  if (stores.length > 1) {
    ok.push('载荷目录：' + stores.length + ' 个（' + stores.map(s => s.name + ' ' + s.files + 'f').join('，') + '）');
    warnList.push('存在多份载荷目录，确认都指向当前版本后可用 --prune-old 清理旧的那份');
  } else if (stores.length === 1) {
    ok.push('载荷目录：' + stores[0].name + '（' + stores[0].files + ' 个文件）');
  }

  // v2.1.0：profile 里 link: 目标是否都真实存在（断链会让插件静默消失，DSH 却照常启动）
  if (manifestData) {
    const broken = [];
    for (const [n, v] of Object.entries(manifestData.dependencies || {})) {
      if (typeof v !== 'string' || !v.startsWith('link:')) continue;
      const t = path.resolve(v.slice(5));
      if (!fs.existsSync(t)) broken.push(n + ' → ' + t);
    }
    if (broken.length) bad.push('link: 目标不存在（插件会静默不加载）：\n      ' + broken.join('\n      '));
    else if (Object.values(manifestData.dependencies || {}).some(v => typeof v === 'string' && v.startsWith('link:'))) ok.push('link: 目标全部存在');
  }

  log('');
  for (const s of ok) log('  ✓ ' + s);
  for (const s of warnList) log('  ! ' + s);
  for (const s of bad) log('  ✗ ' + s);
  log('');
  log(bad.length ? '结论：有 ' + bad.length + ' 项阻塞问题，先按上面的 ✗ 处理。' : (warnList.length ? '结论：基本正常，' + warnList.length + ' 项提醒可忽略。' : '结论：一切正常。'));
  log('=========================================');
  writeResult({ mode: 'doctor', ok: bad.length === 0, bad, warn: warnList, at: new Date().toISOString() });
  return;
}

// ==================================================================== 回滚
async function rollbackMode(spec, wanted) {
  const { home, profile, manifest } = resolveProfile();
  const store = path.resolve(opt('--store', defaultStore(spec)));
  const backups = listBackups(store);
  if (!backups.length) die('没有找到任何备份（' + path.join(store, 'backups') + '）。若是刚装的还没备份，说明安装没进行到那一步。');
  let backup = wanted ? path.resolve(wanted) : backups[backups.length - 1];
  if (!fs.existsSync(backup)) die('指定的备份目录不存在：' + backup);
  const snapFile = path.join(backup, 'deps-before.json');
  if (!fs.existsSync(snapFile)) {
    const usable = backups.filter(b => fs.existsSync(path.join(b, 'deps-before.json')));
    if (!usable.length) die('备份里缺少 deps-before.json（这是 v2 才有的快照）。请手动恢复，或直接 UNINSTALL.cmd。');
    backup = usable[usable.length - 1];
  }
  const snap = readJson(path.join(backup, 'deps-before.json'));
  log('使用备份：' + backup);
  log('回滚到：' + snap.at + '（当时模式 ' + snap.mode + '，依赖 ' + Object.keys(snap.dependencies || {}).length + ' 个）');

  // 1) 配置：原样拷回备份里的 cfg 文件
  const cfgNames = ['package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml', 'cordis.yml', 'cordis.patch.yml'];
  const restored = [];
  for (const f of cfgNames) {
    const src = path.join(backup, f);
    if (fs.existsSync(src) && f !== 'package.json') { fs.copyFileSync(src, path.join(profile, f)); restored.push(f); }
  }
  // 2) package.json：依赖回到快照，并清掉本包新增的包
  const cur = readJson(manifest);
  const snapDeps = snap.dependencies || {};
  const packNames = spec.packages.map(p => p.name).concat(spec.stateBundle);
  const removed = [];
  const nextDeps = { ...(cur.dependencies || {}) };
  for (const n of packNames) {
    if (!(n in snapDeps) && n in nextDeps) { delete nextDeps[n]; removed.push(n); }
  }
  for (const [n, v] of Object.entries(snapDeps)) nextDeps[n] = v;
  cur.dependencies = nextDeps;
  const bundles = (snap.bundles || []).filter(b => b.startsWith('@deepseek-ai/') || fs.existsSync(path.join(profile, 'node_modules', ...b.split('/'))));
  cur.dsh = cur.dsh || {}; cur.dsh.profile = cur.dsh.profile || {}; cur.dsh.profile.bundles = bundles;
  fs.writeFileSync(manifest, JSON.stringify(cur, null, 2) + '\n');
  // 3) 清掉本包链接（只删符号链接/目录，不动用户其它包）
  for (const n of removed) {
    const t = path.join(profile, 'node_modules', ...n.split('/'));
    try { if (fs.existsSync(t)) fs.rmSync(t, { recursive: true, force: true }); } catch (e) { warn('· 删不掉链接 ' + n + '：' + e.message); }
  }
  // 4) 技能：备份里有就还原
  const skBackup = path.join(backup, 'skills');
  if (fs.existsSync(skBackup)) {
    const map = { dsh: path.join(home, 'skills'), agents: path.join(os.homedir(), '.agents', 'skills') };
    for (const tier of fs.readdirSync(skBackup)) {
      for (const name of fs.readdirSync(path.join(skBackup, tier))) {
        const dst = path.join(map[tier] || '', name);
        if (!map[tier]) continue;
        try { if (fs.existsSync(dst)) fs.rmSync(dst, { recursive: true, force: true }); copyTree(path.join(skBackup, tier, name), dst); restored.push('skill:' + name); } catch (e) { warn('· 技能还原失败 ' + name + '：' + e.message); }
      }
    }
  }
  log('✓ 已还原配置：' + (restored.filter(r => !r.startsWith('skill:')).join(', ') || '（无）'));
  log('✓ 已移除本包依赖：' + (removed.join(', ') || '（无）'));
  log('✓ bundle 列表已回到 ' + bundles.length + ' 个');
  log('');
  log('回滚完成。请重新打开 DeepSeek Harness 生效。若界面里还残留面板，刷新一次页面即可。');
  writeResult({ mode: 'rollback', ok: true, backup, restored, removed, at: new Date().toISOString() });
}

// ==================================================================== 卸载
async function uninstallMode(spec) {
  const { profile, manifest } = resolveProfile();
  if (!fs.existsSync(manifest)) die('没有找到 profile：' + manifest);
  const cur = readJson(manifest);
  const store = path.resolve(opt('--store', defaultStore(spec)));
  const backup = path.join(store, 'backups', 'uninstall-' + stamp());
  fs.mkdirSync(backup, { recursive: true });
  for (const f of ['package.json', 'cordis.yml', 'cordis.patch.yml', 'pnpm-workspace.yaml', 'pnpm-lock.yaml']) {
    if (fs.existsSync(path.join(profile, f))) fs.copyFileSync(path.join(profile, f), path.join(backup, f));
  }
  const packNames = spec.packages.map(p => p.name).concat(spec.stateBundle);
  const deps = cur.dependencies || {};
  const removed = [];
  for (const n of packNames) if (n in deps) { delete deps[n]; removed.push(n); }
  cur.dependencies = deps;
  const bundles = ((cur.dsh && cur.dsh.profile && cur.dsh.profile.bundles) || []).filter(b => !packNames.includes(b));
  cur.dsh = cur.dsh || {}; cur.dsh.profile = cur.dsh.profile || {}; cur.dsh.profile.bundles = bundles;
  fs.writeFileSync(manifest, JSON.stringify(cur, null, 2) + '\n');
  for (const n of removed) {
    const t = path.join(profile, 'node_modules', ...n.split('/'));
    try { if (fs.existsSync(t)) fs.rmSync(t, { recursive: true, force: true }); } catch (e) { warn('· 删不掉链接 ' + n + '：' + e.message); }
  }
  log('✓ 已卸载 ' + removed.length + ' 个插件包，bundle 剩 ' + bundles.length + ' 个');
  log('· 技能文件保留未删（想删就手动去掉 ~/.dsh/skills 与 ~/.agents/skills 里对应目录）');
  log('· 配置备份：' + backup);
  log('· 持久目录仍保留：' + store + '（确认不再需要可整目录删除）');
  const others = listStores().filter(s => path.resolve(s.dir) !== path.resolve(store));
  if (others.length) log('· 另有 ' + others.length + ' 份旧载荷：' + others.map(s => s.name).join('、') + '（可用 --prune-old 清理）');
  log('重新打开 DeepSeek Harness 生效。');
  writeResult({ mode: 'uninstall', ok: true, removed, backup, at: new Date().toISOString() });
}

// ==================================================================== 只装服务
// 服务安装只有一个实现，安装流程（--with-services）与 SETUP-SERVICES 共用。
// 返回退出码：0 成功 / 非 0 失败 / 2 需要用户去服务包自己跑
function installServicesAt(store, home) {
  const manifest = path.join(store, 'payload', 'services', 'manifest.json');
  const localManifest = path.join(ROOT, 'payload', 'services', 'manifest.json');
  const base = fs.existsSync(manifest) ? store : ROOT;
  if (!fs.existsSync(manifest) && !fs.existsSync(localManifest)) {
    log('这个包里没有服务本体（payload/services 不存在），这是正常的：');
    log('  · 插件整合包（Windows）本身不含 ReMe / OpenViking / Hindsight / WeKnora 的运行文件。');
    log('  · 需要本地记忆服务时，另外下载 "Services" 包，直接双击它根目录的 SETUP-SERVICES.cmd。');
    log('  · 详细步骤见 docs/服务部署指南.md。');
    return 2;
  }
  log('开始安装本地记忆服务（约 3–8 分钟，会建独立 Python 环境并灌入 site-packages 快照）…');

  // 三种入口，按「服务包里实际带的是哪个」自动选：
  //   1. payload/services/install-services.cjs —— 纯 Node 实现，用 Desktop 的 node 跑
  //   2. 服务包根目录 / payload/services 下的 SETUP-SERVICES.ps1 —— 服务包自带脚本
  //   3. 都没有 → 告诉用户去服务包根目录跑
  const cjs = path.join(base, 'payload', 'services', 'install-services.cjs');
  const ps1 = [path.join(base, 'SETUP-SERVICES.ps1'), path.join(base, 'payload', 'services', 'SETUP-SERVICES.ps1')]
    .find((p) => fs.existsSync(p));

  if (fs.existsSync(cjs)) {
    const exe = locate(findDesktopDir(opt('--desktop-dir'))).exe;
    const r = spawnSync(exe, ['--expose-internals', cjs, '--store', base, '--home', home], {
      stdio: 'inherit', cwd: base, env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' }, windowsHide: true,
    });
    return r.status === null ? 1 : r.status;
  }
  if (ps1) {
    log('使用服务包自带脚本：' + ps1);
    const r = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1, '-Auto'], {
      stdio: 'inherit', cwd: path.dirname(ps1), windowsHide: false,
    });
    return r.status === null ? 1 : r.status;
  }
  log('找到了服务本体（manifest.json），但没找到安装脚本（install-services.cjs / SETUP-SERVICES.ps1）。请这样做：');
  log('  · 解压 DSH-Plugins-v2.0.0-Services.zip（服务包沿用 v2.0.0，内容未变），直接双击它根目录的 SETUP-SERVICES.cmd（那里自带完整安装逻辑，不依赖本包）。');
  log('  · 装完回到这里继续用 DSH 即可；详细步骤见 docs/服务部署指南.md。');
  return 2;
}

async function servicesMode(spec) {
  const store = path.resolve(opt('--store', defaultStore(spec)));
  const code = installServicesAt(store, resolveProfile().home);
  if (code === 2) return;
  if (code !== 0) die('服务安装未全部成功（退出码 ' + code + '）。详见上面的输出与 docs/服务部署指南.md。');
  log('✓ 本地记忆服务安装完成。重启 DSH 后，记忆融合 / Hindsight / knowledge 等入口即可工作。');
}
