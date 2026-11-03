# A fallback LLM on Strix Halo, beside live speech-to-text

*Plan and first package, November 2026. Status: **planned; the first package is built and tested offline, nothing
is live yet.** The figures below are from the plan and from vendor and community documentation; the staged bring-up
exists to measure them on our machine.*

## The problem

Navi's main model runs on a small GPU cluster on the home network. When the cluster is down (a move, a power
problem, maintenance), Navi is down: both agents had an empty fallback list, and the nightly engine would publish a
code-only "Navi did not interpret this day".

Requirements, in the owner's and the operator's words: a dependable fallback for basic conversation, memory and
context handling, and tool routing; **reliability over maximum intelligence**; on the GPU, not the CPU; no external
eGPU; and "we don't want to push the Strix Halo to the absolute limitations of its RAM."

The complication: the home server's integrated GPU already runs the live speech-to-text worker for the pendant, and
an earlier kernel panic had been blamed (by inference, never proven) on a second GPU compute job started beside it.

## The choice

**Model: Qwen3.8-27B, Unsloth UD-Q4_K_M** (~15.3 GiB of weights, Apache-2.0), kept loaded all day.

| Candidate | Resident memory | Speed on Strix Halo, Vulkan | Tool calling | Verdict |
|---|---|---|---|---|
| **Qwen3.8-27B Q4_K_M** | ~28 GiB with two 131k slots | ~10-13 tok/s decode; ~270-365 tok/s prefill | Best evidence we found; also OpenClaw's own first recommendation for llama.cpp | **Primary** |
| Qwen3.8 Flash-Next (125B MoE) | 82-94 GiB resident (~60 GiB with lazy loading) | 25-28 tok/s short, 9-13 at 128k | Reports of reasoning loops in agent use; lazy path unstable under memory pressure | Dropped as the fallback: the opposite of headroom |
| Qwen3.6-35B-A3B | ~24 GiB | ~60-70 tok/s | No agent-harness evidence found | Speed contingency only |
| A 12B model on Ollama | ~8 GiB | fast | History of malformed tool calls in long agent use | Not the fallback |

**Runtime: upstream `llama-server`, Vulkan (RADV), built from source and hash-pinned.** Not HIP/ROCm, so it is not
a second ROCm compute client beside the speech-to-text worker (the suspect path from the panic, and the trigger for a
known "GPU pinned at 100% while idle" bug with two HIP clients on gfx1151). Not a model swapper (one always-warm model
doesn't need one). Not a gateway child process (it would die on every routine gateway restart).

**Key flags:** `-ngl 999 -c 262144 -np 2` (two 131k slots so each agent keeps its own cached prompt), `-fa on`,
**`-ctk q8_0 -ctv q8_0`**, `--ctx-checkpoints 8` (matters for this hybrid architecture: without checkpoints a
continued chat re-reads the whole prompt), `--jinja` with a fixed chat template that repairs JSON-string tool
arguments, thinking off, no speculative decoding (reliability first), localhost only.

**Why q8_0 KV is mandatory, for now:** on our kernel and Vulkan driver, flash attention with f16 KV at depth hits a
slow path that trips the amdgpu job timeout (device lost). It is fixed upstream, but not in the build we pinned.
We requalify on a newer build after it has aged two weeks.

## The memory budget (one physical pool; "GTT" is the GPU's share)

| Row | Planned cap (GiB) |
|---|---|
| OS, kernel, desktop | 6 |
| Gateway, proxies, capture services, push server, coding-agent sessions | 10 |
| Live speech-to-text (RAM side + GPU side) | 10 |
| Text-to-speech (CPU) | 5 |
| Open-mic speech-to-text + speaker scorer (CPU) | 5 |
| Embeddings (CPU) | 1.5 |
| Future classifier | 4 |
| **Fallback LLM** (weights 15.3 + KV ~8.5 + compute ~2 + host ~1.5) | **28 planned, 32 hard** |
| Night work and page cache | 18 |
| **Planned total** (rows rounded) | **~88-90 of ~121.5 usable** |
| **Never planned (headroom)** | **≥ 30 (~25%)** |

The BIOS stays at the standard Strix Halo pattern: a small fixed carve-out and a large GTT (96 GiB) via
`ttm.pages_limit`. The plan uses less than half of that ceiling.

## Failover in OpenClaw (no core changes)

- One custom provider for the local server, `api: openai-completions`, `contextWindow 131072`, and the llama.cpp
  tool-schema profile, which strips schema constraints that can make llama.cpp's grammar compiler crash.
- Each agent's `model.fallbacks` gets the local model; so do the defaults, so cron jobs fall back too.
- **Caveat:** a session with a user model override never falls back. Check for pinned sessions before relying on it.
- **Cost of an outage turn:** OpenClaw treats a 5xx as transient and retries for about 90 seconds before advancing,
  then the 27B has to prefill a ~35k-token prompt (about two minutes cold, seconds when its slot is warm). If that
  proves too slow, the cheap fix is in our own small proxy in front of the main model: after a minute of the upstream
  being unreachable, answer **404 `model_not_found`**, which OpenClaw advances on at once.
- Fallback is per turn, so recovery is automatic: the next turn tries the main model first.
- **The nightly engine** has its own client and needs a code change (a fallback endpoint used only when the
  primary's preflight fails, recorded in the night's receipt). That comes last.

## Safety: what was kept and what was cut

The October plan for a 94 GiB model carried a lot of insurance. For a 28 GiB model:

**Kept:**
- Reboot automatically 10 s after a kernel panic (today a panic would hang the box until someone holds the power
  button). The trade-off was written down: an oops that today kills one process would reboot the whole machine
  (~3 minutes; all services come back by themselves).
- Journal sync every 15 s, so a crash leaves logs.
- Hold the GPU driver and firmware packages against surprise upgrades (reversible).
- A small stop guard around the LLM: memory, GTT, heat and kernel-log checks; **stop at ≥ 90 °C for 60 s**; it
  writes a latch and files a ticket.
- A staged, attended first load with small context first.
- The unit does not start at boot during bring-up; later, systemd's start limits break any crash loop.

**Cut or replaced:**
- A memory-test day and an 18-hour soak (an always-warm model, health-checked every 10 minutes, is its own soak).
- A 360-call tool exam, cut to **30 synthetic cases once, plus 10 in a weekly drill**.
- Drills on the live gateway, replaced by a throwaway OpenClaw profile with synthetic data.
- Reboot-only kernel changes, deferred to one planned maintenance reboot.

## What the first package contains

A user-level systemd unit (not enabled), the stop guard (with 45 fixture-tree tests), a 30-case synthetic tool
suite with a runner and scorer, a long-context "needle" test generator, a 10-minute watch tick (timer not enabled),
root scripts for the journal and package-hold steps with their rollback, and the work order for the operator.

## Prior art that shaped this

AMD's Strix Halo optimisation guide; community Strix Halo toolboxes (Vulkan RADV recommended, flash attention on,
resident loading); community notes on `ttm.pages_limit`; a published Qwen3.8-27B-on-Strix-Halo agent soak; OpenClaw's
own llama.cpp and model-failover docs; the llama.cpp issue on f16 KV and device-lost; ROCm issues on idle-100% with two
HIP clients and on silent hangs that leave no kernel trace.
