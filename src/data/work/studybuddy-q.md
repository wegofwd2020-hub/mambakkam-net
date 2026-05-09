---
title: StudyBuddy Q
excerpt: A focused, opinionated mobile learning app for adult self-learners — powered by the Anthropic API, with your own key. Not a chatbot. Not a course platform. A purpose-built learning tool.
author: siva-m
type: product
status: in-progress
tags:
  - React Native
  - Expo
  - FastAPI
  - Anthropic API
  - BYOK
  - Mobile
  - Self-learning
featured: false
publishDate: 2026-04-28
draft: false
---

## What is StudyBuddy Q?

**Q** stands for Query — a reference to the scoped-query model that is the core engineering idea.

StudyBuddy Q is a mobile learning client for adults who want to learn on their own terms. You bring your own Anthropic API key, describe what you want to understand, and get a beautifully rendered lesson, explanation, or quiz back.

The positioning is intentional: _"Claude Code, but for learners instead of coders."_

## What It Is Not

- Not a chatbot. There is no open-ended conversation mode.
- Not a course platform. There are no pre-built courses to enrol in.
- Not a children's product. No COPPA, no FERPA, no school compliance — adults only.

These are constraints by design, not limitations of scope.

## The BYOK Model

Users paste their own Anthropic API key. The app never stores it — it is held in memory for the session only and cleared when the app is closed. The user pays Anthropic directly for what they use.

This eliminates the subscription complexity, the payment rails, and the data custody problem in one move. The product can focus on the learning experience.

## Architecture

- **Mobile:** React Native with Expo — iOS and Android from one codebase
- **Backend:** FastAPI — handles the scoped-query pipeline, prompt construction, and response rendering
- **Pipeline:** A vendored prompt pipeline — deliberately isolated from the institutional StudyBuddy OnDemand product, sharing IP without sharing infrastructure

## Status

Pre-MVP. Architecture and scope decisions are documented. Directory structure and ADRs are in place. Application code is not yet written — this is the next product in the pipeline.

## Relationship to StudyBuddy OnDemand

StudyBuddy Q and [StudyBuddy OnDemand](/work/studybuddy-ondemand) are sister products with different audiences and architectures. OnDemand is the institutional B2B platform for schools. Q is the individual self-learner tool for adults. They share prompt IP via one-way vendoring — nothing else.
