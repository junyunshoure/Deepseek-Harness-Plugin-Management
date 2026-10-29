#!/usr/bin/env node
/**
 * 发消息.mjs —— 给另一个场景留一条消息（纯文件，不调用任何接口）
 *
 * 用法：
 *   node scripts\发消息.mjs --to <场景id> "内容"
 *   node scripts\发消息.mjs --to <场景id> "内容" --root <工作台根>   # 隔离根测试
 *   node scripts\发消息.mjs --list
 *
 * 只做两件事：
 *   1. 目标场景的正文（项目信息.md / 场景私有记忆.md）末尾追加 ## 〇-通知 段一条
 *   2. workbench\memory\_共享记忆\_跨场景通知.md 追加一条（跨场景看板）
 *
 * 本机适配（2026-10-29）：
 *   - 记忆根 → workbench\memory（上游模板是 引擎数据\.dsh\场景记忆）
 *   - 时间用本地时区（上游 toISOString 是 UTC，会比本机早 8 小时）
 *   - 支持 --root（上游只认环境变量，隔离根测试会静默写进真身 → 假成功，已修）
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const argv = process.argv.slice(2)
const val = (k) => { const i = argv.indexOf(k); return i >= 0 ? (argv[i + 1] || '') : '' }

// 2026-10-29 修第 13 个 bug：原 ROOT 只读 DSH_WORKBENCH_ROOT 与脚本所在目录，不认 --root。
//   后果：在隔离根以 `--root $T` 测试时，工具报 `✓ 已发` 却静默写进真身
//   workbench\memory\<场景>，并且把 --root 的值当成消息正文一起写进记忆（已污染过一次，见报告会话 14）。
const ROOT = val('--root') || process.env.DSH_WORKBENCH_ROOT || path.resolve(HERE, '..')
const MEM = process.env.DSH_SCENE_MEMORY || path.join(ROOT, 'workbench', 'memory')
const BOARD = path.join(MEM, '_共享记忆', '_跨场景通知.md')

const to = val('--to')
// 带值 flag 的**值**不能进正文：原写法只跳过 --to 的值，于是 `--root D:\...` 的路径被拼进消息。
const FLAGS_WITH_VALUE = new Set(['--to', '--root', '--场景'])
const text = argv
  .filter((a, i) => !a.startsWith('--') && !FLAGS_WITH_VALUE.has(argv[i - 1]))
  .join(' ')
  .trim()

if (argv.includes('--list')) {
  const t = fs.existsSync(BOARD) ? fs.readFileSync(BOARD, 'utf8').split('\n').filter(l => l.trim().startsWith('-')) : []
  console.log(t.slice(-15).join('\n') || '（还没有消息）')
  process.exit(0)
}
if (!to || !text) { console.log('用法：node scripts\\发消息.mjs --to <场景id> "内容" [--root <工作台根>]'); process.exit(1) }

// 时间用本地时区（上游用 toISOString＝UTC，会比本机时间早 8 小时，和 场景记忆.mjs 的本地时间口径不一致）
const d = new Date(); const p2 = (n) => String(n).padStart(2, '0')
const ts = `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())} ${p2(d.getHours())}:${p2(d.getMinutes())}`
const line = '- [' + ts + '] → ' + to + '：' + text

fs.mkdirSync(path.dirname(BOARD), { recursive: true })
if (!fs.existsSync(BOARD)) fs.writeFileSync(BOARD, '# 跨场景通知\n\n', 'utf8')
fs.appendFileSync(BOARD, line + '\n', 'utf8')

// 正文文件：本机布局叫 项目信息.md，上游 v2 叫 场景私有记忆.md —— 两个都认，优先已有者；
// DSH_SCENE_MAIN 可强制锁定（与 场景记忆.mjs 的 mainFileOf 同口径）。
const pick = (dir) => {
  const lock = process.env.DSH_SCENE_MAIN
  if (lock) { const q = path.join(dir, lock); if (fs.existsSync(q)) return q }
  for (const f of ['项目信息.md', '场景私有记忆.md']) {
    const q = path.join(dir, f)
    if (fs.existsSync(q)) return q
  }
  return path.join(dir, '项目信息.md')
}
const memFile = pick(path.join(MEM, to))
if (fs.existsSync(memFile)) {
  let t = fs.readFileSync(memFile, 'utf8')
  // 通知段只建一次；段内每行紧挨着，不夹空行（原实现每次都在行间插空行，读起来像断段）
  if (!t.includes('## 〇-通知')) {
    t = t.replace(/\s*$/, '') + '\n\n## 〇-通知\n'
  }
  if (!t.endsWith('\n')) t += '\n'
  t += line + '\n'
  fs.writeFileSync(memFile, t, 'utf8')
  console.log('✓ 已发：' + to + '（正文 + 看板）')
} else {
  console.log('! 目标场景没有记忆文件：' + memFile + '（只写进了看板）')
  console.log('✓ 已发：' + to + '（仅看板）')
}
