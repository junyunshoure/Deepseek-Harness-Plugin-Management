'use strict';
// v1.0.0-patch.1 安装器：把 reverse-engineer-anything 技能改成「短入口 + 按需手册」
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');

const root = __dirname;
const readJson = p => JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
const sha = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const die = s => { throw new Error(s); };

function verifyFiles(base) {
  const sums = readJson(path.join(root, 'checksums.json'));
  let count = 0;
  for (const item of sums.files) {
    const f = path.resolve(base, item.path);
    if (!f.startsWith(path.resolve(base) + path.sep)) die('Unsafe checksum path: ' + item.path);
    if (!fs.existsSync(f) || sha(f) !== item.sha256) die('文件校验失败：' + item.path);
    count++;
  }
  return count;
}

function descriptionOf(file) {
  const text = fs.readFileSync(file, 'utf8');
  const m = text.match(/^description:\s*(.+)$/m);
  return m ? m[1].trim() : '';
}

(async () => {
  const argv = process.argv.slice(2);
  const get = key => (argv.includes(key) ? argv[argv.indexOf(key) + 1] : undefined);

  const spec = readJson(path.join(root, 'patch.json'));
  if (process.platform !== 'win32') die('本补丁仅面向 Windows x64 的 DSH Desktop 整合包。');

  const count = verifyFiles(root);
  console.log('SHA-256 文件校验通过：' + count + ' 个文件。');
  // 兼容两种写法：脚本转发的是 --check-only，用户手敲可能是 -CheckOnly
  const checkOnly = ['--check-only', '-check-only', '-CheckOnly', '--CheckOnly']
    .some(flag => argv.includes(flag));
  if (checkOnly) {
    console.log('仅自检，未改动任何文件（去掉 -CheckOnly 才会真正应用）。');
    return;
  }

  const home = process.env.USERPROFILE || os.homedir();
  const skillDir = path.resolve(get('--skill-dir') || path.join(home, '.agents', 'skills', spec.skill.name));
  const srcDir = path.join(root, 'skill', spec.skill.name);
  const srcSkill = path.join(srcDir, 'SKILL.md');
  const srcManual = path.join(srcDir, 'references', 'manual-cli.md');

  console.log('目标技能目录：' + skillDir);
  const existed = fs.existsSync(path.join(skillDir, 'SKILL.md'));
  const beforeSize = existed ? fs.statSync(path.join(skillDir, 'SKILL.md')).size : 0;
  const beforeDesc = existed ? descriptionOf(path.join(skillDir, 'SKILL.md')).length : 0;

  let backup = null;
  if (existed) {
    const store = path.join(process.env.LOCALAPPDATA || path.join(home, 'AppData', 'Local'), 'DSHPluginMigration', spec.id);
    backup = path.join(store, 'backup-' + new Date().toISOString().replace(/[:.]/g, '-'));
    fs.mkdirSync(backup, { recursive: true });
    fs.cpSync(skillDir, path.join(backup, spec.skill.name), { recursive: true });
    console.log('原技能已备份：' + backup);
  } else {
    console.log('未发现同名技能，将新建一份（不影响其它技能）。');
  }

  fs.mkdirSync(path.join(skillDir, 'references'), { recursive: true });
  fs.copyFileSync(srcSkill, path.join(skillDir, 'SKILL.md'));
  fs.copyFileSync(srcManual, path.join(skillDir, 'references', 'manual-cli.md'));

  // 校验：写入内容逐字节一致
  for (const rel of [['SKILL.md', srcSkill], [path.join('references', 'manual-cli.md'), srcManual]]) {
    const dst = path.join(skillDir, rel[0]);
    if (sha(dst) !== sha(rel[1])) die('写入后校验失败：' + rel[0]);
  }
  const afterSize = fs.statSync(path.join(skillDir, 'SKILL.md')).size;
  const afterDesc = descriptionOf(path.join(skillDir, 'SKILL.md')).length;
  if (!afterDesc) die('新技能缺少 description，会导致无法被自动触发。');

  // 确认没有重新注册 MCP（本补丁只碰技能文件）
  const cordis = path.join(home, '.dsh', 'cordis.patch.yml');
  const cordisText = fs.existsSync(cordis) ? fs.readFileSync(cordis, 'utf8') : '';
  const mcpRegistered = /^\s*-\s*insert:/m.test(cordisText) && /rea-mcp/.test(cordisText) && !/^#\s*-\s*insert:/m.test(cordisText);

  const report = {
    completedAt: new Date().toISOString(),
    patch: spec.id,
    skillDir,
    backup,
    skillBody: { beforeBytes: beforeSize, afterBytes: afterSize },
    descriptionChars: { before: beforeDesc, after: afterDesc },
    manual: path.join(skillDir, 'references', 'manual-cli.md'),
    reaMcpInsertActive: mcpRegistered,
    rollback: backup ? '把 ' + path.join(backup, spec.skill.name) + ' 复制回 ' + skillDir : '删除新建的 ' + skillDir,
  };
  const store = path.join(process.env.LOCALAPPDATA || path.join(home, 'AppData', 'Local'), 'DSHPluginMigration', spec.id);
  fs.mkdirSync(store, { recursive: true });
  fs.writeFileSync(path.join(store, 'patch-result.json'), JSON.stringify(report, null, 2) + '\n');

  const pct = beforeSize ? Math.round((1 - afterSize / beforeSize) * 100) : null;
  console.log('\n补丁已应用。');
  console.log('- 技能正文：' + beforeSize + ' → ' + afterSize + ' 字节' + (pct === null ? '' : '（减少 ' + pct + '%）'));
  console.log('- 常驻描述：' + beforeDesc + ' → ' + afterDesc + ' 字符');
  console.log('- 按需手册：' + report.manual);
  console.log('- REA MCP 仍处于禁用：' + (mcpRegistered ? '否（检测到 insert 未注释，请复查）' : '是'));
  console.log('- 回滚：' + report.rollback);
  console.log('技能描述即时刷新，无需重启 Desktop；新会话即可看到短入口。');
})().catch(e => {
  console.error('\n补丁未应用：' + (e.stack || e.message));
  process.exitCode = 1;
});
