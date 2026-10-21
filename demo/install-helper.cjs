'use strict';
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const {pathToFileURL} = require('node:url');
const root = __dirname;
const readJson = p => JSON.parse(fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, ''));
const sha = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function die(s) { throw new Error(s); }
function verifyFiles(base) {
 const sums = readJson(path.join(root, 'checksums.json'));
 let count = 0;
 for (const item of sums.files) {
  const f = path.resolve(base, item.path);
  if (!f.startsWith(path.resolve(base) + path.sep)) die('Unsafe checksum path: ' + item.path);
  if (!fs.existsSync(f) || sha(f) !== item.sha256) die('文件校验失败：' + item.path);
  count++;
 }
 console.log('SHA-256 文件校验通过：' + count + ' 个文件。');
}
(async () => {
 const argv = process.argv.slice(2);
 const get = key => argv.includes(key) ? argv[argv.indexOf(key) + 1] : undefined;
 const desktop = get('--desktop-dir');
 const spec = readJson(path.join(root, 'migration.json'));
 if (process.platform !== spec.platform || process.arch !== spec.arch) die('本包仅支持 Windows x64。');
 verifyFiles(root);
 if (argv.includes('--check-only')) return;
 if (!desktop) die('缺少 Desktop 安装目录。请通过 INSTALL.cmd 启动。');
 const exe = path.join(desktop, 'DeepSeek Harness.exe');
 const app = path.join(desktop, 'resources', 'app.asar', 'dsh');
 const cli = path.join(app, 'node_modules', '@deepseek-ai', 'dsh-desktop-host', 'lib', 'cli.js');
 const version = readJson(path.join(app, 'node_modules', '@deepseek-ai', 'dsh-app-boot', 'package.json')).version;
 if (version !== spec.dshVersion) die('目标 DSH 内核版本必须为 ' + spec.dshVersion + '，当前为 ' + version + '。');
 const boot = await import(pathToFileURL(path.join(app, 'node_modules', '@deepseek-ai', 'dsh-app-boot', 'lib', 'index.js')).href);
 const home = path.resolve(process.env.DSH_HOME || path.join(os.homedir(), '.dsh'));
 const profile = path.join(home, 'profiles', 'desktop');
 const manifestFile = path.join(profile, 'package.json');
 if (!fs.existsSync(manifestFile)) die('请先打开 Desktop 一次完成初始化，再从托盘完全退出。');
 const before = readJson(manifestFile);
 const beforeBundles = before.dsh?.profile?.bundles || [];
 if (!['@deepseek-ai/dsh-base', '@deepseek-ai/dsh-web-app'].every(n => beforeBundles.includes(n))) die('目标 profile 不是已初始化的标准 Desktop profile。请先打开同版 Desktop 一次。');
 for (const name of spec.builtinBundles) {
  const manifest = path.join(app, 'node_modules', name, 'package.json');
  if (!fs.existsSync(manifest) || readJson(manifest).version !== version) die('目标 Desktop 缺少同版内置 bundle：' + name);
 }
 const packages = spec.packages.filter(p => p.install);
 const expectedNames = packages.map(p => p.name).concat('dsh-migration-plugin-state');
 const unknownBundles = beforeBundles.filter(n => !spec.builtinBundles.includes(n) && !expectedNames.includes(n));
 if (unknownBundles.length) die('目标含有本迁移包以外的 bundle，请使用新初始化的 Desktop：' + unknownBundles.join(', '));
 const previousOther = Object.keys(before.dependencies || {}).filter(n => !expectedNames.includes(n));
 if (previousOther.length) die('目标已经安装了其他插件。为避免覆盖，脚本停止；请在全新初始化的 Desktop 上迁移。现有包：' + previousOther.join(', '));
 const defaultStore = path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local'), 'DSHPluginMigration', spec.id);
 const store = path.resolve(get('--store') || defaultStore);
 if (store === root || store.startsWith(root + path.sep) || root.startsWith(store + path.sep)) die('持久安装目录不能与解压目录重叠。');
 if (store === home || store.startsWith(home + path.sep)) die('持久目录不能位于 DSH profile 或数据目录内。');
 for (const [name, value] of Object.entries(before.dependencies || {})) {
  const target = name === 'dsh-migration-plugin-state' ? path.join(store, 'payload', 'migration-state') : path.join(store, 'payload', 'node_modules', name);
  if (value !== 'link:' + target.replaceAll('\\', '/') && value !== 'link:' + target) die('目标已有同名插件，且不是本迁移包安装的版本：' + name + '。脚本停止。');
 }
 console.log('复制插件到持久目录：' + store);
 fs.mkdirSync(store, {recursive: true});
 if (fs.existsSync(path.join(store, 'migration.json'))) {
  const previous = readJson(path.join(store, 'migration.json'));
  if (previous.id !== spec.id) die('安装目录属于其他迁移包。');
 } else if (fs.readdirSync(store).length) die('安装目录非空且没有迁移标识，脚本停止。');
 fs.cpSync(root, store, {recursive: true});
 verifyFiles(store);
 const backup = path.join(store, 'backups', new Date().toISOString().replace(/[:.]/g, '-'));
 fs.mkdirSync(backup, {recursive: true});
 for (const name of ['package.json', 'pnpm-lock.yaml', 'pnpm-workspace.yaml', 'cordis.yml', 'cordis.patch.yml']) {
  if (fs.existsSync(path.join(profile, name))) fs.copyFileSync(path.join(profile, name), path.join(backup, name));
 }
 console.log('安装前备份保存在：' + backup);
 const enabledBuiltins = spec.builtinBundles.filter(n => !beforeBundles.includes(n));
 boot.writeProfileBundles(profile, before, [...spec.builtinBundles, ...beforeBundles.filter(n => !spec.builtinBundles.includes(n))]);
 if (enabledBuiltins.length) console.log('启用同版 Desktop 自带的内置 bundle：' + enabledBuiltins.join(', '));
 const env = {...process.env, ELECTRON_RUN_AS_NODE: '1', DSH_HOME: home};
 const run = args => {
  const r = spawnSync(exe, ['--expose-internals', cli, 'plugin', '--profile', 'desktop', ...args], {cwd: store, env, stdio: 'inherit', windowsHide: true});
  if (r.error) throw r.error;
  if (r.status !== 0) die('官方安装命令失败，退出码 ' + r.status + '。安装日志中包含原因；备份：' + backup);
 };
 const steps = packages.map(p => ({...p, dir: path.join(store, 'payload', 'node_modules', p.name)}));
 steps.push({name: 'dsh-migration-plugin-state', version: '1.0.0', dir: path.join(store, 'payload', 'migration-state')});
 for (let i = 0; i < steps.length; i++) {
  const p = steps[i];
  const m = readJson(path.join(p.dir, 'package.json'));
  if (m.name !== p.name || m.version !== p.version) die('包身份校验失败：' + p.name);
  console.log('\n[' + (i + 1) + '/' + steps.length + '] 安装 ' + p.name + '@' + p.version);
  run(['add', '--offline', '--ignore-scripts', '--save-exact', 'link:' + p.dir.replaceAll('\\', '/')]);
 }
 const final = readJson(manifestFile);
 for (const p of steps) {
  const anchored = fs.realpathSync(path.join(profile, 'node_modules', p.name));
  if (anchored.toLowerCase() !== fs.realpathSync(p.dir).toLowerCase()) die('安装后的链接不匹配：' + p.name);
  if (!final.dsh.profile.bundles.includes(p.name)) die('bundle 没有启用：' + p.name);
 }
 const composed = boot.loadProfileDirectory('dsh', profile, path.join(app, 'package.json'));
 if (composed.skippedBundles.length) die('安装后的 profile 出现被跳过的 bundle。');
 const rows = boot.composeEntries([...composed.layers.map(l => l.patches), composed.patches]);
 const inventory = readJson(path.join(root, 'inventory.json'));
 for (const expected of inventory.pluginRows) {
  const actual = rows.find(r => r.id === expected.id);
  if (!actual || actual.name !== expected.name) die('插件组合检查失败：' + expected.id);
  if (!expected.disabledExpression && (actual.disabled === true) !== expected.disabled) die('插件启停状态检查失败：' + expected.id);
 }
 const report = {completedAt: new Date().toISOString(),runtimeVersion: version,home,profile,store,backup,enabledBuiltins,installedPackages: packages.length,stateBundle: 'dsh-migration-plugin-state',verifiedRows: inventory.pluginRows.length,skippedSourcePackages: spec.packages.filter(p=>!p.install).map(p=>p.name)};
 fs.writeFileSync(path.join(store, 'installation-result.json'), JSON.stringify(report, null, 2));
 console.log('\n安装及组合配置验证通过。可启动 Desktop。模型/API、登录、壁纸资源等请在新电脑单独配置。');
 console.log('请保留持久目录：' + store + '；原 ZIP 和解压目录可移走。');
})().catch(e => { console.error('\n安装未完成：' + (e.stack || e.message)); process.exitCode = 1; });
