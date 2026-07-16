---
title: Mentible
excerpt: An AI book-authoring tool for adult self-learners. The model is the commodity — you set the scope and boundaries, and Mentible compiles a polished EPUB3/PDF book that's exactly what you decided. Provider-agnostic, with managed keys or your own.
author: siva-m
type: product
status: live
url: https://mambakkam.net/demos/mentible/
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
updateDate: 2026-06-23
draft: false
---

## What is Mentible?

Mentible is an AI **authoring** tool for adults who learn on their own terms — the model supplies the content; **you** supply the scope, the boundaries, and the shape. You
describe what you want to understand, structure it as a multi-chapter book, generate
the content topic by topic, and **compile it into a polished EPUB3 / PDF book** —
cover and all. The finished book is the product: yours to keep, read offline, and
share.

The tagline says it best: **_Author Yourself._** — author the material, and author
who you become.

## Books, not chat

Mentible is deliberately **books-only**. There is no one-off "throwaway lesson" mode,
no open-ended chatbot, and no catalogue of pre-built courses — just the focused loop of
outline → generate → compile a real artifact.

## Try it

There's a **public web demo** running at
[mambakkam.net/demos/mentible](https://mambakkam.net/demos/mentible/) — a
reading-first preview you can open straight in the browser, no install. The
[full product page](/mentible) has the same demo plus an Android build to sideload.

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

Actively in development, with a **public web demo live** (a reading-first preview —
see [Try it](#try-it) above). The mobile authoring app (library, real EPUB covers, book
import/export) and the compiler (theming, covers, watermarking) are taking shape;
accounts, metering, and the managed-key path are the MVP focus. **Mentible** is the
chosen brand, pending final trademark and domain clearance.

## Relationship to StudyBuddy OnDemand

Mentible and [StudyBuddy OnDemand](/work/studybuddy-ondemand) are independent sister
products. OnDemand is the institutional B2B platform for schools; Mentible is the
individual self-learner authoring tool for adults. They share prompt-generation IP
via one-way vendoring — nothing else.
