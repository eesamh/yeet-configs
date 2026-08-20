---
name: stacked-parallel-build
description: Orchestrate a set of Jira tickets that share a real dependency graph (not a strict linear epic) across parallel, worktree-isolated agents, using git-spice to track the true stack/fan-in shape and /critique per completed leg. Use when 3+ discrete tickets under one epic/feature need to be built together instead of one at a time, and some of them are genuinely independent of each other.
---

# Stacked parallel build

`/plan-epic` plans one ticket at a time on purpose ("never plan two tickets in parallel") and `/build` provisions exactly one worktree for exactly one branch. Neither handles a set of tickets where some are independent siblings and one or more depend on *more than one* sibling. This skill fills that gap: it resolves the real dependency graph, fans work out across isolated worktrees where the graph allows it, and serializes only where the graph requires it.

**Precondition — check before doing anything else:** every ticket in the set names a common root dependency (a foundation/skeleton ticket). That root must already be **merged to the repo's default branch**, not just pushed. If it's only on its own feature branch, stop and tell the human — starting from an unmerged root means every leg silently depends on a branch that could still change or be abandoned. Verify with `git log main --oneline | grep <root-ticket-id>` or by checking the PR's merge status, not by assuming.

## Step 1 — Resolve the dependency graph

For each ticket, fetch its Jira description and read the `Depends on: X, Y` line. Build a DAG restricted to the tickets actually in this batch (ignore dependencies outside the set except to flag them — see below). Partition into **waves** by topological sort:

- **Wave 0:** tickets whose only in-set dependency is the already-merged root.
- **Wave N:** tickets depending only on tickets in waves `< N`.

Tag each ticket:
- **`leaf`** — depends on nothing else in the set. Safe to build fully in parallel with other leaves in its wave.
- **`fan-in`** — depends on **2 or more** tickets in the set. Do not stack this on top of one parent and merge the other in by hand — that defeats the point of a stacking tool and silently privileges one parent's diff over the other's. Instead: this ticket does not start until **all** of its in-set parents have merged to the default branch, and it branches fresh from the updated default branch, not from either parent's branch.
- **`blocked-external`** — depends on a ticket outside the batch. Schedule it for implementation like any other ticket in its wave, but flag explicitly that its PR cannot close until the external ticket lands. Say so in the PR description and don't chase it as if it were a bug in this batch.

Write the graph to `plans/stack-context-<label>.md` (same spirit as `/plan-epic`'s `epic-context.md`) — ticket → wave → tag → dependencies. This is the file you re-read on each wave transition instead of holding the whole graph in conversation.

## Step 2 — Confirm the wave plan with the human

Show a table (ticket, wave, tag, depends-on) and a mermaid graph before creating anything. Get explicit confirmation of wave order and any `blocked-external` calls before Step 3 — this is the one place a wrong read of the Jira dependency text turns into wasted worktrees.

## Step 3 — Per wave, in order (tickets *within* a wave run concurrently)

Waves are a barrier: don't start wave N+1 until every wave-N ticket has a merged PR (fan-in tickets in wave N+1 need that merge to exist, not just be opened). Within a wave, everything below can happen at once.

For each ticket in the current wave:

1. **Confirm before creating its worktree.** Branch name follows this repo's convention (`CLAUDE.md` → Git Workflow): `{username}/{jira-ticket}/{short-description}` — e.g. `eesam/BBH-2421/chaptercard-engagement-variant`. (Note: the generic `/build` skill defaults to a different `kinano/{ticket}-{desc}` format — don't use that default here.) Base the branch on the current tip of the default branch (all waves) — never on a sibling's unmerged branch, even for same-wave tickets that happen to touch adjacent code.
2. After the worktree is created, **verify it completed cleanly** — branch checked out, `.env.local` present, `graphql:codegen` ran (the `post-worktree-setup.py` hook should have handled this) — before handing it to an agent. If `git worktree add` fails or is interrupted, clean up immediately with `git worktree prune` rather than leaving a broken entry.
3. **Track the branch:** `git-spice branch track --base main` (or the relevant base) from inside the worktree.
4. **Spawn one agent per ticket**, named after a pop-culture/meme-worthy icon per the standing identity convention (Regina George, Blair Waldorf, Taylor Swift, SpongeBob, Nicki Minaj, Ice Spice, etc. — mix in a deliberately unglamorous one too). One agent per ticket by default; only fan out multiple agents on a single ticket if that ticket's own scope is large enough to need it — don't reflexively swarm every leg.
5. **Give each agent, upfront, the facts that shape *what* it builds** — not just the ticket text. Pull from `CLAUDE.md`'s conventions section and this project's memory (`feedback`/`project` entries) for whatever the ticket is likely to touch, e.g.:
   - New article/content card → extend `ContentCardVariant`, don't build a parallel component.
   - New Today Tab card → higher-tier candidate in an existing `TODAY_SKELETON` slot, not a new slot.
   - Any new/changed GraphQL field, query, or mutation → needs a companion `pets-mesh` PR (read the `pets-mesh-permissions` skill first) and, if user-scoped, must gate on `uuid` from `useUserContext()`.
   - WHH/Today Tab Figma work → expect untokenized values; snap to nearest token with an inline comment, preserve relative type-scale hierarchy, don't ask the user.
   - Any owner-supplied value (pet name, free text) reaching `dangerouslySetInnerHTML` or `parse(...)` → keep it out of the HTML string entirely (JSX text node) or run it through `escapeHtml`.
   Tell the agent to run `/plan-task` itself first if `plans/<ticket-id>.plan.md` doesn't already exist, implement, run the repo's test + typecheck commands, and **stop before committing** — the orchestrator controls the commit/PR step so `/finish-up` happens on a clean, reviewed diff. Before stopping, the agent runs `/handoff` to write `plans/handoff-<ticket-id>.md` — this is what a `fan-in` ticket's agent reads (in addition to its own upfront context in this step) once its parents have merged, instead of re-deriving what each parent actually did from the diff alone.

## Step 4 — Finish up per leg

Once a wave's agents finish, run `/finish-up` for each ticket independently (not batched into one commit) so each gets its own PR, its own risk-tiered review, and its own Jira transition. `blocked-external` tickets still go through `/finish-up` and get a real PR — just a draft one that stays open with the blocker named, not a failure to clean up.

## Step 5 — Wave gate

Before starting the next wave, check which of this wave's PRs have **actually merged** (`gh pr view <n> --json state,mergedAt`), not just opened. Report status to the human: "wave 1 done: BBH-2421 ✅ merged, BBH-2423 ✅ merged, BBH-2424 still in review — hold wave 2's fan-in ticket until it lands, or proceed with what's ready?" Don't assume merge just because a PR exists.

## Step 6 — Final summary

`git-spice log short` plus a table of ticket → branch → PR → status once every wave is through. Update `plans/stack-context-<label>.md` one last time so a future session (or a compacted one) can pick the state back up without re-deriving the graph.
