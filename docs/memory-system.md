# Memory System Design / 记忆系统设计

## Overview / 概述

The memory system provides persistent, structured knowledge that survives across
conversation sessions and context window compactions. It is file-based, managed
by the AI through standard tool calls (Read/Write/Edit), and designed for
graceful degradation as context windows fill.

记忆系统提供跨会话、跨上下文压缩的持久化结构化知识。基于文件、由 AI 通过标准工具调用
（Read/Write/Edit）管理，并针对上下文窗口填满时的优雅降级进行了设计。

## Architecture / 架构

```
memory/
├── MEMORY.md              # Always-loaded index (< 200 lines)
├── user-profile.md        # Type: user
├── feedback-testing.md    # Type: feedback
├── project-auth.md        # Type: project
├── reference-tracker.md   # Type: reference
└── diary/                 # Daily diary entries
    ├── 2026-07-10.md
    ├── 2026-07-11.md
    └── diary.jsonl         # Machine-readable backup
```

## Design Principles / 设计原则

### 1. Two-Tier Loading / 两级加载

- **MEMORY.md** (always loaded): A concise index of all memories, each entry
  under 150 characters. This gives the AI a map of what it knows without
  consuming context window on full content.
- **Individual files** (loaded on demand): Full memory content, read only
  when relevant to the current conversation.

### 2. Typed Categories / 分类类型

Each memory has a `type` in its YAML frontmatter:

| Type | Purpose | Volatility |
|------|---------|------------|
| `user` | Who the user is | Low — changes slowly |
| `feedback` | How to behave | Medium — corrections accumulate |
| `project` | What's happening | High — changes frequently |
| `reference` | Where to find things | Low — URLs/locations |

### 3. Actionable Structure / 可执行结构

Every `feedback` and `project` memory includes:
- **The fact/rule itself** (lead sentence)
- **Why:** The motivation or incident behind it
- **How to apply:** When and where this guidance kicks in

The "Why" enables judgment in edge cases rather than blind rule-following.

### 4. Cross-References / 交叉引用

Memories link to related memories using `[[name]]` syntax:
```markdown
See also [[feedback-testing]] for the related incident.
```
Links that don't match an existing memory are fine — they mark
something worth writing later.

### 5. Anti-Patterns / 反模式

What NOT to store in memory:
- Code patterns derivable from reading current source
- Git history (use `git log` / `git blame`)
- Debugging solutions (the fix is in the code)
- Ephemeral task state (use conversation context)

## Lifecycle / 生命周期

1. **Creation**: AI writes the file + adds index entry to MEMORY.md
2. **Update**: AI edits existing file when new information arrives
3. **Verification**: Before acting on a memory, AI verifies it against
   current state (files may have been renamed/removed since memory was written)
4. **Pruning**: Stale or incorrect memories are updated or removed

## Diary Subsystem / 日记子系统

Daily diary entries serve a different purpose from memories:
- **Memories** = reusable knowledge for future conversations
- **Diary** = personal record of experiences and reflections

Diary entries are stored in both Markdown (human-readable) and JSONL
(machine-parseable) formats for redundancy.
