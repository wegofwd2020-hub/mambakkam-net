---
title: Thittam
excerpt: A multi-tenant SaaS platform for production management — one codebase, many verticals. Film productions, construction projects, software delivery, live events — all from a single declarative YAML vertical config.
author: siva-m
type: product
status: in-progress
image: ~/assets/images/work/thittam-logo.svg
landingUrl: /thittam
tags:
  - Go
  - gRPC
  - PostgreSQL
  - NATS JetStream
  - Redis
  - Multi-tenant
  - SaaS
  - Next.js
featured: true
comingSoon: true
publishDate: 2026-04-28
draft: false
---

## What is Thittam?

**Thittam** (திட்டம்) is Tamil for "plan" — and the name carries the intent precisely. It is a multi-tenant SaaS platform for production management: one codebase that adapts to any industry through a declarative vertical plugin system.

Film productions, construction firms, software teams, live event companies — each gets an instance of Thittam that speaks their domain's language: their entity names, their phase graphs, their budget categories, their workflows. No separate codebases. No forks. One system, many verticals.

## The Vertical Plugin System

The engineering differentiator in Thittam is the vertical config. Each tenant's industry is captured in a YAML file. Services read this config at request time and adapt accordingly — the same API endpoint behaves differently for a film production tenant versus a construction firm, because the vertical tells it how.

This means adding a new industry vertical is a configuration change, not a code change.

## Architecture

Nine Go microservices communicating synchronously over gRPC and asynchronously over NATS JetStream, fronted by Kong API Gateway for REST/JSON consumers.

| Service              | Role                                   |
| -------------------- | -------------------------------------- |
| project-management   | Productions, phases, crew, schedules   |
| budget-planning      | Budget versions, line items, approvals |
| expense-tracking     | POs, receipts, petty cash              |
| general-ledger       | Double-entry accounting                |
| inventory-management | Equipment, props, locations            |
| reporting-analytics  | Cross-service reports (read-only)      |
| iam                  | Identity, auth, RBAC, tenancy          |
| notifications        | Email, SMS, push, in-app               |
| document             | File storage, versioning, e-signatures |

**Persistence:** PostgreSQL with tenant-per-schema isolation — each tenant's tables live in a dedicated `tenant_<uuid>` schema. Redis for caching and rate limiting. MinIO for object storage.

**Frontend:** Next.js application at port 3100, adapting its UI to the active tenant's vertical configuration.

## Multi-tenancy Model

Data isolation is tenant-per-schema: `SET search_path` on the pooled connection routes each request to the correct tenant schema. No cross-tenant data leakage by design.

The full model — vertical plugin system, per-vertical UI adaptation, runbook for adding new tenants — is documented in the companion docs repository.

## Status

Active development. Two demo verticals are seeded: XYZ_CBA Productions (film, INR) and XYZ Construction LLC (construction, USD). Core services are implemented; work is ongoing on reporting, document e-signatures, and the billing service.

## Documentation

Architecture docs, ADRs, and API specifications live in the [Thittam Docs](https://github.com/wegofwd2020-hub/thittam_docs) repository — including 11 standard architecture diagrams maintained alongside the codebase.
