# Multi-Agent Patterns

The six canonical patterns from Anthropic's "Building Effective Agents". The architect picks one (or composes two) for each generated team.

## 1. Prompt chaining

```
Input → Agent A → Agent B → Agent C → Output
```

**Use when:** the work decomposes into a fixed, predictable sequence and accuracy matters more than speed.

**Example for the generated team:** spec-writer → implementer → reviewer. Each produces input for the next. Failures are caught early in the chain.

**Don't use when:** the steps depend on intermediate findings that can't be predicted up-front.

## 2. Routing

```
Input → Router → ┌─ Specialist A
                 ├─ Specialist B
                 └─ Specialist C
```

**Use when:** inputs cluster into categories that benefit from distinct handling. The router classifies; one specialist responds.

**Example:** a support-triage team where a router sends bug reports to the debugging specialist, feature requests to the product specialist, and account issues to the customer-ops specialist.

**Don't use when:** every input needs every specialist (that's parallelization, not routing).

## 3. Parallelization

Two flavors:

### Sectioning

```
Input → split into independent sections → ┌─ Worker A ┐
                                          ├─ Worker B ├─→ Aggregator → Output
                                          └─ Worker C ┘
```

**Use when:** subtasks are independent and can be executed concurrently. Each worker owns a slice; an aggregator stitches results.

**Example for the generated team:** parallel implementers, each owning a non-overlapping module (`frontend/`, `backend/`, `infra/`).

### Voting

```
Input → ┌─ Worker A ┐
        ├─ Worker A' ├─→ Voter → Output
        └─ Worker A" ┘
```

**Use when:** the same task is run multiple times to increase confidence. Three implementers solve the same problem; the voter picks the best (or merges).

**Example:** three different code-review passes (security, performance, style) on the same diff, results combined.

**Don't use when:** subtasks are not actually independent — you'll get duplicate work and merge conflicts.

## 4. Orchestrator-workers

```
Input → Orchestrator → ┌─ Worker A (dynamic) ┐
                       ├─ Worker B (dynamic) ├─→ Synthesizer → Output
                       └─ Worker C (dynamic) ┘
                              ↑
                              │
                          (orchestrator decides
                           how many workers
                           and what each does)
```

**Use when:** subtasks can't be predicted up-front. The orchestrator decomposes dynamically, spawns the right workers, then synthesizes.

**Example for the generated team:** the default. Lead receives a task, decomposes into N sub-tasks, assigns each to the right teammate, supervises, synthesizes.

**This is the default** the architect picks unless evidence points elsewhere. It's the most flexible and the documented best practice for code-heavy projects.

## 5. Evaluator-optimizer

```
Input → Generator → Output ─→ Evaluator ─→ feedback ─┐
                                  │                   │
                                  ▼                   │
                              ACCEPT? ─── No ─────────┘
                                  │
                                 Yes
                                  ▼
                                Output
```

**Use when:** quality criteria are explicit and the generator demonstrably improves with feedback.

**Example for the generated team:** wrap any of the above patterns in this. Implementer produces code, reviewer evaluates, feedback loops until reviewer says APPROVE (capped at 3 iterations).

**Don't use when:** there's no rubric — open-ended quality grading by another LLM is noisy and expensive without a clear criterion.

## 6. Autonomous agent

```
Input → Agent ⇄ Tools → Output
              (loops freely until done)
```

**Use when:** the step count is genuinely unpredictable, the environment is trusted, and you've validated the agent stays on task.

**Example for the generated team:** rare. Maybe a long-running researcher with WebSearch over a multi-day investigation.

**Don't use when:** you have any structure to impose. Structure beats autonomy for reliability.

---

## How the architect picks

The architect's decision tree:

```
1. Is the project's work bounded and predictable?
   → Yes: prompt chaining or sequential pipeline.
   → No: continue.

2. Do inputs cluster into categories that need distinct specialists?
   → Yes: router + 2–4 specialists.
   → No: continue.

3. Can the work be split into independent slices?
   → Yes: parallel sectioning.
   → No: continue.

4. Is the work decomposable but the decomposition depends on the input?
   → Yes: orchestrator-worker (the default).
   → No: continue.

5. Is quality gradeable by an LLM rubric?
   → Yes: wrap with evaluator-optimizer.
   → No: rely on hooks / verifiers for quality.

6. Is the work genuinely open-ended with no useful structure?
   → Yes: autonomous agent. (Rare.)
```

In practice, most projects get **orchestrator-worker** with **evaluator-optimizer** wrapped around code-touching work. That's the canonical "code team" shape.
