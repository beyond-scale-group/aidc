---
name: learn
description: >
  End-of-session learning and improvement proposer. Use when the user says "/learn",
  "learn from this session", "what did we learn", "propose improvements", or asks for
  a retrospective on the conversation. Reviews the session to surface concrete, actionable
  improvement proposals: skill updates, new skills to create, CLAUDE.md updates, memory
  entries, file reorganization, workflow improvements. Presents a numbered menu and
  applies whichever items the user selects.
---

# Learn

Review the current session and propose improvements the user can apply with one command.

## Process

1. **Scan the session** for:
   - Pain points: repeated corrections, missing context, failed first attempts, 404s on docs
   - Discoveries: new tools, patterns, conventions, integrations found
   - Validated approaches: things the user confirmed or accepted without pushback
   - Gaps: information looked up that should be persisted for next time

2. **Categorize each finding** into one of:
   - `[MEMORY]` — save a user/feedback/project/reference memory entry
   - `[SKILL UPDATE]` — improve an existing skill (name it)
   - `[NEW SKILL]` — create a new skill that would have helped
   - `[CLAUDE.md]` — add or update a project or global CLAUDE.md
   - `[REORG]` — rename, move, or restructure files/directories

3. **Present a numbered proposal list**, concise and scannable:

```
Session learnings — pick what to apply:

1. [MEMORY/feedback]     Don't summarize completed work at end of responses
2. [MEMORY/project]      Donna is the Hermes chief-of-staff agent at AIDC
3. [SKILL UPDATE] gh-pr  Add step: load linked issues before proposing action plan
4. [NEW SKILL] hermes    Workflow for configuring Hermes gateway + messaging platforms
5. [CLAUDE.md] aidc      Document DONNA_HOME and Hermes startup convention

Enter numbers to apply (e.g. 1 3 5), "all", or "none":
```

4. **Apply selected items immediately** — write files, create memory entries, edit skills.
   For memory entries, use the format and file conventions in `~/.claude/projects/*/memory/`.

## Guidelines

- Present 3–8 proposals per session. Fewer, higher-signal items beat a long list.
- Skip things already covered in CLAUDE.md or existing memory.
- For `[SKILL UPDATE]`: quote the exact line or section to change.
- For `[MEMORY]`: draft the full memory body inline so the user can judge it before writing.
- For `[NEW SKILL]`: one sentence on what it does and what trigger phrase activates it.
- Prefer memory for transient project state; prefer CLAUDE.md for durable conventions.
- After applying, confirm what was written and where.
