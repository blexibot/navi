# Status

*Last updated: 2026-11-03. Taken from the private build records; refresh before each public update.*

Navi is one person's working system. It is in daily use, it changes most days, and it is not packaged for anyone
else to run.

## Live (in daily use)

| Area | What runs |
|---|---|
| Capture | Pendant audio through the Android app to the home server; local speech-to-text; transcript journal; audio deleted once transcribed |
| Nightly engine | Runs at 04:00, finishes in under an hour; day summaries, detail, people and situation pages, current-world page; write-once days with addenda; degraded-night alerts; catch-up after a killed run |
| Morning | Briefing on request; at most three questions, chosen by Navi |
| Conversation | Recall tools; current-world page and person/situation cards in front of each message; "today's notes" |
| Memory | Plain Markdown pages plus an event-sourced fact store with one writer; a notebook she can append to |
| Reminders | To-do list and reminders that ring on the phone (self-hosted push), re-ring up to three times, Done/Snooze |
| Voice | Hands-free open mic, push-to-talk, read-aloud; all speech models local; voice ID as logs only |
| Shadow mode | A nightly "would have offered" list for the owner to review; nothing is sent |
| Operations | Work-order mailbox to the operator agent; production changelog; nightly backups, plus encrypted off-site copies of the install and memory weekly; morning self-check of live versions |

## In progress

- **Memory redesign** (the active lane): fewer, better-shaped stores.
- **Local fallback LLM** on the home server's GPU: first package built and tested offline; not live.
- **Shadow mode, round two:** cross-check existing context before suggesting anything.
- **"Is this the owner?"** per chunk, in seconds, on the CPU.

## Known gaps

- The transcript journal is never pruned and is rewritten whole on each append.
- One small patch to OpenClaw core is still carried (it predates the no-core-changes rule).
- Email and calendar are not connected.
- Linux-only pieces (systemd units, a few `/proc` and `/sys` reads, GPU drivers) are listed for a planned move to
  macOS, but not yet abstracted.

## Not yet

- Acting on the owner's behalf. Today she proposes and he decides; see [VISION.md](VISION.md) for the steps.
- Offers in the moment (shadow mode is still reviewed silently each night).

## Deliberate non-goals

- Cloud speech or cloud memory.
