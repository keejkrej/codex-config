# Global guidance

## Standing delegation authorization

This file is the user's **standing, durable authorization** to use bounded subagent delegation in this workspace. You do **not** need a fresh, per-turn user message saying "use subagents" or "delegate this" before spawning subagents that this policy mandates. The workflow below is the authorization, not just a description of a nice-to-have.

Concretely, you are authorized and expected to spawn subagents autonomously (within `agents.max_threads` and `agents.max_depth`) whenever this policy calls for it, including the `explorer` interview phase, `worker` implementation units, and the independent `reviewer` validation pass. Treating "the user didn't explicitly ask this turn" as a reason to absorb delegated work into the main thread is a policy violation, not a safe default. If you believe a specific step should not be delegated (security-sensitive, high-blast-radius, or truly cheaper inline), say so and proceed; do not silently fall back to main-thread work.

This standing authorization covers bounded delegation as scoped by this file. It does **not** authorize delegated commits, pushes, deploys, secrets handling, or other high-blast-radius actions unless the user asks for those explicitly at the point of action. When in doubt about scope, delegate the read/analysis/review and keep the destructive action in the main thread with an explicit ask.

## The orchestration pipeline

**The pipeline for substantial work:** a Codex subagent grills the orchestrator (~5 rounds) -> plan/PRD -> the orchestrator decomposes into specs -> dispatch to Codex worker subagents for implementation -> an **independent Codex reviewer subagent** validates -> the orchestrator arbitrates and integrates. The main thread orchestrates throughout; subagents do the interviewing, the building, and the validating.

## Division of labor: the main thread orchestrates, subagents execute

Default operating model for substantial coding work: **the main thread is the orchestrator and validator; Codex subagents do the bulk implementation.**

Codex subagents are fast and strong at focused, well-specified code generation. The orchestrator is stronger at planning, decomposition, cross-file reasoning, and judgment. Play to both.

**The orchestrator's job (keep this in the main thread):**
- Understand the request; explore the codebase enough to scope the work.
- Break the task into concrete, independent, well-specified units of work.
- Write precise specs/prompts for each subagent unit (exact files, expected behavior, constraints, acceptance criteria).
- Dispatch to Codex subagents using the `worker` agent for implementation, the `explorer` agent for read-heavy investigation, and the `reviewer` agent for validation.
- **Dispatch validation to an independent Codex reviewer subagent, don't validate inline.** You authored the spec, so you're biased toward seeing it as correct. A fresh reviewer subagent with an adversarial brief catches what you miss. Spawn a reviewer subagent, give it the diff plus the spec and an adversarial brief ("assume this is wrong; find what's broken, missing, or off-spec; run the build and tests"), and have it report back. Then **arbitrate** its findings as orchestrator, judgment lives at the arbitration step.
- Never merge subagent output unread or unvalidated. Validation is *gates*, not a glance: does it build, do tests pass, does the adversarial reviewer find holes.
- Integrate the pieces, resolve conflicts, and own the final result.

**Delegate to a subagent when:**
- The task is mechanical or well-bounded (implement to a clear spec, refactor a known pattern, port, scaffold, write tests).
- Work can be parallelized into independent chunks.
- A second implementation or diagnosis pass would help, or the main thread is stuck.

**Keep in the main thread (don't delegate) when:**
- The work is primarily architecture, ambiguous requirements, or trade-off decisions.
- It needs whole-repo context and judgment more than raw code volume.
- It's a quick edit where handoff overhead exceeds the benefit.

**Non-negotiable:** The orchestrator is the last line of defense. Fast is only useful if it's correct, treat subagent output as a draft to verify, not a finished answer. If validation fails, tighten the spec and re-dispatch rather than hand-fixing silently.

## Subagent orchestration patterns

Codex handles orchestration across agents, including spawning new subagents, routing follow-up instructions, waiting for results, and closing agent threads. Use it.

### Planning phase: interview the orchestrator

Before substantial work, spawn an `explorer` subagent to interview *you* (the orchestrator), not a human. The subagent presses you with targeted questions; you are **forced to answer** every question in detail. That pressure surfaces your reasoning, assumptions, and trade-off calls into an explicit, well-specified plan instead of leaving them implicit.

- Aim for about **five** question-and-answer rounds, enough to surface the real assumptions and trade-offs, then stop. Diminishing returns set in quickly, and over-grilling burns time and tokens for little gain.
- The output of the back-and-forth is the plan/PRD you then decompose and dispatch to `worker` subagents for implementation.
- Keep the same interviewer alive across rounds (don't spawn a fresh agent per question, or the interviewer loses the thread).

### Implementation phase: parallel workers

Once the plan is decomposed into independent, well-specified units, spawn one `worker` subagent per unit. Codex waits until all requested results are available, then returns a consolidated response. Use `spawn_agents_on_csv` for large batches that map to one row per work item.

### Validation phase: independent reviewer

After implementation, spawn a fresh `reviewer` subagent with an adversarial brief. Give it the diff plus the spec. It reports back what's broken, missing, or off-spec. You arbitrate.

## Built-in and custom agents

Codex ships with built-in agents and loads custom agents from `~/.codex/agents/` (personal) or `.codex/agents/` (project-scoped):

- `default`: general-purpose fallback agent.
- `worker`: execution-focused agent for implementation and fixes.
- `explorer`: read-heavy codebase exploration agent.
- `reviewer` (custom): adversarial PR reviewer focused on correctness, security, and missing tests. See `agents/reviewer.toml`.

If a custom agent name matches a built-in agent, the custom agent takes precedence.
