---
title: Atri Sangam
excerpt: >
  A GPS/PNT integrity monitor for fixed sites. It cross-checks what a GPS
  receiver reports against independent time references and raises an
  explainable alarm when they stop agreeing — jamming, spoofing, or plain
  outage. Alpha: the monitor runs, but its thresholds have not been proven
  against real jamming hardware.
author: siva-m
type: product
status: in-progress
tags:
  - Python
  - GNSS
  - PNT
  - NMEA
  - NTP
  - Roughtime
  - WWVB
  - CUSUM
  - SQLite
  - Stdlib-only
featured: false
comingSoon: false
publishDate: 2026-07-21
draft: false
---

## What is Atri Sangam?

**Atri Sangam** is a GPS/PNT integrity monitor for a fixed site — a building,
a tower, a substation — whose antenna position has been surveyed once and is
thereafter treated as truth.

A GPS receiver cannot audit itself. Asked what time it is and where it is, it
answers confidently whether or not anyone is lying to it. So Atri Sangam does
not ask one source. It runs several independent channels — satellite, network
time, cryptographically signed time, radio time, the drift of the local clock
itself — and watches for the moment they stop agreeing. The disagreement is
the signal.

## Why the name

Atri (अत्रि) is one of the Saptarishi, born of Brahma's mind; the
Brihadaranyaka Upanishad has him symbolize the tongue — wisdom, and knowledge
of the Vedas. The fifth Mandala of the Rigveda is called the Atri Mandala in
his honour, and it is there, in hymn 5.40, that the sky's most trusted
reference goes dark — the eclipse of Svarbhanu — and is understood rather
than merely feared.

Sangam (சங்கம்) is confluence and assembly: rivers meeting, and the classical
Tamil academies where independent voices reached consensus by collective
judgment. That is the architecture — a sangam of independent channels
deliberating over what the sky and the clocks are really saying.

## The problem it solves

GPS is infrastructure that almost everything else quietly depends on, and it
is easy to attack. Jamming drowns the signal. Spoofing is worse: the receiver
keeps reporting a confident fix, and the fix is a lie. Both are cheap. Neither
announces itself.

The defence is not a better receiver — it is a second opinion that does not
come from the same sky. Atri Sangam's premise is that a site which already
knows where it is can check what it is being told.

## The channels

Each channel is a residual — an observed value minus what it should be — fed
into one engine. Only the GPS channels come from the satellite constellation;
the rest are deliberately independent of it.

| Channel                 | What it measures                                        | What it catches                                                       |
| ----------------------- | ------------------------------------------------------- | --------------------------------------------------------------------- |
| `gps_time_offset`       | GPS-reported UTC minus the local clock                  | Time spoofing, receiver faults                                        |
| `gps_position_error`    | Distance of the reported fix from the surveyed site     | Position spoofing, multipath                                          |
| `gps_cn0_spread`        | Spread of per-satellite signal strength                 | Spoofing tell — a single transmitter collapses the spread toward zero |
| `ntp_time_offset`       | Network time minus the local clock                      | Independent time cross-check                                          |
| `ntp_consensus_spread`  | Widest disagreement among several NTP servers           | A minority of lying time servers                                      |
| `roughtime_time_offset` | Ed25519-signed time minus the local clock               | Time reference an attacker cannot forge without the key               |
| `wwvb_time_offset`      | WWVB 60 kHz radio time minus the local clock            | Terrestrial time, no network needed                                   |
| `holdover_residual`     | Observed offset minus the local clock's own drift model | Slow manipulation that tracks nothing real                            |

NTP consensus counts every server whose claimed uncertainty is within bounds,
takes the median of what those servers themselves reported, and requires that
value to be vouched for by a quorum of them — each server's own interval has
to contain it. No server is picked or dropped on the strength of how precise
it claims to be, so a server cannot win by claiming precision it does not
have, and one widening its own uncertainty to bridge two honest servers that
genuinely disagree cannot get the round vouched for. Disagreement is flagged
either way. Roughtime consensus works the same way, and additionally reports
how many servers failed cryptographic verification.

The honest limit: a lying minority still contributes to the median, so it can
move the result — but only within the range the honest counted servers
themselves reported, never outside it. And the trade runs the other way too.
Because every counted server enters the median, a single lying server can now
push a round below the vouching threshold and **silence** it, where the older
rule would have answered. That fails safe — no reading is published, and the
staleness detector treats the silence as the fault it is — but it means the
guarantee is about correctness, not availability. One server can stop the
channel answering; it cannot make it answer wrongly.

"Within bounds" is a real number a site can set, because a bound that cannot
be changed is a bound that eventually silences somebody. Three flags:

| Flag | Bounds | Default |
| ------------------------------ | ---------------------------------------------- | ------- |
| `--ntp-max-half-width-s`       | half the measured round-trip delay              | 1.0 s   |
| `--roughtime-max-half-width-s` | the signed uncertainty plus half the round trip | 2.0 s   |
| `--roughtime-max-radius-s`     | the signed uncertainty on its own               | 10.0 s  |

A Roughtime server has to clear both of its bounds, and they catch different
things. A server on a satellite or congested cellular path — modest signed
uncertainty, slow link — is admitted by raising the width bound alone. A
server *claiming* an implausibly wide uncertainty is not; that one is held by
the radius bound, and needs both raised. Raising either widens how far a
single server can reach when it tries to bridge two honest ones that
genuinely disagree, which is the whole reason the bounds exist.

## How it decides

Three detector layers, because the attacks come in three shapes:

- **Step** catches jumps — crude spoofing, receiver glitches.
- **CUSUM** catches slow walks that never trip a step threshold — the patient
  version of the same attack.
- **Staleness** catches silence — jamming, an outage, a dead feed.

Every alarm carries its provenance: which channel, which detector, the value,
the threshold it crossed, and a message. An operator sees an explainable
event, not a red light.

A monitor that invents readings is worse than none, so a failed collector
raises a typed exception and a void GPS fix produces nothing at all — the
silence is then caught by the staleness detector rather than papered over with
a fabricated zero.

## Architecture

The core has **no third-party dependencies** — `dependencies = []`, standard
library only. Everything external is injected: sockets, clocks, serial ports
and stores are constructor parameters, which is what makes the whole suite
deterministic and runnable offline.

- **Daemon:** `atri-sangam-run`, reading from a simulator, `gpsd`, or a serial
  port, with a systemd unit for deployment
- **Storage:** SQLite by default, TimescaleDB behind the same interface
- **Dashboard:** an optional Dash app that opens the store read-only — health
  pills, residual strips, event log
- **Red-team simulator:** deterministic by seed, generating jamming, spoofing
  and drift scenarios, so thresholds can be tested against the attack they are
  meant to catch
- **Specification:** contracts written as concrete numeric scenarios, each one
  mirrored by a test — the design commitments are stated _and_ verified, not
  just asserted

## Status

Alpha. The monitor runs: the daemon, the detection layers, the
storage and the dashboard are built and tested, and the independent time
channels — NTP consensus, Roughtime, WWVB — are wired in and opt-in per site.

What is honestly not done: the solar channel exists as a predictor but is not
yet wired into the daemon, and the star-tracker channel is a roadmap idea. The
default thresholds are consumer-grade starting points, meant to be overridden,
and have not been validated against real jamming or spoofing hardware. Treat
them as a place to begin tuning, not as a calibrated defence.

Source code is private.

## See it

The [dashboard demo](/demos/atri-sangam/) replays four scenarios from the
red-team simulator: a healthy site, a slow spoof, a position jump, and an
outage. Each shows GPS plotted against the consensus band the independent
references span — a hairline when everything agrees, fanning open when it stops.

It is a recorded replay of simulated data, not a live installation.

## A different line of work

Atri Sangam shares no code and no thesis with the other products here. There
is no language model anywhere in it — nothing is generated, nothing is
inferred. It is arithmetic on residuals, and the reason it can be trusted is
that you can read every step of it.
