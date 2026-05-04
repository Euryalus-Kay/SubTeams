# SubTeams vs. Plain Claude Code — Head-to-Head Evaluation Proposal

## Goal

Measure whether running a generated multi-agent team produces a meaningfully better artifact than running the same task with plain Claude Code (single agent), across **functionality, visual design, code quality, usability, completeness, and documentation** — while also tracking **cost** (wall time, tokens) so any quality lift can be judged against the spend.

If SubTeams costs 3× more for a 5% quality bump, that's a different story than 1.2× more for a 30% bump. Both numbers come out of this eval.

## What this eval is NOT

- Not a benchmark of trivial tasks (where coordination overhead obviously dominates).
- Not a research/conversation eval — every task produces a tangible artifact you can run.
- Not a speed contest. SubTeams will likely be slower per task; that's expected.

## Test tasks

Three tasks of increasing scope. Each one surfaces graphics + function + quality + usability **simultaneously** so a single artifact can be scored on all six dimensions.

### T1 — Browser arcade game *(medium, ~30–60 min)*
> Build a playable Breakout-style game as a single `index.html` (vanilla JS/CSS allowed, no build step). Include: paddle, ball physics, brick grid with ≥3 colors, score, lives, win + lose screens, restart button, keyboard **and** touch controls, brief on-screen instructions, and visible polish (smooth animation; sound optional). Must be playable end-to-end in Chrome.

Stresses graphics rendering, game-state correctness, controls/usability, finish polish.

### T2 — SaaS landing page *(visual-heavy, ~30–45 min)*
> Design and build a one-page landing site for a fictional product **"Tinker"** — a no-code automation tool for ops teams. Sections: hero + CTA, 3-feature grid, pricing (3 tiers), 2 testimonials, FAQ (5 questions), footer. Must be fully responsive, keyboard-navigable, and use a **coherent design system** (CSS tokens for color/spacing/type). Static site, any framework or vanilla.

Stresses visual design, copywriting, responsive layout, accessibility.

### T3 — Mini analytics dashboard *(functional-heavy, ~45–75 min)*
> Build a dashboard that loads `sample_sales.csv` (a 5k-row CSV provided in the prompt) and renders: 4 KPI cards, 1 trend chart, 1 breakdown chart, a filterable table, and a CSV-export button. Filters must update **everything** live. Provide a README with run instructions.

Stresses data-layer correctness, chart integration, filter wiring, error/empty states.

## Fairness controls

| Control | Rule |
|---|---|
| Prompt | Identical wording to both systems, locked before any run |
| Model | Opus 4.7 for both — same model, different orchestration |
| Wall-clock cap | 90 min per run (hard kill); time-to-self-declare-done also recorded |
| Starting state | Cold start in empty fresh directory each trial |
| Tool surface | Read, Write, Edit, Bash, WebFetch — no paid integrations |
| Trials per cell | 3 (2 systems × 3 tasks × 3 trials = **18 runs total**) |
| Re-prompting | None. One shot. No mid-run coaching. |
| SubTeams setup | `/build-team` runs **once per task** before any trial — its cost is recorded separately and amortized in the cost analysis. This mirrors real-world use. |

## Evaluation rubric (100 pts total)

| Dimension | Weight | What a "10" looks like |
|---|---|---|
| Functionality | 25 | Works end-to-end, no console errors, edge cases handled |
| Visual design | 20 | Coherent system, clear hierarchy, polish, modern feel |
| Code quality | 15 | Clean structure, no dead code, idiomatic, sensibly testable |
| Usability | 15 | Smooth flow, accessible, empty + error states present |
| Completeness | 15 | All listed features present and finished, not stubbed |
| Documentation | 10 | README runnable as written, design notes if non-obvious |

Each dimension scored 0–10; weighted sum = **total / 100**.

## Methodology

1. **Lock prompts** in `evals/prompts/T1.md`, `T2.md`, `T3.md`.
2. **Run** each (system, task) pair 3× in clean dirs. Output to `evals/runs/<system>/<task>/<trial>/`.
3. **Anonymize**: rename run folders to opaque IDs (`A1`…`R3`) so graders can't tell which system produced which artifact.
4. **Score blind**: 2–3 graders independently rate each artifact on the rubric. Use the median across graders to dampen one harsh/lenient outlier.
5. **Aggregate**: report per-task medians and overall medians for each system on each dimension.
6. **Cost capture**: wallclock minutes, approximate tokens, number of agent invocations (for SubTeams).

## What "winning" looks like

- **Practical win on a dimension**: SubTeams' median is ≥ **1.5 points higher** (out of 10) on that dimension across all 3 tasks. Anything smaller is likely noise at N=3.
- **Cost-adjusted quality**: total score / token spend. SubTeams may win on raw quality but lose here — both numbers go in the report.
- **Loss is also a finding**. If SubTeams underperforms or ties, that's an honest signal about which task shapes don't justify the orchestration overhead.

## Report deliverable

- One scorecard table per task (rows = dimensions, cols = systems, cells = median).
- One aggregate radar chart across all 6 dimensions.
- Qualitative section: "what each system did differently," with screenshots and 2–3 concrete examples per task (e.g., "SubTeams' game had a separate `physics.js`; Claude Code inlined everything").
- Cost-per-quality-point comparison.
- Limitations section (below) printed verbatim.

## Limitations (printed in the final report)

- **N=3 per cell is small.** Results are directional, not conclusive. Borderline differences should trigger more trials before drawing conclusions.
- **Grader subjectivity** is real on visual design and usability. Multiple graders + median mitigates but doesn't eliminate it.
- **Task-selection bias.** These three tasks are visual + integrative, which *should* favor multi-agent specialization. If SubTeams doesn't win here, it likely won't win on simpler tasks either.
- **Plain Claude Code is the same Opus 4.7** with full tool access. This is a fair fight, not a strawman vs. a stripped-down baseline.
- **Team-design cost amortization.** `/build-team` is run once per task and reused across trials. This advantages SubTeams in per-trial cost — and accurately reflects how it's used. The one-time cost is reported separately so readers can re-amortize for their own use.

## Effort estimate

| Phase | Effort |
|---|---|
| Lock prompts + write `sample_sales.csv` | 1 hr |
| 18 runs (~45 min avg, parallelizable) | ~14 hrs machine time |
| Blind grading (18 × 15 min × 2 graders) | ~9 person-hrs |
| Writeup + charts | 2 hrs |
| **Total** | ~**1.5 person-days + machine time** |

## Suggested next steps

If you approve, I'll:
1. Write the three task prompts to `evals/prompts/` and generate `sample_sales.csv`.
2. Build a thin run harness (`evals/run.sh <system> <task> <trial>`) that handles the cold-start dir + timer + token capture.
3. Make the scoring sheet (CSV or simple HTML form for graders).
4. **Smoke-test T1 on both systems first** — one trial each — before committing to the full 18-run battery. If something is broken in the methodology, we want to find out cheaply.

— end of proposal —
