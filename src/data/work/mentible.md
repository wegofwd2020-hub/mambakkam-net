---
title: Mentible
excerpt: An AI book-authoring app for adult self-learners. Structure a topic, generate it chapter by chapter, and compile a polished EPUB3/PDF book — provider-agnostic, with managed keys or your own. Formerly StudyBuddy Q.
author: siva-m
type: product
status: in-progress
image: ~/assets/images/work/mentible-logo.png
tags:
  - React Native
  - Expo
  - FastAPI
  - Multi-provider LLM
  - EPUB3
  - PDF
  - BYOK
  - Self-learning
  - Mobile
featured: false
publishDate: 2026-04-28
updateDate: 2026-06-07
draft: false
---

## What is Mentible?

Mentible is an AI **authoring** app for adults who learn on their own terms. You
describe what you want to understand, structure it as a multi-chapter book, generate
the content topic by topic, and **compile it into a polished EPUB3 / PDF book** —
cover and all. The finished book is the product: yours to keep, read offline, and
share.

The tagline says it best: **_Author Yourself._** — author the material, and author
who you become.

> Mentible began life as **StudyBuddy Q**. It has since been rebranded and spun out
> as an independent product, distinct from the StudyBuddy school platform.

## Books, not chat

Mentible is deliberately **books-only**. An earlier one-off "Query" mode (generate a
single throwaway lesson) was removed once the centre of gravity became authoring a
real artifact. There is no open-ended chatbot and no catalogue of pre-built courses —
just the focused loop of outline → generate → compile.

## Provider-agnostic, your choice of keys

Mentible is not tied to a single AI vendor. It works across Anthropic and the
OpenAI-compatible providers (OpenAI, DeepSeek, Qwen, Gemma). Key handling is
**hybrid**: a managed default (a subscription with a metered token allowance, so you
just start writing) and an optional **bring-your-own-key** path for power users who
want to pay the provider directly.

## Who it's for

Adults only — self-learners and working professionals who want to go deep on a
subject at their own pace. It is a standalone tool with no school compliance
(no COPPA, no FERPA) and no funnel into the institutional product.

## Architecture

- **Mobile:** React Native with Expo — iOS, Android, and web from one codebase
- **Backend:** FastAPI — the scoped-query generation engine behind every chapter
- **Compiler:** a TypeScript pipeline that renders generated content into EPUB3 / PDF
  artifacts with real covers, a template + theme system, and a release lifecycle
  (draft watermarking → published)
- **Delivery:** the compiled book is the deliverable, read in a separate free,
  offline reader app

## Status

Actively in development. The mobile authoring app (library, real EPUB covers, book
import/export) and the compiler (theming, covers, watermarking) are taking shape;
accounts, metering, and the managed-key path are the MVP focus. The **Mentible** name
is the chosen brand, pending final trademark and domain clearance.

## Relationship to StudyBuddy OnDemand

Mentible and [StudyBuddy OnDemand](/work/studybuddy-ondemand) are independent sister
products. OnDemand is the institutional B2B platform for schools; Mentible is the
individual self-learner authoring tool for adults. They share prompt-generation IP
via one-way vendoring — nothing else.
