# Roadmap

*Order of work as of early November 2026. One active lane at a time; everything else waits in a queue.*

## Now

1. **Memory redesign.** Fewer stores with clearer authority, shaped around what Navi actually looks up.
2. **Local fallback LLM** ([plan](docs/local-fallback-llm-strix-halo.md)): crash auto-reboot and hygiene first, then
   an attended first load, then wiring both agents' failover (one gateway restart), then the nightly engine's own
   fallback route.

## Next

- **Shadow mode v2, live timing:** a small local classifier flags moments as they happen; Navi's model wakes only
  on flags. Goal: about 30 seconds for clear cases. Still nothing is sent.
- **Per-chunk speaker scoring** in real time, used wherever a channel needs it.
- **Reminders and to-dos you can check off in the app.**
- **Journal retention and segmenting.**

## Later

- **Move to a new machine (macOS).** The first real portability test: OpenClaw, memory, plugins, voice, backups and
  every supporting service. Likely done together with the rebuild.
- **The clean rebuild, open source.** A ground-up rebuild on synthetic data, using this system and its documents as
  the reference implementation and test oracle.
- Email and calendar as evidence.
- Enrolling other voices (family, AI voices) in the app.
- An AI-security watchdog.

## How the roadmap is run

Goals, success criteria and limits are agreed up front, with the questions that would otherwise block work asked
ahead of time. Then the engineers and the operator run on their own; the owner checks in hours later. Tasks only a
human can do (Bluetooth pairing, voice enrolment, real-use tests) are batched for him.
