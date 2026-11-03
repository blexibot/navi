# Lessons learned

*What failed, which diagnoses were wrong, and what we would do differently. Collected from the build ledger. Every
item here cost real time; most were settled by one targeted measurement.*

## Silent failures

**A rebuild that made good days worse, and told no one.** The first design re-authored each day one night later
("finalisation"), so late recordings could land. In six days, three rebuilds came out worse than the morning's
version; twice the briefing was replaced by a ~340-byte placeholder. Nobody heard, because:

1. a *degraded* rebuild left the exit code at 0 (only a *failed* one changed it);
2. the supervisor's alerts went to a log file only;
3. the watchdog counted "degraded" as healthy;
4. the health check looked at last night, not at the day that was rebuilt.

An earlier version of the engine had the right rule ("a rebuild never replaces a good published day with a worse
one"). It lived in one pipeline and didn't carry over when the engine was restructured.
**Fix:** days are written once; late recordings become an addendum; degraded nights alert a person.
**Lesson:** put "never replace better with worse" in the publisher, not in one pipeline, and map exit codes so that
"degraded" can never be reported as "healthy".

**The memory flush that had nothing to write with.** Before OpenClaw compacts a long conversation it gives the
agent a chance to write notes. Navi's notes were always empty, because she had no write tool. Fixed with a native
notebook: plain read/write in her own workspace, behind a guard plugin that allows only appends to today's file.

## Wrong diagnoses

- **"The second voice reply is echo."** It was a special token making the streamed text and the final text differ.
- **"A process at 244% CPU is stuck."** That was `ps`'s lifetime average.
- **"The integrated GPU is unusable at 4 GB VRAM."** It addresses 96 GB of GTT.
- **"Kokoro on the GPU is 3 to 5 times faster."** Only on repeated sentences; slower on new ones.
- **"A one-word reply is a model problem."** It was the harness clamping `max_tokens` to the context window minus an
  over-estimated input size. A large reserve fixed it.
- **"`parked` became `Parakeet` because of narrowband audio."** It was our own term fixer.
- **"Disabling the old speech-to-text unit is enough."** A stale `Wants=` brought it back on the next cold boot.
- **"The prompt is too big for the model."** The model's window was fine; the operating system's single-argument
  limit (128 KiB) was the real bound, because prompts were passed on a command line.

## Voice

- **An installed speaker-ID threshold of 0.85 accepted only 19% of the owner.** Measure on the real person, under
  real conditions, before shipping a number.
- **Enrolment counted turns; it must count seconds of speech.**
- **Split audio routing in the car produced echo.** Abandoned.
- **A conference speaker over USB didn't fix the tablet**; the tablet's own audio unit was the limit.
- **Pipecat's defaults split long rambles** into many turns, and a "turn complete" signal reset the silence counter.
  Both needed tuning.
- **Metrics that looked useful and weren't:** a bandwidth field that was always meaningless, a frame log that was
  always empty, a route field that was always "none". Check a metric means something before you build on it.

## The host

- **A kernel panic** on the home server, with no proof of cause; the leading suspect was a second GPU compute job
  started beside the live speech-to-text worker. The response was a temporary "one GPU compute process" rule. It was
  later lifted for a *planned* fallback model, with a memory budget and a staged bring-up instead, because the
  rule was an over-reaction to one unexplained event.
- **The host reached 100 °C** when several coding agents ran benchmarks in parallel. Now: one heavy job at a time,
  watch the temperature, stop at 90 °C.
- **After any crash, cold-boot-test the service graph.** Stale dependencies survive until the next boot.
- **Keep incident evidence separate from incident content.** Kernel logs are engineering evidence; that day's
  recordings are not, and keeping them apart is what let the investigation happen without reading private data.

## Process

- **Never write approval in someone else's name.** Early on, an engineer wrote "GO" files as if the owner had
  approved them. The rule now: quote the owner's own words, about that exact change, or it isn't approved.
- **A report is a claim, not evidence.** Re-check on the machine.
- **Fresh inventories.** An order was stopped because its list of live scheduled jobs came from an old inventory
  and missed two of the five.
- **Tests on synthetic data are for regressions; acceptance uses the real system.** The biggest misses (silent
  degradation, empty notes, offers nobody wanted) only showed up on real days.

## Product

- **Instructions don't change habits; context does.** "Always check memory before drafting a message to someone" did
  not stop Navi from drafting first. Putting a short card about the person *in front of the message*, by code, did.
- **Name drift is normal.** Speech-to-text and dictation spell known names differently. Match by sound and edit
  distance, not by exact alias.
- **Shadow mode before live mode.** Navi's first list of "moments I could have offered help" was 32 of 34 not
  useful. Shipping those as notifications would have been spam. Reviewing them silently first cost nothing.
- **Value over polish.** Before a change, ask whether the owner would notice it in daily use. Batch the small stuff.
- **Trust the agent's reasoning over keyword tripwires.** Deterministic exact-phrase rules kept misfiring; letting
  the agent read intent, with code only for format and safety, worked better.

## For the rebuild

- Append-only days; immutable evidence baselines.
- Every degraded outcome reaches a person.
- Name things for what they do. Delete rollback targets after a week of clean use, and record it.
- Build the measurement first.
- Inventory every GPU-capable service on the host and pin each one explicitly.
- Documentation is a product: the ledger, the system map and the rules file are what make a clean rebuild possible.
