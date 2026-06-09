---
title: AI Learning Platform
excerpt: A production-grade enterprise AI tutoring system — combining LLMs, Retrieval-Augmented Generation, vector search, adaptive quizzes, and event-driven learning analytics for grade-based STEM education.
author: siva-m
type: research
status: in-progress
image: ~/assets/images/work/ai-learning-platform-logo.svg
tags:
  - Python
  - FastAPI
  - LLM
  - RAG
  - Milvus
  - Kafka
  - Kubernetes
  - Vector Search
  - Anthropic API
  - STEM
featured: false
listed: false
publishDate: 2026-04-28
draft: false
---

## What is the AI Learning Platform?

The AI Learning Platform (v5) is an enterprise-grade AI tutoring and adaptive learning system — built to deliver personalised, grade-based STEM education at scale.

It is the architectural reference implementation for AI-powered education: demonstrating how LLMs, RAG, vector search, and event-driven analytics can be composed into a coherent, production-grade learning system rather than a demo.

## Core Capabilities

- **AI tutoring** using LLMs (OpenAI or local models via Ollama)
- **Retrieval-Augmented Generation** for curriculum-grounded responses — the tutor answers from the actual curriculum, not from general training data
- **Adaptive quiz generation and evaluation** — questions adjust to the student's demonstrated level
- **Student learning progress prediction** — analytics that surface where a student is likely to struggle before they do
- **Event-driven learning analytics** — every interaction is an event; the analytics layer composes a full learning picture from the stream
- **Production-grade observability** — metrics, tracing, dashboards from day one
- **Cloud-native deployment** — Docker and Kubernetes throughout

## Architecture

The platform is a set of independently deployable services behind a FastAPI gateway:

**Tutor Service** — handles the student-facing query loop. Retrieves relevant curriculum context from the vector store, constructs a grounded prompt, calls the LLM provider, and returns a rendered lesson or explanation.

**Quiz Engine** — generates adaptive questions and evaluates responses. State is held in Redis; question difficulty adjusts per session.

**Curriculum API** — manages the curriculum corpus. Chunks content, generates embeddings, and serves retrieval requests to the Tutor Service.

**Analytics Service** — consumes the Kafka event stream and writes derived learning metrics to PostgreSQL. Progress predictions are computed here.

## The RAG Pipeline

The key technical decision is the RAG architecture. Rather than relying on general LLM knowledge for educational content, every tutor response is grounded in the curriculum:

1. Curriculum content is chunked and embedded into a vector store (Milvus or FAISS)
2. The student's query is embedded and used for semantic retrieval
3. Retrieved curriculum chunks are injected into the LLM prompt as context
4. The tutor's response reflects what the curriculum actually says — not what the model happens to know

This makes the tutor accurate, auditable, and updatable: swap the curriculum, get a different tutor.

## Status

Active research and development. The platform serves as the architectural foundation for the StudyBuddy product line — validating the AI tutoring patterns before they are applied to production products.
