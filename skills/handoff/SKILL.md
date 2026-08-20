---
name: handoff
description: Write a handoff document when a task is passing to the next agent or session — a sequenced "part 2," a dependency that just unblocked, or simply stopping mid-task. Captures the goal, verified current state, in-flight files, likely-next files, dead ends, and next steps so the receiver doesn't re-derive context or repeat a rejected approach. Also covers consuming a handoff doc as the receiving agent.
---

# Task handoff

A handoff document exists to answer one question for whoever picks this up next: **what would I have to re-discover if this document didn't exist?** Every section below exists to pre-empt one specific kind of rediscovery. If a section would just repeat what `git diff` already shows, that section is wrong — write what isn't visible in the diff.

## When to use this

- You're stopping mid-task and there's a known next step, a dependent ticket, or a "part 2."
- A different agent or worktree is about to pick up work that depends on what you just did (this is the standard hand-off point between waves in `stacked-parallel-build`, and between tickets in `plan-epic`).
- You're about to run low on context and want the next session to pick up cleanly instead of re-deriving state from scratch.

## Writing a handoff (as the outgoing agent)

**Ground every section in something verifiable — don't narrate from memory.** Run `git status` / `git diff --stat`, re-run the test/typecheck commands, and grep for `TODO`/`FIXME` added in this diff before writing anything. A handoff that says "the mutation is wired up" when the last test run actually failed is worse than no handoff at all, because it costs the receiver trust in every other section too.

Save to `plans/handoff-<ticket-or-label>.md` (same `plans/` convention as `/plan-task`'s plan files and decisions scratch file). Structure:

```markdown
## Handoff: <ticket-id or label>
_Written by <who/agent name> on <date> — branch: <branch>, worktree: <path if applicable>_

### Goal
The outcome this is working toward, in 1-2 sentences — not just the ticket ID, the actual desired end state. Link the ticket if there is one.

### Current State
What's actually true right now, verified: what's implemented, what the last test/typecheck run actually showed (pass/fail, not "should pass"), what's stubbed or incomplete. State it as fact you just checked, not as recollection.

### Files Actively Being Edited
Files with incomplete, in-progress changes right now — and *what specifically* is incomplete in each (a half-written function, a TODO, a test that doesn't yet exist). This is not "files changed" — `git diff --stat` already gives that. This is "don't assume these are finished."

### Files Likely Needed Next
Files nobody has touched yet but the plan/ticket scope implies will need changes. Pull this from the plan file (`plans/<ticket-id>.plan.md`) if one exists, diffed against what's actually been touched so far. Keep this list separate from the section above — conflating "in-progress" with "not started" is the single most common way a handoff misleads its reader.

### Attempted and Rejected
Approaches that were tried and abandoned, and why — a human correction, a test that revealed a wrong assumption, a design that didn't fit a constraint discovered mid-implementation. This is the highest-value section and the easiest one to skip. If a fresh agent doesn't know approach X was already tried and rejected, it will propose X again. If genuinely nothing was rejected, say so explicitly rather than leaving the section thin and ambiguous.

### Next Steps
Concrete, ordered actions — not "finish the feature," but "wire the mutation's onError handler; the happy path is done but AC-3's error state isn't handled yet." Tie each to an acceptance criterion or plan step if one exists.

### Open Questions / Blockers
Anything that needs a human decision before the next agent can proceed without guessing. Omit this section entirely if there's nothing here — don't pad it.
```

**Commit this file, deliberately** — unlike the `/plan-task` decisions-scratch-file (which is consumed same-session by `/critique` and deleted, never committed), a handoff doc's entire purpose is to survive a session boundary, an agent boundary, or a worktree teardown. An uncommitted file in a worktree that later gets cleaned up (see `delete-dead-worktrees`) disappears along with it. Note in the commit message that it's a temporary handoff doc meant to be deleted once consumed, the same way `/plan-task`'s acceptance-test commit is understood to be a stepping stone, not a permanent artifact.

## Consuming a handoff (as the receiving agent)

1. Check for `plans/handoff-<ticket-or-label>.md` before doing anything else — same instinct as `/plan-epic` checking for an Epic Context file.
2. **Treat every claim in it as something to verify, not ground truth** — the same discipline `finish-up` applies to docstrings and PR narratives. State may have drifted if anything landed between the handoff being written and now. Re-run the test/typecheck commands yourself before trusting the "Current State" section.
3. Fold what you need into your own working context, then **delete the handoff file** (or note in your own eventual handoff that it was consumed) so it doesn't linger and mislead a later reader with stale state.
4. If "Attempted and Rejected" conflicts with what looks like a reasonable approach to you, don't silently re-attempt it — surface the conflict to the human first.
