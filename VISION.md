# Vision

*What Navi is being built to become. [STATUS.md](STATUS.md) says what runs today; [ROADMAP.md](ROADMAP.md) gives the order of work.*

## The one-line version

A secretary who knows you really well: she hears your day, understands it, keeps track of everything that matters,
and over time handles more of it for you, within boundaries you set.

## Where she's headed

**1. From proposing to acting.** Today Navi notices things and offers them; the owner decides. Her abilities are
meant to grow in steps, each one earned on real use before the next:

| Step | What she does | Example |
|---|---|---|
| Today | Remembers, briefs, reminds, proposes | "You said you'd sand the light fixture today." |
| Next | Offers in the moment, when an offer would really help | A nudge during the day, not just the next morning |
| Then | Acts on small things after a one-tap confirmation | Drafts the message and sends it once he says yes |
| Later | Acts on her own inside standing permissions he sets | Keeps routine commitments moving without asking |
| Always his | Destructive actions, new spending, changes to her own permissions | These stay with the owner for good |

**2. The primary agent.** The owner already works with several AI agents (coding sessions, an operator agent, an
older local agent). Navi is meant to be the one who knows him best. She routes work to the others, keeps them on
task, and hands context between them, so he doesn't have to.

**3. All of his context, kept securely.** Email, calendar, finances, health and private notes are part of the target
design. The more she knows, the more useful she is. Security comes from keeping that data local and handling it
carefully, not from leaving it out.

**4. Fully local.** Speech and memory are already local. The main model runs on hardware at home. A smaller model on
the home server is being prepared as a fallback. The aim is to need no cloud model for anything personal.

**5. Survives a change of home.** Memory is plain Markdown plus one small event store. Plugins use only public
OpenClaw interfaces. When one agent is down, another can stand in: Blexi, an older fully local agent, has already
taken over Navi's work once. The planned move to a new machine is the first real test of all of this.

## The rebuild

This repository documents a working system that grew by trial and error. Once it's clear which parts earn their
place, Navi will be rebuilt from the ground up as an open-source project:

- built on **synthetic data only**, so nothing personal is ever part of it;
- with this system and its records (decisions, failures, measurements) as the **reference implementation and test
  oracle**;
- by a purpose-built AI coding session, with the owner setting goals and limits as he does now.

The documentation here is written for that rebuild. That's why it records what failed and what's now vestigial,
not just what worked.
