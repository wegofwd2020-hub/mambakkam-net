---
title: StudyBuddy AI
excerpt: An AI-powered STEM learning companion for students in Grades 5–12 — delivering personalised lessons, adaptive quizzes, and step-by-step tutorials via the Anthropic Claude API. Ships as an Android app and desktop application.
author: siva-m
type: product
status: live
tags:
  - Python
  - Kivy
  - Anthropic API
  - Android
  - STEM
  - Education
  - Claude
featured: false
publishDate: 2026-04-28
draft: false
---

## What is StudyBuddy AI?

StudyBuddy AI is a Python/Kivy application that puts an AI-powered STEM tutor in the hands of students in Grades 5 through 12. It runs on Android phones, Android tablets, Chromebooks, and desktop (Windows/macOS/Linux) from a single codebase.

Students register once. From there, they read AI-generated chapter content matched to their grade level, take adaptive quizzes with instant feedback, receive hints when they struggle, and get personalised step-by-step tutorials when a concept isn't landing.

## How It Works

The core loop is straightforward:

1. The student selects a subject and chapter for their grade
2. The app generates a lesson using the Claude API — written at the right level, in the right voice
3. The student takes a quiz; responses are evaluated immediately with feedback
4. If the student struggles, a tutorial is generated on the spot — targeted at exactly what went wrong

A live token counter on the home screen keeps the student (and parents) informed of remaining usage. A built-in subscription screen handles top-ups.

## Token-based Access Model

Usage is metered by tokens — the same unit the Anthropic API uses. Students purchase token bundles; the app tracks and displays consumption in real time. This keeps the unit economics transparent and gives students and parents direct visibility into usage.

## Platform Support

| Device                          | Supported     |
| ------------------------------- | ------------- |
| Android phone (portrait)        | Yes           |
| Android tablet                  | Yes           |
| Chromebook (Android app)        | Yes           |
| Windows / macOS / Linux desktop | Yes           |
| iOS                             | Not currently |

## Status

**Shipped.** Version 1.1.0 released March 2025. Active on Android and desktop. This is the earliest production StudyBuddy product — the experience and learnings from building it directly shaped the architecture of [StudyBuddy OnDemand](/work/studybuddy-ondemand) and [Mentible](/work/mentible).
