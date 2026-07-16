---
title: Pramana
excerpt: A compliance-training tracking platform that produces auditable proof of completion. Named for प्रमाण ("valid means of knowledge"), v1 is SOX-scoped with an append-only, tamper-evident audit trail.
author: siva-m
type: product
status: in-client-deployment
image: ~/assets/images/work/pramana-logo.svg
tags:
  - Python
  - FastAPI
  - SQLAlchemy
  - PostgreSQL
  - Celery
  - SOX
  - Compliance
  - SAML/OIDC
  - AWS S3
featured: false
publishDate: 2026-06-07
draft: false
---

## What is Pramana?

**Pramana** — Sanskrit _प्रमाण_, "proof" or "valid means of knowledge" — is a
compliance-training and tracking platform. It assigns mandatory training, tracks
completion across an organization, and produces the **auditable evidence** that the
training actually happened. The name is literal: the system's job is to generate
_pramana_ of compliance.

## The problem it solves

Regulated companies must prove — to auditors, not just to themselves — that the right
people completed the right training on time. That proof has to be **tamper-evident**
and survive long retention windows. Pramana treats the audit trail as the product:
every assignment, reminder, completion, and exception is recorded in an append-only
log archived to immutable object storage.

## v1 scope

The first release is a **single-tenant** deployment scoped to **SOX (Sarbanes-Oxley)**
compliance training. The architecture is framework-aware from the start — HIPAA,
ISO/IEC 27001, GDPR, and PCI DSS are mapped on the roadmap — but v1 stays deliberately
narrow to ship a correct, defensible SOX workflow first.

## Architecture

- **Service:** Python 3.12+ with FastAPI, specified API-first against an OpenAPI 3.1
  contract
- **Data:** SQLAlchemy 2.x with Alembic migrations on PostgreSQL
- **Core domain:** a pure, well-tested **assignment state machine** that drives every
  training assignment from assigned → completed (or escalated)
- **Background work:** Celery + Redis for reminders, escalations, and report
  generation
- **Identity:** enterprise SSO via SAML / OIDC
- **Audit archive:** AWS S3 with Object Lock, so the compliance log is write-once and
  tamper-evident

## Status

Deployed as the client's SOX compliance-training platform. Delivery ran in four
governed phases — scaffolding, API specification, state machine, data model — using an
AI-assisted workflow operating under version-controlled conventions, with every change
ticketed and reviewed.

## Case study

The architecture decisions behind Pramana — immutability enforced at the database
level, the assignment lifecycle proven with property-based tests, and a spec-first API
contract — are written up in a
[public case study](https://github.com/wegofwd2020-hub/pramana-case-study). Source code
is private under the client engagement.
