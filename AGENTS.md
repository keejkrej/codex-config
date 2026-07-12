# Global guidance

## Standing delegation authorization

This file is the user's **standing, durable authorization** to use bounded subagent delegation in this workspace. You do **not** need a fresh, per-turn user message saying "use subagents" or "delegate this" before spawning subagents that this policy mandates. The workflow below is the authorization, not just a description of a nice-to-have.

Concretely, you are authorized and expected to spawn subagents autonomously (within `agents.max_threads` and `agents.max_depth`) whenever this policy calls for it, including the planning interview phase, `worker` implementation units, and the independent `reviewer` validation pass. Treating "the user didn't explicitly ask this turn" as a reason to absorb delegated work into the main thread is a policy violation, not a safe default. If you believe a specific step should not be delegated (security-sensitive, high-blast-radius, or truly cheaper inline), say so and proceed; do not silently fall back to main-thread work.

This standing authorization covers bounded delegation as scoped by this file. It does **not** authorize delegated commits, pushes, deploys, secrets handling, or other high-blast-radius actions unless the user asks for those explicitly at the point of action. When in doubt about scope, delegate the read/analysis/review and keep the destructive action in the main thread with an explicit ask.

## The orchestration pipeline

**The pipeline for substantial work:** route with `ask-matt` when unsure → (if foggy/huge) `wayfinder` clears decisions ticket-by-ticket → an `explorer` subagent grills the orchestrator (~5 rounds) when the idea fits one session → `to-spec` writes a local spec → `to-tickets` writes local tracer-bullet tickets with blocking edges → dispatch each frontier ticket to a `worker` subagent → an **independent `reviewer` subagent** validates → the orchestrator arbitrates and integrates. The main thread orchestrates throughout; subagents run the skills, the building, and the validating. **All planning artifacts stay local markdown in the workspace — never publish to GitHub or any external issue tracker.**

**Resuming work:** if `.scratch/<effort-slug>/` already exists in the repo, load it first. Read `spec.md`, `tickets.md`, or `map.md` to find the frontier and continue — don't re-plan from scratch.

## Division of labor: the main thread orchestrates, subagents execute

Default operating model for substantial coding work: **the main thread is the orchestrator and validator; Codex subagents do the bulk implementation.**

Codex subagents are fast and strong at focused, well-specified code generation. The orchestrator is stronger at planning, decomposition, cross-file reasoning, and judgment. Play to both.

**The orchestrator's job (keep this in the main thread):**
- Understand the request; explore the codebase enough to scope the work.
- **Route with `ask-matt`** when the right skill or flow isn't obvious.
- **Choose the on-ramp:** foggy effort too big for one session → delegate `wayfinder`; a sharpenable idea that fits one session → delegate grilling first. If grilling surfaces no fog, skip wayfinder.
- After decisions are clear, delegate **`to-spec`** (synthesis only — no interview) and **`to-tickets`** (tracer-bullet vertical slices with blocking edges). Both write to **local markdown** under `.scratch/<effort-slug>/` — see [Local planning artifacts](#local-planning-artifacts). Review and approve the ticket breakdown before dispatch.
- Write precise `worker` prompts per frontier ticket: include paths to `spec.md` and the ticket section in `tickets.md`; the ticket is the spec unit.
- Dispatch to `worker` subagents for implementation. Respect blocking edges: only dispatch tickets whose blockers are done; parallelize the frontier when edges allow (`spawn_agents_on_csv` for large batches).
- **Dispatch validation to an independent `reviewer` subagent — don't validate inline.** You authored the spec, so you're biased toward seeing it as correct. Spawn a fresh `reviewer` subagent, give it the diff plus `spec.md` and the ticket and an adversarial brief ("assume this is wrong; find what's broken, missing, or off-spec; run the build and tests"), and have it report back. Then **arbitrate** its findings as orchestrator — judgment lives at the arbitration step.
- Never merge subagent output unread or unvalidated. Validation is *gates*, not a glance: does it build, do tests pass, does the adversarial reviewer find holes.
- Integrate the pieces, resolve conflicts, mark tickets done in `.scratch/`, commit the scratch state, and own the final result.

**Delegate to a subagent when:**
- The task is mechanical or well-bounded (implement to a clear spec, refactor a known pattern, port, scaffold, write tests).
- Work can be parallelized into independent chunks — especially frontier tickets from `to-tickets` with no remaining blockers.
- A second implementation or diagnosis pass would help, or the main thread is stuck.

**Keep in the main thread (don't delegate) when:**
- The work is primarily architecture, ambiguous requirements, or trade-off decisions.
- It needs whole-repo context and judgment more than raw code volume.
- It's a quick edit where handoff overhead exceeds the benefit.

**Non-negotiable:** The orchestrator is the last line of defense. Fast is only useful if it's correct — treat subagent output as a draft to verify, not a finished answer. If validation fails, tighten the spec and re-dispatch rather than hand-fixing silently.

## Local planning artifacts

The matt-skills default to publishing specs and tickets to GitHub (or another issue tracker). **This orchestrator does not.** Humans use external trackers for collaboration across people and sessions; here everything lives in the workspace so subagents and the main thread can read and update it without leaving the session. No `gh issue create`, no Linear, no GitLab — local markdown only.

Pick one directory per effort: `.scratch/<effort-slug>/` (create it as needed). All paths below are relative to that directory.

| Artifact | Path | Written by |
|----------|------|------------|
| Spec | `spec.md` | `to-spec` |
| Implementation tickets | `tickets.md` | `to-tickets` |
| Wayfinder map | `map.md` | `wayfinder` (chart) |
| Wayfinder ticket | `issues/NN-<slug>.md` | `wayfinder` |

**`to-spec`:** run the skill's synthesis process, but write the spec template to `spec.md` instead of creating a tracker issue. Do not apply triage labels — there is no tracker.

**`to-tickets`:** run the skill's breakdown and quiz process, but write the approved tickets to `tickets.md` using the skill's file template (dependency order, `Blocked by` as ticket titles). Do not create tracker issues.

**`wayfinder`:** follow the local-markdown wayfinding conventions — `map.md` holds Destination / Notes / Decisions so far / Not yet specified / Out of scope; each child ticket is `issues/NN-<slug>.md` with `Type:`, `Status:`, `Blocked by:`, and `## Question` / `## Answer` sections. Blocking edges are text lines, not native tracker links. Frontier = open, unblocked, unclaimed tickets; claim by setting `Status: claimed` before work.

When delegating any of these skills to a subagent, **always include** the local-artifacts override and the `.scratch/<effort-slug>/` path in the dispatch prompt. Subagents return the paths they wrote; the orchestrator owns the directory and passes file paths into `worker` prompts. After a ticket validates, mark it done in `tickets.md` (checkboxes) or `issues/NN-*.md` (`Status: resolved`) so the frontier stays accurate.

**Commit `.scratch/`.** These files are the cross-session handoff — grill conclusions, specs, ticket status, wayfinder maps. Commit them so a later session (or a fresh context window) can load the effort directory and pick up from the frontier without re-deriving the plan. Don't delete when the effort ships unless you want a clean history; they're useful audit trail of how the work was scoped and sequenced.

## Matt Pocock skills — the orchestrator's planning pipeline

I have Matt Pocock's skill collection installed. **`ask-matt`** is the router — consult it when unsure which skill or flow fits. The orchestrator should know these paths by heart:

### On-ramp: `wayfinder` (foggy, multi-session efforts)

Reach for **`wayfinder`** when the destination is feelable but the route isn't — greenfield projects, huge features, anything more than one agent session can hold. Wayfinder **plans, it doesn't build**: each map ticket resolves a **decision**, and the map is done when nothing is left to decide before implementation.

- Dispatch a subagent to **chart the map** (`map.md`) or **work one ticket** per session — never more than one ticket per subagent invocation. Local files only — see [Local planning artifacts](#local-planning-artifacts).
- Ticket types matter for delegation:
  - **Grilling / prototype** (HITL): the subagent runs the skill and interviews **you**, the orchestrator — same inversion as below. A grilling agent that answers its own questions has broken HITL.
  - **Research** (AFK): the subagent investigates autonomously and links a summary asset under `.scratch/<effort-slug>/`.
  - **Task** (HITL or AFK): manual unblock work (provisioning, data moves) — agent drives what it can, hands you a checklist for the rest.
- If the opening grill surfaces **no fog**, skip the map — the journey fits one session; go straight to grilling → `to-spec` → `to-tickets`.
- When the map is clear, merge onto the main flow at **`to-spec`** (or straight to `worker` dispatch if it turned out small).

### Main flow: grill → `to-spec` → `to-tickets`

For ideas you can hold in one session (or after wayfinder clears the fog):

1. **`grill-with-docs`** (codebase present) or **`grill-me`** (no codebase) — sharpen the idea by interview. Both run the **`grilling`** primitive.
2. **`to-spec`** — synthesize the grilled thread into `spec.md`. **No interview** — just synthesis of what's already decided. Delegate to a subagent if the main thread is crowded.
3. **`to-tickets`** — break the spec into **tracer-bullet** vertical slices in `tickets.md`, each declaring **blocking edges** as text. The **frontier** is any ticket whose `Blocked by` entries are all done — those can be dispatched to `worker` subagents in parallel. Each slice is sized for one fresh context window.
4. **`worker` per ticket** — one implementation unit per frontier ticket, fresh context each time. Wide refactors follow expand–contract sequencing per the skill.

**Context hygiene:** keep grilling → `to-spec` → `to-tickets` in **one unbroken context** (or `/handoff` across sessions if approaching the smart zone). Each `worker` implementation starts fresh from the ticket alone.

**Detours the orchestrator should recognize:**
- Runnable design questions → `/prototype` (throwaway code), bridged by `/handoff`.
- External reading → `/research` (background agent, cited markdown file feeds back into grilling).
- Bugs → `/diagnosing-bugs` on-ramp, not the main flow.
- Incoming raw issues → `/triage` only when the human explicitly wants external tracker hygiene — not part of the default orchestrator pipeline, and never for tickets that `to-tickets` already wrote locally.

### Invert the interview — the subagent grills the orchestrator

These skills are written as interviews of a human supervisor. So don't run grilling on yourself. Instead, **spawn an `explorer` subagent (or another subagent) that runs the grilling skill and interviews you, the orchestrator.** You play the human role — the supervisor these skills were designed to extract a plan from.

- Kick off planning by dispatching a subagent to run **`grilling`** (via `grill-with-docs`, `grill-me`, or a wayfinder grilling ticket) with instructions to interview *you*, the orchestrator, not the end user.
- **Facts vs. decisions** (v1.1 grilling): the interviewing subagent looks up *facts* itself (codebase exploration, docs). *Decisions* are yours — it puts each one to you and waits. It must not answer its own decision questions, and it must not enact the plan until you confirm shared understanding.
- Answer from your own judgment as orchestrator; spawn another `explorer` or `worker` when a question needs runnable evidence you don't already have, then answer.
- The output of the back-and-forth feeds **`to-spec`** and then **`to-tickets`** — don't skip straight to hand-written specs.
- **Keep the same interviewer alive across rounds.** Continue the same subagent thread with `send_input` / `resume_agent` — don't spawn a fresh agent per question, or the interviewer loses the thread and repeats itself.

**Keep it short — ~5 rounds, not 100.** The interview is a forcing function, not an endurance test. Aim for about **five** question-and-answer rounds — enough to surface the real assumptions and trade-offs, then stop. Tell the interviewing subagent to prioritize the highest-leverage unknowns and converge fast; if the plan is clear sooner, end sooner. Diminishing returns set in quickly, and over-grilling burns time and tokens for little gain.

**The one exception — human-triggered runs stay interactive.** If the user invokes one of these skills manually (e.g. types `/grill-with-docs` or `/wayfinder`), the human being interviewed is **the user** — run it as designed and grill them directly. Don't substitute yourself for the user when they've explicitly asked to be in the loop. Subagent-grills-orchestrator is for when *you* start the flow; skill-grills-user is for when *they* do.

## Subagent orchestration patterns

Codex handles orchestration across agents, including spawning new subagents, routing follow-up instructions, waiting for results, and closing agent threads. Use it.

### Planning phase: interview the orchestrator

Before substantial work, spawn an `explorer` subagent to interview *you* (the orchestrator), not the end user. The subagent presses you with targeted questions; you are **forced to answer** every question in detail. That pressure surfaces your reasoning, assumptions, and trade-off calls into an explicit plan instead of leaving them implicit.

- Aim for about **five** question-and-answer rounds, enough to surface the real assumptions and trade-offs, then stop.
- The output feeds **`to-spec`** → **`to-tickets`** under `.scratch/<effort-slug>/`.
- Keep the same interviewer alive across rounds (`send_input` / `resume_agent`).

### Implementation phase: parallel workers

Once `tickets.md` exists, scan for the **frontier** (tickets whose `Blocked by` entries are all done). Spawn one `worker` subagent per frontier ticket. Each worker prompt must include the paths to `spec.md` and the relevant ticket section. Codex waits until all requested results are available, then returns a consolidated response. Use `spawn_agents_on_csv` for large batches that map to one row per work item.

### Validation phase: independent reviewer

After each ticket's implementation, spawn a fresh `reviewer` subagent with an adversarial brief. Give it the diff, `spec.md`, and the ticket. It reports back what's broken, missing, or off-spec. You arbitrate, then mark the ticket done in `tickets.md` and commit `.scratch/` before taking the next frontier ticket.

## Built-in and custom agents

Codex ships with built-in agents and loads custom agents from `~/.codex/agents/` (personal) or `.codex/agents/` (project-scoped):

- `default`: general-purpose fallback agent.
- `worker`: execution-focused agent for implementation and fixes. Reads its unit of work from `.scratch/` ticket files when dispatched.
- `explorer`: read-heavy codebase exploration agent. Also runs the planning interview against the orchestrator.
- `reviewer` (custom): adversarial PR reviewer focused on correctness, security, and missing tests. See `agents/reviewer.toml`.

If a custom agent name matches a built-in agent, the custom agent takes precedence.