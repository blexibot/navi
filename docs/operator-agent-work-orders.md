# The operator agent and the work-order mailbox

*How AI engineers change a live system they are not allowed to touch.*

## The setup

Navi is built by several Claude Code sessions (a lead engineer and specialists), but **no coding session changes the
live system directly**. Live changes (services, gateway config, plugins, models) are made by **the operator**, a separate OpenClaw
agent on its own machine. The owner set it up this way early on, when a coding
session's own permission layer (rightly) refused to stop a dead service on the shared host.

Why it works:

- **Separation of duties.** The agent that writes the change is not the one that applies it, and the one that
  applies it checks the order against the real machine first.
- **Every change has a paper trail:** an order, a receipt, a report and a production changelog entry.
- **The owner isn't the courier.** He doesn't carry messages between agents, and he isn't asked to approve every
  routine deploy.

What we publish about it is the *pattern*. How the operator reaches the server and how her elevated access is held
are deliberately not described here.

## How it evolved (the short version)

1. **Numbered orders, carried by hand** (about 24 of them in the first week): the engineer wrote a numbered `TO-OPERATOR-N.md`,
   the owner pasted it to the operator, the operator replied with a report. It worked, but the owner was the courier.
2. **"GO" files written in the owner's name.** A mistake: an engineer wrote approval files as if the owner had
   approved them. The lasting rule that came out of it: **never write that the owner approved something unless he
   said so, about that exact change, in his own words**, and quote him.
3. **"Forwarding is the authorization."** An order the owner forwards himself is approved by that act.
4. **The mailbox (since late October 2026).** The owner gave standing authority, in writing, for the lead engineer to
   send orders straight to the operator, and for her to carry them out without asking each time, deploys and
   restarts included, *except* for a short list of hard stops.

## The mailbox

It works like the ticket rail in a restaurant kitchen. The lead engineer puts a ticket on the rail; the operator
checks it every few minutes, takes one ticket, does the work, and puts back a receipt and a report.

It is a folder plus one small dependency-free Node program that guarantees:

- a ticket can't be seen until it is completely written (it becomes visible only when a `.ready` file is written
  last);
- only one worker can take a ticket, and only **one ticket runs at a time**;
- every claim gets a fresh random token (fencing); a stalled worker whose lease lapsed can't finish a ticket someone
  else recovered;
- an expired or cancelled ticket never starts; a ticket that depends on another waits until that one has
  **passed**;
- a ticket id is used once, ever;
- the first receipt wins and is never overwritten (created with `link(2)`), and the report on disk is always the one
  the receipt's hash names;
- a crashed run is noticed, and the next run **inspects the real system before redoing anything**;
- nothing can point outside the mailbox, and nothing in it is readable by other users.

## What an order must contain

| Field | Why |
|---|---|
| `tier` | read-only or development; "needs the owner" is refused, the engineer asks him instead |
| `live` | does it change the live system? |
| `targets` | what it touches, with expected hashes where possible |
| `after` | tickets that must have passed first |
| `steps` | exact, in order |
| `acceptance` | the checks that decide "passed" |
| `rollback` | the prior state and the command to return to it. A live order with no real rollback is refused |
| `recovery_check` | how to inspect the target before redoing anything after a crash |
| `window_ok` | it respects the protected nightly window. A live order that doesn't is refused |
| `policy_version` | which version of the standing policy it relies on |

Unknown fields are refused, so a typo can't silently drop a control.

## Hard stops (the operator pauses and asks the owner)

In outline: content the owner has put off-limits to cloud models; changing the policy or its guardrails;
**anything public**; high-impact infrastructure (bootloader, kernel, firmware, disks, host access controls,
firewall, unrequested reboots) unless the order cites his prior authorization; irreversible deletion of private
data; credentials or private data going somewhere new; new spending; his personal devices; major product-policy
changes; and the operator's own gateway.

The engineer can *propose* changes to this list. It can't authorize them itself.

## Standing practice

- **No live changes during the nightly run** (a protected window around 04:00).
- **Checkpoints, not ceremony.** Keep a recent checkpoint before anything hard to undo. If a deploy's checks fail,
  roll back and report. Rolling back further, or after real use has moved on, is a conversation with the owner.
- **Verify, don't trust.** A fixer's report, a builder's "done" or a peer's summary is a claim, not evidence. The
  lead engineer re-checks the result on the machine, read-only.
- **An engine candidate is a clean child of the current live version,** with only the intended files, and comes with
  a whole-tree diff summary and directory hashes.
- **The operator keeps her judgement.** A malformed, stale, contradictory or unsafe order is stopped and returned
  with the reason. Several orders were stopped this way (a runbook gap, a contradiction between two steps, a missing service in an
  inventory); each came back as a corrected revision.
- **A change is finished only when** the operator has written its changelog entry and her report.
- **Test setups are not live changes.** Coding sessions may run throwaway OpenClaw profiles with synthetic data on the
  same host (own profile, own port, never the real agent's memory or gateway) without an order.

## What we'd keep for a rebuild

- Separate the writer of a change from the applier.
- Make rollback and a recovery check mandatory fields, not good intentions.
- One ticket at a time, idempotent receipts, fencing tokens.
- Quote the owner's own words for every authorization; never paraphrase approval into existence.
