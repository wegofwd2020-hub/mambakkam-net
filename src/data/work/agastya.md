---
title: AGASTYA
excerpt: >
  A reference implementation of a real-time cyber-attack detection and response
  pipeline — event scoring, MITRE ATT&CK mapping, alert management, and automated
  incident response. It runs and is tested (108 tests); an architecture demonstrator,
  not a hardened production SOC.
author: siva-m
type: product
status: in-progress
image: ~/assets/images/work/agastya-logo.svg
# The console first: it shows what the pipeline decided — the intake funnel and
# each alert's five-factor score breakdown — which is the part a reader cannot
# get from an endpoint list. Swagger second, for anyone who wants to call the
# API directly. The instance is read-only — the five mutating endpoints are
# refused at the proxy, not merely hidden by the app.
links:
  - label: Open the live console
    href: https://agastya.mambakkam.net
  - label: Browse the API
    href: https://agastya.mambakkam.net/api/docs
tags:
  - Python
  - FastAPI
  - Cybersecurity
  - MITRE ATT&CK
  - Threat Detection
  - Incident Response
  - GeoIP
  - Pydantic
featured: false
comingSoon: false
publishDate: 2026-08-08
draft: false
---

## What is AGASTYA?

**AGASTYA** is a reference implementation of a real-time cyber-attack detection
and response pipeline. It takes in security events, enriches and scores them,
maps them onto known adversary behavior, and carries them through to an alert
or an automated response — the shape of a SOC pipeline, built and tested end
to end.

It is not a product sold to a customer. It is a design study: an answer to
"what does a defensible, explainable detection pipeline actually look like,
end to end, when every stage is real code and every claim is backed by a
test?" The pipeline runs. It has a 108-test suite, all passing. It is an
architecture demonstrator, not a hardened SOC.

## Why the name

Agastya is one of the Saptarishi, the seven great sages, and one of the very
few sages the sky itself is named for: Canopus, the second-brightest star in
the night sky, is called Agastya in Sanskrit astronomical tradition. Canopus
sits low and steady in the southern sky — too far south to be seen from much
of the northern hemisphere, which is part of why old sailing and navigation
traditions leaned on it as a fixed point to steer by. A star you orient
yourself against because it does not move.

The other half of the story is more violent. Agastya is the sage who drank
the ocean dry — Vatapi's other victims had done it before and burst, but
Agastya simply drank Vatapi down and digested him before he could
reconstitute and kill again. Between the two images — the fixed point
watchers steer by, and the sage who consumes what would otherwise consume
others — the name fit a pipeline whose whole job is to watch continuously and
absorb what comes at it before it does damage. The tie is thematic, not
literal; AGASTYA does not navigate ships or drink oceans. It watches events
and consumes threats before they turn into incidents.

## The problem it solves

Attacks against any exposed service are constant and cheap to mount — scanning,
credential stuffing, exploitation attempts arrive whether or not anyone is
watching. Each one, taken alone, can look almost like noise. The difficulty is
rarely spotting a single loud event; it is separating the handful of events
that matter from the flood of ones that don't, without either drowning an
analyst in false positives or filtering so aggressively that a real campaign
slips through as a string of individually-unremarkable events.

Two failure modes recur in practice. Alert fatigue: a system that flags
everything trains its operators to ignore everything, and the real alert
gets lost with the noise. And correlation blindness: attacks that unfold in
stages — reconnaissance, then a foothold, then lateral movement, then
exfiltration — don't look like an attack if each stage is scored on its own.
They look like an attack only once someone connects them across time and
geography. AGASTYA's pipeline is built around both problems: scoring that
tries to separate signal from noise, and a correlation stage whose job is
specifically to notice when a set of otherwise-quiet events are actually one
campaign.

## How it works

The pipeline is a straight line, each stage handing a structured result to
the next:

- **Event ingestion** — attack events enter through a FastAPI service, with
  Swagger/OpenAPI docs describing every endpoint.
- **Multi-source GeoIP enrichment** — an event's origin is resolved against
  more than one GeoIP source, and a consensus score is derived from where
  they agree (and how much they disagree).
- **5-factor composite threat scoring** — each event is scored across five
  independent factors and combined into a single composite score, rather than
  relying on any one signal to carry the decision.
- **MITRE ATT&CK mapping** — scored events are mapped onto ATT&CK tactics and
  techniques, so an alert reads as "this looks like credential access" rather
  than a bare severity number.
- **Alert management** — dynamic thresholds, deduplication, and suppression
  keep repeated or related events from becoming repeated alerts.
- **Attack-campaign correlation** — related alerts are grouped into
  candidate campaigns, so a multi-stage attack shows up as one story instead
  of many disconnected ones.
- **Incident-response automation** — a confirmed incident can drive a
  ticket, a firewall rule, or a notification, without a human wiring each of
  those actions by hand.

A v1.5 layer adds risk scoring, response playbooks, automated escalation,
forensic evidence preservation, and proactive threat hunting on top of that
core pipeline.

## What it is (and isn't)

AGASTYA runs, and it is tested: 108 tests, all passing, against a FastAPI
service with Swagger docs describing the API surface. What you can stand up
and exercise today is real code doing real scoring, mapping, and correlation
logic — not a mockup of a dashboard.

You can check that yourself: the links above open a live instance, where the console shows the intake funnel and each alert's score broken into the five factors that produced it. Its
data is seeded at startup by replaying canned attack scenarios through the
same pipeline the ingest endpoint uses, so the alerts, MITRE mappings,
incidents and campaigns you see are genuine output of the scoring code rather
than fixtures written to look convincing. Twenty-one events produce four
alerts — the rest are absorbed by deduplication and rate limiting, which is
the funnel working, not the detector missing.

The instance is deliberately read-only. Its five mutating endpoints are
refused by the reverse proxy before a request reaches Python, and the
application drops them from its own route table as a second layer. Publishing
a writable security tool would have been an invitation.

What it is not: it is not battle-tested against real adversaries, and it
does not ingest live traffic. It operates on mock data — event streams
constructed to exercise the pipeline's logic, not production telemetry from
an actual network under attack. It has not been through a red team, has not
been tuned against real attacker behavior, and has not carried the
operational load of a real SOC. It is a personal, AI-assisted design study —
built to work through what a defensible detection-and-response architecture
looks like when every stage has to be specified and tested, not a
production-ready security product. Treat it as a reference architecture to
learn from, not a system to deploy in front of anything that matters.
