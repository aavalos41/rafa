# Rafa Skills

Skills are Claude Code slash commands that power the human-driven planning phases of the Rafa workflow. Install them once and use them across any project.

---

## The full workflow

```
/grill-me          → stress-test the plan (interview style)
/to-prd            → synthesize into a structured PRD
/to-rafa-tasks     → break PRD into TASKS.json (this folder)
─────────────────────────────────────────────────────────
./scripts/create-linear-tasks.sh   → sync tasks to Linear
./afk-rafa.sh -n N                 → Rafa executes autonomously
```

The first three steps are human-driven in Claude Code. The last two are automation.

---

## Skills in this folder (install these)

### `to-rafa-tasks`
**Location:** `skills/to-rafa-tasks/SKILL.md`

A Rafa-specific adaptation of the `to-issues` pattern. Converts a PRD or plan into tasks written directly into `TASKS.json`, with Rafa's schema: `status`, `owner` (bot/human/both), `dependencies`, `priority`, and `tdd` fields. This is the bridge between your planning and Rafa's execution.

**To install in Claude Code:**
```bash
# Copy to your global Claude skills directory
cp -r skills/to-rafa-tasks ~/.claude/skills/

# Or install per-project by placing it in the project's .claude/skills/ folder
mkdir -p .claude/skills
cp -r skills/to-rafa-tasks .claude/skills/
```

---

## External skills (install from Matt Pocock's repo)

These skills work as-is with no Rafa-specific changes. Install them from the source:

**Source:** https://github.com/mattpocock/skills

### `grill-me`
Interviews you one question at a time about a plan, stress-testing every assumption and decision branch. Use at the start of any feature to surface unknowns before writing a PRD.

```bash
# Install
cp -r path/to/mattpocock-skills/skills/productivity/grill-me ~/.claude/skills/
```

### `to-prd`
Synthesizes the current conversation into a structured PRD (Problem Statement, Solution, User Stories, Implementation Decisions, Testing Decisions). Run after `/grill-me`.

```bash
cp -r path/to/mattpocock-skills/skills/engineering/to-prd ~/.claude/skills/
```

### `tdd`
Red-green-refactor guidance for manual sessions. Useful when you want to work on a task yourself before handing off to Rafa, or when pairing with Claude on a complex piece.

Note: Rafa applies TDD automatically during autonomous execution when `tdd_enabled: true` is set in `rafa-config.json` — you don't need to run this skill manually for Rafa's loop.

```bash
cp -r path/to/mattpocock-skills/skills/engineering/tdd ~/.claude/skills/
```

---

## Cloning Matt Pocock's skills

```bash
git clone https://github.com/mattpocock/skills.git /tmp/mp-skills

# Then copy individual skills
cp -r /tmp/mp-skills/skills/productivity/grill-me ~/.claude/skills/
cp -r /tmp/mp-skills/skills/engineering/to-prd ~/.claude/skills/
cp -r /tmp/mp-skills/skills/engineering/tdd ~/.claude/skills/
```

---

## Verifying installation

In Claude Code, run `/help` and look for your skill names in the slash commands list. Or just type `/grill-me` — if it loads, it's installed.
