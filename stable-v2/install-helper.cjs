'use strict';
/**
 * DeepSeek Harness 插件整合包 v2.0.0 —— 安装器核心（Windows）
 *
 * 设计原则
 *  1. 绝不联网：所有插件依赖已在 payload/node_modules 里，逐个用官方 `plugin add --offline` 挂载。
 *  2. 绝不覆盖用户在用的东西：默认 --mode merge，已存在的同名包一律跳过；配置默认只补缺。
 *  3. 一切可回滚：每次安装都在 store/backups/<时间戳>/ 留配置与依赖快照，ROLLBACK.cmd 可原样退回。
 *  4. 失败可见：任何一步失败都打印中文原因 + 已完成的步骤 + 备份路径，并写 last-result.json。
 *
 * 用法（一般由 INSTALL.cmd / VERIFY.cmd / DOCTOR.cmd / ROLLBACK.cmd 调用）：
 *   node install-helper.cjs --desktop-dir <目录> [--mode new|merge|backup] [--with-services]
 *        [--no-launch] [--force-config] [--check-only] [--rollback <备份目录>] [--yes]
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

/** 把 src 里 dst 还没有的条目追加到 dst 末尾；返回追加的 id 列表。 */
function mergePatchFile(srcFile, dstFile) {
  const src = splitPatchBlocks(fs.readFileSync(srcFile, 'utf8'));
  const dstText = fs.existsSync(dstFile) ? fs.readFileSync(dstFile, 'utf8') : '';
  const dst = splitPatchBlocks(dstText);
  const have = new Set(dst.flatMap(b => b.key));
  const missing = src.filter(b => b.key.length && b.key.every(id => !have.has(id)));
  const added = missing.flatMap(b => b.key);
  if (!missing.length) return added;
  const header = [
    '',
    '# === 以下条目由插件整合包 v2.0.0 追加（你的原有条目一条没动） ===',
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

// ------------------------------------------------------------------ 主流程
(async () => {
  const spec = readJson(path.join(ROOT, 'migration.json'));
  const result = { pack: spec.version, id: spec.id, startedAt: new Date().toISOString(), steps: [], ok: false };

  // ---------- 分派：诊断 / 回滚 / 卸载 / 只装服务 ----------
  if (flag('--doctor')) return doctorMode(spec);
  if (flag('--rollback')) return rollbackMode(spec, opt('--backup', ''));
  if (flag('--uninstall')) return uninstallMode(spec);
  if (flag('--services-only')) return servicesMode(spec);

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
    log('✓ 本包版本：' + spec.version + '，插件包数：' + spec.packages.length + '，技能：' + (spec.skills || []).length);
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
  if (!['new', 'merge', 'backup'].includes(mode)) die('未知安装模式：' + mode);
  if (mode === 'new' && hasForeign) {
    die('选的是“全新安装”，但目标 profile 已有其他插件（' + foreignDeps.length + ' 个依赖 / ' + foreignBundles.length + ' 个 bundle）。\n' +
      '请改用 B 智能合并（--mode merge）或 C 备份后覆盖（--mode backup）。');
  }
  log('安装模式：' + ({ new: 'A 全新安装', merge: 'B 智能合并', backup: 'C 备份后覆盖' })[mode]);
  result.mode = mode;

  // ---------- 持久目录 ----------
  const defaultStore = path.join(process.env.LOCALAPPDATA || os.tmpdir(), 'DSHPluginsPack', 'v' + spec.version + '-windows');
  const store = path.resolve(opt('--store', defaultStore));
  if (store === ROOT || store.startsWith(ROOT + path.sep) || ROOT.startsWith(store + path.sep)) die('持久安装目录不能与解压目录重叠，请换一个目录。');
  if (store === home || store.startsWith(home + path.sep)) die('持久安装目录不能放在 DSH 数据目录里，请换一个目录。');

  for (const [name, value] of Object.entries(before.dependencies || {})) {
    if (!spec.packages.some(p => p.name === name) && name !== spec.stateBundle) continue;
    const expect = path.join(store, 'payload', 'node_modules', ...name.split('/'));
    const okTarget = value === 'link:' + expect.replaceAll('\\', '/') || value === 'link:' + expect;
    if (!okTarget && mode !== 'backup') {
      // 已存在同名包但指向别处（例如另一份整合包 / 用户自己装的）
      warn('· 已存在同名包且指向其他目录，本模式下跳过：' + name);
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
    if (fs.existsSync(oldPayload)) fs.rmSync(oldPayload, { recursive: true, force: true });
    for (const e of fs.readdirSync(ROOT, { withFileTypes: true })) {
      if (e.name === 'backups' || e.name === 'payload') continue;
      const s = path.join(ROOT, e.name), d = path.join(store, e.name);
      if (e.isDirectory()) copyTree(s, d); else if (e.isFile()) fs.copyFileSync(s, d);
    }
    copyTree(path.join(ROOT, 'payload'), path.join(store, 'payload'));
    verifyFiles(store, true);
    log('✓ 复制完成并通过校验');
  } else {
    log('已在持久目录内运行：' + store);
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

  const installed = [], skipped = [], failed = [];
  const targets = spec.packages.map(p => ({ ...p, dir: path.join(store, 'payload', 'node_modules', ...p.name.split('/')) }));
  targets.push({ name: spec.stateBundle, version: spec.version, dir: path.join(store, 'payload', 'migration-state'), kind: 'state' });

  for (let i = 0; i < targets.length; i++) {
    const p = targets[i];
    const cur = (before.dependencies || {})[p.name];
    const curTarget = typeof cur === 'string' ? cur.replace(/^link:/, '') : null;
    const sameTarget = curTarget && path.resolve(curTarget).toLowerCase() === path.resolve(p.dir).toLowerCase();
    const pkgJson = path.join(p.dir, 'package.json');
    if (!fs.existsSync(pkgJson)) { failed.push(p.name + '（payload 里没有这个包）'); continue; }
    const meta = readJson(pkgJson);
    if (mode === 'merge' && cur && !sameTarget) { skipped.push(p.name + '（已有他人版本）'); log('· 跳过 ' + p.name + '：已存在且不是本包版本'); continue; }
    if (mode === 'merge' && sameTarget) { skipped.push(p.name + '（已装同版本）'); continue; }
    log('\n[' + (i + 1) + '/' + targets.length + '] 挂载 ' + p.name + '@' + meta.version);
    let status = runCli(['add', '--offline', '--ignore-scripts', '--save-exact', 'link:' + p.dir.replaceAll('\\', '/')], store);
    if (status !== 0) {
      warn('  离线挂载失败，改用普通模式重试（需要能访问 npm 源）…');
      status = runCli(['add', '--ignore-scripts', '--save-exact', 'link:' + p.dir.replaceAll('\\', '/')], store);
    }
    if (status !== 0) { failed.push(p.name); warn('  ✗ 挂载失败：' + p.name); continue; }
    installed.push(p.name + '@' + meta.version);
  }

  if (failed.length) {
    result.failed = failed;
    die('有 ' + failed.length + ' 个插件挂载失败：' + failed.join(', ') + '\n备份在：' + backup + '\n可以先用 ROLLBACK.cmd 退回，再重试。');
  }

  // ---------- 校验挂载结果 ----------
  const finalManifest = readJson(manifestFile);
  const finalBundles = finalManifest.dsh.profile.bundles;
  for (const p of targets) {
    if (skipped.some(s => s.startsWith(p.name + '（已有他人'))) continue;
    const linked = path.join(profile, 'node_modules', ...p.name.split('/'));
    if (!fs.existsSync(linked)) { failed.push(p.name + '（没生成链接）'); continue; }
    if (!finalBundles.includes(p.name)) { failed.push(p.name + '（bundle 未启用）'); }
  }
  if (failed.length) die('挂载后的校验没通过：' + failed.join(', ') + '\n备份：' + backup);

  const composed = boot.loadProfileDirectory('dsh', profile, bootPkg);
  if (composed.skippedBundles.length) warn('⚠ 有 bundle 被跳过：' + composed.skippedBundles.join(', '));
  const rows = boot.composeEntries([...composed.layers.map(l => l.patches), composed.patches]);
  const inv = readJson(path.join(store, 'inventory.json'));
  const rowProblems = [];
  for (const exp of inv.pluginRows) {
    const act = rows.find(r => r.id === exp.id);
    if (!act) { rowProblems.push('缺少条目 ' + exp.id); continue; }
    if (exp.disabled !== undefined && !exp.disabledExpression && (act.disabled === true) !== exp.disabled) {
      rowProblems.push('启停状态不一致 ' + exp.id + '（期望 ' + (exp.disabled ? '停用' : '启用') + '，实际 ' + (act.disabled ? '停用' : '启用') + '）');
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
  const skTargets = { dsh: path.join(home, 'skills'), agents: path.join(os.homedir(), '.agents', 'skills') };
  if (fs.existsSync(skSrc)) {
    for (const tier of fs.readdirSync(skSrc)) {
      const dst = skTargets[tier];
      if (!dst) continue;
      fs.mkdirSync(dst, { recursive: true });
      for (const name of fs.readdirSync(path.join(skSrc, tier))) {
        const s = path.join(skSrc, tier, name), d = path.join(dst, name);
        if (fs.existsSync(d)) {
          const bk = path.join(backup, 'skills', tier, name);
          copyTree(d, bk);
          fs.rmSync(d, { recursive: true, force: true });
          skillRes.skipped.push(name + '（已存在，旧版备份到 backups）');
        } else {
          skillRes.installed.push(name);
        }
        copyTree(s, d);
      }
    }
  }
  if (skillRes.installed.length) log('✓ 安装技能：' + skillRes.installed.join(', '));
  if (skillRes.skipped.length) log('· 技能覆盖（旧版已备份）：' + skillRes.skipped.join(', '));

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

  // ---------- 结果 ----------
  result.ok = true;
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
  result.nextSteps = [
    '打开 DeepSeek Harness：左侧栏应出现「技能融合 / 记忆融合 / 功能说明 / Ollama / 清理 / 工作台」等入口。',
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
  if (fpHint.length) log('功能说明：' + fpHint.join('；'));
  log('下一步：打开 DeepSeek Harness，并把中转站地址/密钥填进设置 → 模型。');
  log('==========================================');

  // ---------- 可选：自动启动并等待 GUI ----------
  if (!flag('--no-launch')) {
    try {
      log('\n正在启动 DeepSeek Harness（首次加载插件约 20–60 秒）…');
      const child = spawn(k.exe, [], { detached: true, stdio: 'ignore', windowsHide: false });
      child.unref();
      const port = await waitForPort(child.pid, 120000);
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
function waitForPort(pid, timeoutMs) {
  const script = `$p=${pid}; try { (Get-NetTCPConnection -State Listen -OwningProcess $p -ErrorAction Stop | Where-Object { $_.LocalAddress -in @('127.0.0.1','0.0.0.0','::1') } | Select-Object -First 1 -ExpandProperty LocalPort) } catch { '' }`;
  const start = Date.now();
  return new Promise(resolve => {
    const tick = () => {
      try {
        const r = spawnSync('powershell', ['-NoProfile', '-NonInteractive', '-Command', script], { encoding: 'utf8', windowsHide: true, timeout: 8000 });
        const n = String(r.stdout || '').trim();
        if (n && /^\d+$/.test(n)) return resolve(Number(n));
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
function defaultStore(spec) {
  return path.join(process.env.LOCALAPPDATA || os.tmpdir(), 'DSHPluginsPack', 'v' + spec.version + '-windows');
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
  log('  · 解压 DSH-Plugins-v2.0.0-Services.zip，直接双击它根目录的 SETUP-SERVICES.cmd（那里自带完整安装逻辑，不依赖本包）。');
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
