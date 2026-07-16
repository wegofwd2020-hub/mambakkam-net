---
title: StudyBuddy OnDemand
excerpt: Grade-aware STEM learning for Grades 5–12 — AI-generated content built ahead of time and served instantly, offline-capable, with teacher and school visibility.
author: siva-m
type: product
status: in-progress
url: https://demo.usestudybuddy.com/
image: ~/assets/images/work/studybuddy-ondemand-logo.png
tags:
  - Python
  - FastAPI
  - K-12
  - Education
  - PostgreSQL
  - Redis
  - Celery
featured: true
publishDate: 2026-04-28
draft: false
---

## What is StudyBuddy OnDemand?

StudyBuddy OnDemand is a backend-powered STEM learning platform for Grades 5–12. Lessons, quizzes, and audio are generated ahead of time by an LLM content pipeline and cached — so a student gets material the instant they ask for it, rather than waiting on a live model call.

The platform delivers that structured content, grades quizzes server-side, and tracks progress across subjects — on a multi-tenant architecture where every school is an isolated tenant. Independent teachers and home schoolers register as their own single-school tenant.

## The Problem It Solves

Access to quality academic support has always been uneven. Students in under-resourced schools or remote communities rarely get the same depth of support as those in urban or well-funded environments.

StudyBuddy OnDemand is built on the premise that generation cost and connectivity should not be the bottleneck. Content is built once per grade, subject, and unit, then served from cache to every student who needs it — and once downloaded, it works with no connection at all, queueing progress on the device until the network returns.

## Architecture

The platform is built on a modern async Python stack designed for reliability and scale:

- **API layer** — FastAPI with async handlers for high-concurrency request handling
- **Database** — PostgreSQL with asyncpg, tenant isolation enforced by row-level security
- **Task processing** — Celery with Redis for background jobs: content-pipeline runs, notifications, progress persistence, and scheduled digests
- **Validation** — Pydantic models throughout, with strict boundary validation
- **Observability** — Structured JSON logging via structlog, Prometheus metrics, health and readiness endpoints

## Design Principles

**Async-first.** Every database call, external integration, and background task is async — the platform is built to handle concurrent load without blocking.

**Multi-tenant from day one.** The school is the primary tenant — no user exists outside a school context, so even an independent teacher is a school of one. Isolation, role separation, and tenant-specific configuration are built into the core, not added later.

**Background tasks for everything non-critical.** Progress writes, streak updates, and notification sends are processed asynchronously — the student-facing request path stays fast.

**No floats for money.** Subscription pricing, build credits, and per-generation AI cost use `Decimal` throughout, stored as fixed-precision `NUMERIC` columns in PostgreSQL.

## Status

Late build. The content pipeline, curriculum lifecycle and governance, teacher authoring studio, server-side quiz grading, progress tracking, and subscription billing are implemented, alongside a self-serve demo. Platform hardening is in progress; launch readiness, onboarding, and accessibility are the next milestones. The student mobile client runs today as a Kivy app, with a React Native rewrite decided but not yet started.

## Documentation

Architecture notes, API specifications, and developer guides live alongside the code in the [StudyBuddy OnDemand repository](https://github.com/wegofwd2020-hub/StudyBuddy_OnDemand#readme).
