# The nightly memory engine

*How Navi turns a day of raw transcripts into an understanding of a life, every night, without anyone watching.*

Status labels used here: **[live]** running every night; **[built]** written and tested, not yet switched on;
**[planned]**. Numbers are from the private build records as of early November 2026.

## What it is for

Every night Navi should read everything she has (what the pendant heard, what the owner typed to her, later email
and calendar) and update a rolling understanding of his life:

- a very short account of each day, and a detailed one behind it;
- pages for the people and situations that matter;
- the commitments that are open;
- a small core of confirmed facts;
- a one-to-two-kilobyte "current world" page that is put in front of every conversation.

In the morning, when asked, she tells him what matters in three to five minutes and asks at most three questions.

## The shape: an external program that asks the agent to think

The engine is **not** an OpenClaw plugin. It is a separate Node program started at 04:00 by an OpenClaw cron job,
supervised, with a watchdog. That keeps it testable on its own (the suite has over 5,000 tests) and keeps the
agent's process small.

```
 EVIDENCE                 NIGHTLY ENGINE                                   MEMORY (plain files)
 transcript journal  -->  M1 intake by local day, open to late evidence    days/<date>.md          short
 chat (owner's own   -->  M2 stitch chunks into conversations              days/<date>.detail.md   full
   words only)            M3 label: life / media / dictation / call /      situations/<slug>.md
 documents                   garbled; owner or not                         people/<slug>.md
 (email, calendar:        M4 select: enumerate all, read the dense whole,  current-world.md        1-2 KB
  later)                     record why the rest was not read              briefing/<date>.md
                          M5 extract items that point at their evidence    fact store (events)     authority
                          ------------------------------------------------ to-do store             authority
                          N1 NAVI interprets the day          (agent turns)
                          N2 NAVI updates situations and proposes memory
                          N3 NAVI writes the briefing
                          N4 NAVI reasons about her own questions
                          N5 NAVI lists moments an offer could have helped ("shadow mode")
                          ------------------------------------------------
                          P1 gates, atomic versioned publish, receipt, alert
```

**The cognition contract.** Stages M1 to M5 are mechanical: cleanup, stitching, labelling, selection, extraction.
They may use a raw model or a small classifier. Stages N1 onward carry *meaning*, and they are done **by Navi
herself**: real OpenClaw agent turns of her own agent, through a standing automation job with a pinned model,
read-only memory tools, no fallbacks and no delivery. The engine supplies evidence and checks her output; it never
decides what a day means. If she can't be reached, the engine publishes a degraded day that says "Navi did not
interpret this day", and never signs her name to a raw model's text.

Why: the owner talks to Navi all day. If the night's understanding came from a different, anonymous model, her
morning voice and her daytime voice would disagree. And a weaker model can follow the plumbing; only the agent who
knows him can judge what mattered.

## Stores and who may write them

| Store | Holds | Authority | Writer |
|---|---|---|---|
| Fact store (event-sourced) | confirmed facts, proposals, corrections, tombstones | authoritative for facts | one plugin tool, nothing else |
| To-do store | commitments, reminders | authoritative for obligations | its own plugin's tools |
| Memory directory | days, situations, people pages, current world, briefings | derived, regenerable | the engine only |
| Transcript journal | raw transcripts | evidence | the capture worker only |

A proposal never outranks a confirmed fact. A correction or "forget that" propagates to every rendered page and
the next briefing on the next run.

**Remembering without asking.** A fact is stored without a question only when the owner said it directly to Navi,
or it is clear on two distinct days, uncontradicted, in speech attributed to him. Media, other speakers, unknown
speakers, pasted text and the same event heard twice never qualify. A plan is not an event; an expected payment is
not money received. Everything else becomes a question, at most three a morning, never a mandatory sitting.

## Contracts that turned out to matter

**Time.** Every item keeps event time, ingest time and source. The local day is computed in one fixed time zone.

**Selection is accounted for.** Every conversation is listed with its label, its evidence that the owner was
speaking, a density score, and either "read whole" or the reason it wasn't. The day's receipt says how much speech
was read, skipped as media, and skipped for budget. "Complete" is never claimed when significant speech was not
examined.

**Honest receipts.** A report distinguishes *no capture*, *media only*, *partial*, *late* and *complete*. A missing
day is never an empty day.

**Days are written once [live].** The first design kept each day "provisional" and rebuilt it the next night when
late evidence might arrive. In practice the rebuild was sometimes *worse* than the morning's version, and on two days
it replaced a real briefing with a ~340-byte placeholder, silently (details in [lessons](lessons-learned.md)). Now:

- a day's first published version is canonical;
- recordings that arrive later become `days/<date>.addendum.md`, which recall shows, and the briefing mentions;
- change over time belongs in the world pages (current world, situations), not in rewritten days;
- the evidence baseline of the first publication is immutable, so "what's late" is always computable;
- a degraded night alerts the owner in the morning.

That change also cut roughly 22 of the night's ~51 minutes.

## Prompt budgets and the transport

Navi's turns are big: the current world, people, situations, the last seven days, and the day's evidence. Two
lessons:

- **The command line was the bottleneck, not the model.** Prompts were first passed as one argument to an OpenClaw
  CLI command; Linux caps one argument at 128 KiB, so every turn was squeezed to 130,000 bytes and quietly dropped
  context. The engine now sends the same patch through OpenClaw's public gateway SDK [live], and budgets were
  derived from the model's actual window (131,072 tokens at ~3.6 bytes per token measured): about 300 KB for the main
  turns, with a hard cap. This also removed a Linux-only dependency.
- **Transcript first [live].** Navi now reads the clean, speaker-labelled transcript of the day *first*, and the
  extracted items second, instead of only the items. Media and garbled speech are left out and counted.

## Morning questions and shadow mode

- **Questions [live].** The engine proposes candidates; Navi reasons about which (if any) are worth asking, at most
  three. Answers go through one plugin tool and are durable at once.
- **Shadow mode [live, being tuned].** After the day is understood, Navi lists every moment where an offer
  ("want me to remind you?", "that conflicts with Thursday") *could* have helped. Nothing is sent; the owner reviews
  the list. The first reviews were humbling: in one night, 32 of 34 suggestions were judged not useful, mostly
  because the topic was already being handled in chat, or was premature. Round two cross-checks existing context
  before offering. The list has no cap on purpose: the owner wants to be able to reject 25 of 27.

## Cards: "Navi knows when to look" [live]

An incident: asked to draft a careful message to a relative, Navi drafted it without loading the rule the owner had
set for that person, because dictation spelled the name one letter off and she didn't search first. Instructions
alone ("always check memory first") didn't fix the habit. What did:

- every night the engine builds a lookup map of people, pets, organisations, projects and open matters, with their
  names, other spellings and relation words;
- before each turn, a plugin matches the message against the map (full names, "my aunt", sound-alikes via Double
  Metaphone plus edit distance) and puts at most three short cards in front of it;
- a card says what is on file, and says plainly when *nothing* is ("no rules stored; ask rather than assume").

## Supervision

- The engine runs under a supervisor with per-stage time bounds; every stage is checkpointed and reports what it
  skipped. A killed run is caught up the next morning.
- A watchdog job checks the outcome; `DEGRADED` is its own exit code and its own alert.
- A morning self-check compares what the docs say is live (engine version, plugin versions, agent config keys)
  with the machine, and reports drift to the lead engineer.

## What we'd keep for a rebuild

- The external-engine-plus-agent-turns split, and the rule that only the agent writes meaning.
- Append-only days with addenda; immutable evidence baselines.
- Receipts that account for what was *not* read.
- Exit codes where "degraded" can never look like "healthy".
- Budgets derived from the real model window, measured, not guessed.
