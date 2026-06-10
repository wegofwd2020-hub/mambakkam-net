# Documentation Index — mambakkam.net + StudyBuddy ecosystem

> **Cross-repo doc map.** Single place to find any operational, architectural,
> product, or market-research document across the three sibling repos. Aims to
> reduce duplication by surfacing overlapping docs in the "Cross-repo overlaps"
> section below.

**Status:** v1, hand-curated 2026-05-17. A nightly workflow will be added to
keep this current — see `scripts/docs_index/README.md` once built (proposal
sketched in the launch-paused operator notes). Until then, **adding a new doc
to any of the three repos means updating this file by hand**.

**Path convention:** Links use relative `../` paths that assume the three repos
are siblings under one parent dir (the local-dev layout). These do NOT render
on GitHub's web UI because `..` escapes the current repo — open this file in
your editor or browse via the local filesystem.

---

## Repos covered

| Repo                  | Local path                | Role                                                                                                |
| --------------------- | ------------------------- | --------------------------------------------------------------------------------------------------- |
| `mambakkam-net`       | `./` (this repo)          | Primary site mambakkam.net + first-tenant of the shared CX23 + cross-repo operational orchestration |
| `studybuddy-docs`     | `../studybuddy-docs/`     | Architectural & product docs for the StudyBuddy platform; market research; promo decks              |
| `StudyBuddy_OnDemand` | `../StudyBuddy_OnDemand/` | StudyBuddy backend + web + mobile application code, epic-level planning, demo readiness             |

**Site mapping:**

- `mambakkam.net` — served by `mambakkam-net`
- `demo.usestudybuddy.com` — served by `StudyBuddy_OnDemand` (second tenant on the same CX23)

---

## Topic index

Tables below group docs by the question an operator is trying to answer.
Within each table, rows are ordered roughly architecture-ref → plan → runbook.

### 1. Hosting, Deployment & Cost

| Doc                                                                                      | Purpose                                                                                                                       |
| ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| [DEMO_HOSTING_GUIDE](../studybuddy-docs/docs/dev/DEMO_HOSTING_GUIDE.md)                  | Architecture ref for the shared CX23 demo box: cost table, why-this-shape, demo-mode simplifications                          |
| [DEPLOYMENT_PLAN](Plans/DEPLOYMENT_PLAN.md)                                              | mambakkam.net deployment + monthly cost breakdown ($6.44/mo mambakkam side, ~$7.30/mo all-in)                                 |
| [DEMO_LAUNCH_PLAN (mambakkam)](Plans/DEMO_LAUNCH_PLAN.md)                                | Operator runbook for the May 17 launch — co-located on the StudyBuddy CX23, cold start + cutover + post-launch                |
| [DEMO_LAUNCH_PLAN (StudyBuddy)](../StudyBuddy_OnDemand/docs/DEMO_LAUNCH_PLAN.md)         | StudyBuddy-side launch plan for the same event — parallel doc to the one above (see Overlaps §1)                              |
| [DEMO_HOSTING_READINESS](../StudyBuddy_OnDemand/docs/DEMO_HOSTING_READINESS.md)          | Readiness checklist snapshot for StudyBuddy demo launch                                                                       |
| [PRODUCTION_DEPLOYMENT](../studybuddy-docs/PRODUCTION_DEPLOYMENT.md)                     | AWS production deployment guide (ECS Fargate, RDS Multi-AZ, ElastiCache, CloudFront) — future-state for first paying customer |
| [DEPLOYMENT (docs/)](../studybuddy-docs/docs/DEPLOYMENT.md)                              | Generic deployment reference within studybuddy-docs                                                                           |
| [CLOUD_HOSTING](../studybuddy-docs/CLOUD_HOSTING.md)                                     | Cloud-platform decision matrix (AWS vs GCP vs Azure) for production-tier hosting                                              |
| [COST_PLAN](../studybuddy-docs/COST_PLAN.md)                                             | StudyBuddy hosting cost + revenue projections across launch/growth/scale tiers                                                |
| [deployment_environments](../studybuddy-docs/market_research/deployment_environments.md) | Pointer index: where demo vs production hosting docs moved after the 2026-05-08 split                                         |
| [VM_LOCALHOST_BOOTSTRAP](../StudyBuddy_OnDemand/docs/VM_LOCALHOST_BOOTSTRAP.md)          | Local-VM bootstrap for development / pre-launch testing                                                                       |
| [SCALABILITY](../studybuddy-docs/SCALABILITY.md)                                         | Scaling plan from launch-tier infra to multi-school production                                                                |

### 2. Observability — Metrics, Logs, Alerts

| Doc                                                  | Purpose                                                                                        |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| [MONITORING](Plans/MONITORING.md)                    | Prometheus + node/blackbox/nginx exporters on CX23 + `remote_write` to Grafana Cloud free tier |
| [LOGGING](Plans/LOGGING.md)                          | Promtail → Grafana Cloud Loki (50 GB / 14d) + LogQL cheatsheet + local-fallback runbook        |
| [RUNBOOK](Plans/RUNBOOK.md)                          | 14 alert rules + per-alert response procedures (Mambakkam/StudyBuddy/CX22*/Restic*)            |
| [OBSERVABILITY](../studybuddy-docs/OBSERVABILITY.md) | StudyBuddy-side observability strategy (broader than the demo runbook)                         |

### 3. Backups & Disaster Recovery

| Doc                         | Purpose                                                                                                 |
| --------------------------- | ------------------------------------------------------------------------------------------------------- |
| [BACKUPS](Plans/BACKUPS.md) | Restic-based encrypted backups + 5-scenario restore drill; off-box deferred until first paying customer |

### 4. Launch & Day-of Operations

| Doc                                                                          | Purpose                                                                                                        |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| [ACCOUNT_SETUP](Plans/ACCOUNT_SETUP.md)                                      | Day -1 (Sat May 16) account-setup runbook — Cloudflare, Hetzner, Email Routing, Grafana Cloud                  |
| [HOSTING_ACTIVITY_LOG](Plans/HOSTING_ACTIVITY_LOG.md)                        | Chronological log of operator actions on live infra — provisioning, deploys, incidents. Appended to over time. |
| [DEMO_EMAIL_INVENTORY](../StudyBuddy_OnDemand/docs/DEMO_EMAIL_INVENTORY.md)  | StudyBuddy demo email-address inventory + routing                                                              |
| [OPERATIONS](../studybuddy-docs/OPERATIONS.md)                               | StudyBuddy steady-state operations guide                                                                       |
| [school-onboarding](../studybuddy-docs/docs/operations/school-onboarding.md) | Migration runbook: demo → production for a new school                                                          |
| [SCHOOL_ONBOARDING_TEMPLATE](../StudyBuddy_OnDemand/onboarding_template/SCHOOL_ONBOARDING_TEMPLATE.md) | School onboarding intake template — collects school details, teacher list, and student roster before provisioning accounts and sending first-login emails |

### 5. DNS, Email, Edge & Security

| Doc                                                                                  | Purpose                                                                             |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| [dns-and-email-setup](../studybuddy-docs/docs/operations/dns-and-email-setup.md)     | Step-by-step DNS + email setup (Cloudflare + Email Routing) for `usestudybuddy.com` |
| [cloudflare-edge-setup](../studybuddy-docs/docs/operations/cloudflare-edge-setup.md) | Cloudflare edge config: TLS, Origin Cert, DDoS, page rules                          |
| [NETWORK_SECURITY](../studybuddy-docs/docs/NETWORK_SECURITY.md)                      | Network-level security posture (firewall, ingress, TLS)                             |
| [CODE_QUALITY_SECURITY](../studybuddy-docs/docs/CODE_QUALITY_SECURITY.md)            | Code-side security policy: linting, SAST, dependency audit                          |
| [SecurityPosture](../studybuddy-docs/docs/promos/SecurityPosture.md)                 | Security-posture slide deck for buyers/prospects                                    |

### 6. Architecture

| Doc                                                                                                           | Purpose                                                                                 |
| ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| [DESIGN_people_work_pages](docs/DESIGN_people_work_pages.md)                                                  | mambakkam-net site: people/work content model, owner-scoped `/work`, per-person work pages, adding a person |
| [ARCHITECTURE](../studybuddy-docs/ARCHITECTURE.md)                                                            | Top-level StudyBuddy architecture: services, data flow, boundaries                      |
| [BACKEND_ARCHITECTURE](../studybuddy-docs/BACKEND_ARCHITECTURE.md)                                            | FastAPI + Celery + Postgres + Redis backend design                                      |
| [AI_ARCHITECTURE](../studybuddy-docs/docs/AI_ARCHITECTURE.md)                                                 | AI/LLM integration architecture for the StudyBuddy platform                             |
| [DOMAIN_MODEL](../studybuddy-docs/docs/DOMAIN_MODEL.md)                                                       | Core domain entities and their relationships                                            |
| [EVENT_SCHEMAS](../studybuddy-docs/docs/EVENT_SCHEMAS.md)                                                     | Pub/sub event payload schemas                                                           |
| [SERVICE_DEPENDENCIES](../studybuddy-docs/docs/SERVICE_DEPENDENCIES.md)                                       | Inter-service dependency map (what calls what)                                          |
| [WEB_FRONTEND_PLAN](../studybuddy-docs/WEB_FRONTEND_PLAN.md)                                                  | Next.js web app architecture + UI plan                                                  |
| [mobile/ARCHITECTURE](../StudyBuddy_OnDemand/mobile/ARCHITECTURE.md)                                          | Mobile app architecture                                                                 |
| [ADR_001](../StudyBuddy_OnDemand/docs/ADR_001_tenancy_and_subscription_model.md)                              | Architecture Decision Record #1 — tenancy + subscription model                          |
| [DESIGN_pipeline_classification](../StudyBuddy_OnDemand/docs/DESIGN_pipeline_classification.md)               | Why `pipeline/build_unit.py` is a structured LLM workflow, not an agent — framing guide |
| [DESIGN_EXPLORATION_MULTI_PROVIDER_LLM](../StudyBuddy_OnDemand/docs/DESIGN_EXPLORATION_MULTI_PROVIDER_LLM.md) | Design exploration for multi-provider LLM (Anthropic + OpenAI + others)                 |
| [DESIGN_HELP_SYSTEM](../StudyBuddy_OnDemand/docs/DESIGN_HELP_SYSTEM.md)                                       | In-app help system design                                                               |
| [DESIGN_lesson_retention_service](../StudyBuddy_OnDemand/docs/DESIGN_lesson_retention_service.md)             | Lesson-retention service design                                                         |
| [DESIGN_content_versioning_lifecycle](../StudyBuddy_OnDemand/docs/DESIGN_content_versioning_lifecycle.md)     | Content versioning lifecycle design                                                     |
| [DESIGN_demo_request_access](../StudyBuddy_OnDemand/docs/DESIGN_demo_request_access.md)                       | Self-service request-access flow design (draft, not implemented)                        |
| [DESIGN_demo_videos](../StudyBuddy_OnDemand/docs/DESIGN_demo_videos.md)                                       | Feature-videos design for demo site (draft, not implemented)                            |
| [ADR_004](../StudyBuddy_OnDemand/docs/ADR_004_authoring_studio_home_repo.md)                                  | Architecture Decision Record #4 — standalone authoring + reader home is StudyBuddy Q (Mentible), not OnDemand |
| [ADR_005](../StudyBuddy_OnDemand/docs/ADR_005_school_roles_and_uniqueness.md)                                 | Architecture Decision Record #5 — `school_admin` as teacher superset, email-only uniqueness, soft-delete account lifecycle |
| [ADR_006](../StudyBuddy_OnDemand/docs/ADR_006_multi_provider_llm.md)                                          | Architecture Decision Record #6 — multi-provider LLM pipeline design; formalises Epic 1 (Anthropic/OpenAI/Gemini, provider column, DPA model) |
| [DESIGN_curriculum_mgmt_capability](../StudyBuddy_OnDemand/docs/DESIGN_curriculum_mgmt_capability.md)         | Design doc for the additive `curriculum_mgmt` capability grant (migration 0059) — commission/review/management per teacher, Administration menu IA |
| [SPEC_curriculum_mgmt_capability](../StudyBuddy_OnDemand/docs/SPEC_curriculum_mgmt_capability.md)             | Implementation spec for the `curriculum_mgmt` capability — endpoint guards, token factory patterns, and migration 0059 test coverage |
| [SCHOOL_USER_MANAGEMENT](../StudyBuddy_OnDemand/docs/SCHOOL_USER_MANAGEMENT.md)                               | Functional spec for school user account lifecycle — provisioning, role model, soft-delete; companion to ADR-005 |

### 7. API & Services

| Doc                                                           | Purpose                                            |
| ------------------------------------------------------------- | -------------------------------------------------- |
| [API_INDEX](../studybuddy-docs/docs/API_INDEX.md)             | Top-level API endpoint index                       |
| [API_REFERENCE](../studybuddy-docs/docs/api/API_REFERENCE.md) | Detailed API reference (endpoints, auth, payloads) |
| [CELERY_TASKS](../studybuddy-docs/docs/api/CELERY_TASKS.md)   | Celery task catalog: triggers, queues, schedules   |

### 8. Application-Side Runbooks (StudyBuddy)

| Doc                                                                                                    | Purpose                                                      |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ |
| [RB-celery-beat-crash](../studybuddy-docs/docs/runbooks/RB-celery-beat-crash.md)                       | Recovery procedure when Celery Beat crashes                  |
| [RB-db-connection-pool-exhausted](../studybuddy-docs/docs/runbooks/RB-db-connection-pool-exhausted.md) | DB connection-pool exhaustion response                       |
| [RB-pipeline-failure-mid-run](../studybuddy-docs/docs/runbooks/RB-pipeline-failure-mid-run.md)         | Resume/cleanup procedure when content pipeline fails mid-run |
| [RB-redis-oom-eviction](../studybuddy-docs/docs/runbooks/RB-redis-oom-eviction.md)                     | Redis OOM / key-eviction response                            |
| [RB-stripe-webhook-backlog](../studybuddy-docs/docs/runbooks/RB-stripe-webhook-backlog.md)             | Stripe webhook-backlog drain procedure                       |

### 9. CI/CD & Developer Setup

| Doc                                                                  | Purpose                                                                                                                      |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| [CICD_PIPELINE](../studybuddy-docs/docs/CICD_PIPELINE.md)            | CI/CD pipeline architecture (GH Actions + image build + deploy)                                                              |
| [DEV_ACCOUNTS](../studybuddy-docs/docs/dev/DEV_ACCOUNTS.md)          | Dev-account inventory (Auth0, Stripe, Sentry, etc.)                                                                          |
| [PHASE1_SETUP](../studybuddy-docs/docs/dev/PHASE1_SETUP.md)          | Phase 1 local-dev setup procedure                                                                                            |
| [TESTING_SETUP](../studybuddy-docs/docs/dev/TESTING_SETUP.md)        | Test-environment setup                                                                                                       |
| [LOCAL_TESTING_GUIDE](../StudyBuddy_OnDemand/LOCAL_TESTING_GUIDE.md) | Local end-to-end testing guide                                                                                               |
| [TESTING_VISUALS](../StudyBuddy_OnDemand/docs/TESTING_VISUALS.md)    | Visual-content testing approach                                                                                              |
| [web/TEST_CASES](../StudyBuddy_OnDemand/web/docs/TEST_CASES.md)      | Web test-case catalog: 56 routes × 99 unit + 34 E2E tests across Public/Student/School/Admin portals (TC-ID table per route) |
| [VISUAL_VALIDATION_GUIDE](../StudyBuddy_OnDemand/docs/feedback/VISUAL_VALIDATION_GUIDE.md) | Step-by-step walkthrough to visually confirm UI fixes from demo feedback (VT-1…VT-5, GG-1, AR-1…AR-3, SR-1, AP-1…AP-5) are live on the running app |

### 10. Content, Visuals & Curriculum Authoring

| Doc                                                                                         | Purpose                                                      |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| [CONTENT_CATALOG](../studybuddy-docs/docs/CONTENT_CATALOG.md)                               | Catalog of curriculum content available in the platform      |
| [VISUAL_CONTENT_LIFECYCLE](../studybuddy-docs/VISUAL_CONTENT_LIFECYCLE.md)                  | Lifecycle of visual content from generation to delivery      |
| [MEDIA_GENERATION_SERVICES](../StudyBuddy_OnDemand/docs/MEDIA_GENERATION_SERVICES.md)       | Survey of media-generation services (text/image/video/audio) |
| [VISUAL_LIBRARY_SIDECAR](../StudyBuddy_OnDemand/docs/VISUAL_LIBRARY_SIDECAR.md)             | Visual-library sidecar metadata format                       |
| [visual_presentation_research](../StudyBuddy_OnDemand/docs/visual_presentation_research.md) | Research notes on visual presentation patterns               |
| [SCENARIO_AUTHORING_TEMPLATE](../StudyBuddy_OnDemand/docs/SCENARIO_AUTHORING_TEMPLATE.md)   | Template for authoring new scenarios/lessons                 |
| [CURRICULUM_ONBOARDING_FLOW](../StudyBuddy_OnDemand/docs/CURRICULUM_ONBOARDING_FLOW.md)     | Flow map showing all paths from nothing to student-visible curriculum — platform catalog, school adopt, and school-build — with state transitions and actor permissions |

### 11. Product, Requirements & Roadmap

| Doc                                                                                         | Purpose                                                             |
| ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| [REQUIREMENTS](../studybuddy-docs/REQUIREMENTS.md)                                          | Top-level product requirements                                      |
| [FEATURE_ROADMAP](../studybuddy-docs/FEATURE_ROADMAP.md)                                    | Feature roadmap across releases                                     |
| [USE_CASES](../StudyBuddy_OnDemand/docs/USE_CASES.md)                                       | End-user use cases (student/teacher/admin/parent)                   |
| [SUBSCRIPTION_MODEL](../StudyBuddy_OnDemand/docs/SUBSCRIPTION_MODEL.md)                     | Subscription tiers + entitlements + pricing                         |
| [UX_GOALS](../studybuddy-docs/UX_GOALS.md)                                                  | UX goal statements                                                  |
| [UX_REQUIREMENTS](../studybuddy-docs/UX_REQUIREMENTS.md)                                    | UX-specific requirements                                            |
| [UNIFIED_LANDING_DESIGN](../studybuddy-docs/UNIFIED_LANDING_DESIGN.md)                      | Unified-landing-page design                                         |
| [UNIFIED_LANDING_DESIGN_ADDENDUM](../studybuddy-docs/UNIFIED_LANDING_DESIGN_ADDENDUM.md)    | Addendum to the unified-landing design                              |
| [REGISTRATION_DESIGN_ANALYSIS](../StudyBuddy_OnDemand/docs/REGISTRATION_DESIGN_ANALYSIS.md) | Analysis of registration-flow design alternatives                   |
| [REGISTRATION_DESIGN_QA](../StudyBuddy_OnDemand/docs/REGISTRATION_DESIGN_QA.md)             | QA notes on the chosen registration design                          |
| [BRANDING_I18N_DRAFT](../StudyBuddy_OnDemand/docs/BRANDING_I18N_DRAFT.md)                   | Branding + internationalization draft notes                         |
| [BRANDING_TAGLINE_OPTIONS](../StudyBuddy_OnDemand/docs/BRANDING_TAGLINE_OPTIONS.md)         | Tagline option exploration (see Overlaps §3)                        |
| [TaglineOptions (promos)](../studybuddy-docs/docs/promos/TaglineOptions.md)                 | Tagline options as presented to outside audiences (see Overlaps §3) |
| [RESPONSIVE_TARGET](../StudyBuddy_OnDemand/docs/RESPONSIVE_TARGET.md)                      | Device and viewport target matrix per StudyBuddy surface — clarifies intended device class so reviewers don't mistake expected behavior for a bug |

### 12. Epics (status-driven, large work units)

> **Sub-index first:** [`epics/INDEX.md`](../StudyBuddy_OnDemand/docs/epics/INDEX.md) is the
> canonical status board (status + ticket prefix per epic). The rows below mirror
> that list so this index stays drift-detectable. 17 active epics (1–13, 15–18;
> EPIC_14 number unused).

| Doc                                                                                                                 | Purpose                                                                                                                                            |
| ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| [epics/INDEX](../StudyBuddy_OnDemand/docs/epics/INDEX.md)                                                           | **Sub-index** of all EPIC*NN*\*.md files — canonical status + ticket-prefix board                                                                  |
| [PROGRESS](../StudyBuddy_OnDemand/docs/PROGRESS.md)                                                                 | **Auto-generated** nightly from epics + git log by `progress.yml` workflow                                                                         |
| [EPIC_01_multi_provider_llm](../StudyBuddy_OnDemand/docs/epics/EPIC_01_multi_provider_llm.md)                       | Epic 1 — Multi-Provider LLM Pipeline. ✅ Complete (F-1–F-5, 19 tests, migration 0043). Full design in [[DESIGN_EXPLORATION_MULTI_PROVIDER_LLM]]    |
| [EPIC_02_production_launch](../StudyBuddy_OnDemand/docs/epics/EPIC_02_production_launch.md)                         | Epic 2 — Production Launch & Demo Readiness. 🚧 G-2/G-3/G-5 done; G-1/G-4 blocked on hosting decision                                              |
| [EPIC_03_student_mobile](../StudyBuddy_OnDemand/docs/epics/EPIC_03_student_mobile.md)                               | Epic 3 — Student Mobile App (Expo / React Native). ✅ Path B chosen 2026-04-14; not yet started (parked behind testing + hosting)                  |
| [EPIC_04_parent_portal](../StudyBuddy_OnDemand/docs/epics/EPIC_04_parent_portal.md)                                 | Epic 4 — Parent Portal. 💭 Your call                                                                                                               |
| [EPIC_05_district_admin](../StudyBuddy_OnDemand/docs/epics/EPIC_05_district_admin.md)                               | Epic 5 — District Admin. 💭 Your call                                                                                                              |
| [EPIC_06_platform_hardening](../StudyBuddy_OnDemand/docs/epics/EPIC_06_platform_hardening.md)                       | Epic 6 — Platform Hardening. 🚧 K-1/K-2/K-3/K-6 done; K-4/K-5 need staging                                                                         |
| [EPIC_07_self_serve_demo](../StudyBuddy_OnDemand/docs/epics/EPIC_07_self_serve_demo.md)                             | Epic 7 — Self-Serve Demo System. ✅ Complete (Option C guided tour, 15 tests)                                                                      |
| [EPIC_08_onboarding_completeness](../StudyBuddy_OnDemand/docs/epics/EPIC_08_onboarding_completeness.md)             | Epic 8 — Onboarding Completeness (address + measurement units). 🚧 H-8/H-9/H-10 shipped; address + units phases pending                            |
| [EPIC_09_accessibility_personalization](../StudyBuddy_OnDemand/docs/epics/EPIC_09_accessibility_personalization.md) | Epic 9 — Accessibility & Personalization. 🚧 Umbrella for GH issue #189 (3 axe rules disabled in persona e2e)                                      |
| [EPIC_10_curriculum_lifecycle](../StudyBuddy_OnDemand/docs/epics/EPIC_10_curriculum_lifecycle.md)                   | Epic 10 — Curriculum Lifecycle & Governance. 🚧 L-1–L-5 backend shipped; L-6 sweeper paused; L-7–L-10 pending                                      |
| [EPIC_11_content_formatting](../StudyBuddy_OnDemand/docs/epics/EPIC_11_content_formatting.md)                       | Epic 11 — Content Presentation & Formatting. 🚧 C-1–C-4, C-6, C-9 shipped; C-5 regen in flight; C-7/C-8 pending                                    |
| [EPIC_12_teacher_content_authoring](../StudyBuddy_OnDemand/docs/epics/EPIC_12_teacher_content_authoring.md)         | Epic 12 — Teacher Content Authoring. ✅ Go — Option B (fork model) adopted; ready to build TA-0                                                    |
| [EPIC_13_branding_refresh](../StudyBuddy_OnDemand/docs/epics/EPIC_13_branding_refresh.md)                           | Epic 13 — Branding Refresh: STEM → Education Enhancement. ✅ Complete 2026-04-21 (all five tickets across EN/FR/ES)                                |
| [EPIC_15_backup_restore](../StudyBuddy_OnDemand/docs/epics/EPIC_15_backup_restore.md)                               | Epic 15 — School Curriculum Backup & Restore. ✅ Go — spec locked; ready to build BR-1 through BR-6                                                |
| [EPIC_16_public_site_redesign](../StudyBuddy_OnDemand/docs/epics/EPIC_16_public_site_redesign.md)                   | Epic 16 — Public Site Redesign: School-First Marketing. 🔜 Ready to build — start 2026-05-03 (S-1 → S-5)                                           |
| [EPIC_17_corporate_ld_fork](../StudyBuddy_OnDemand/docs/epics/EPIC_17_corporate_ld_fork.md)                         | Epic 17 — Corporate L&D Fork. ⏸ Contested — advisor recommends Path A (validate first via `tenant_type` + design-partner pilot); user picks A/B/C |
| [EPIC_18_corporate_scenario_catalog](../StudyBuddy_OnDemand/docs/epics/EPIC_18_corporate_scenario_catalog.md)       | Epic 18 — Corporate Compliance Scenario Catalog. 🚧 2 scenarios live; 48 seed scenarios across 9 domains catalogued; gated on Epic 17              |

### 13. Market Research

| Doc                                                                                                        | Purpose                                                                              |
| ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| [competitive_landscape](../studybuddy-docs/market_research/competitive_landscape.md)                       | Competitive landscape analysis                                                       |
| [cost_structure](../studybuddy-docs/market_research/cost_structure.md)                                     | Cost-structure analysis                                                              |
| [api_subscription_costs](../studybuddy-docs/market_research/api_subscription_costs.md)                     | Anthropic/OpenAI/etc. API subscription cost analysis                                 |
| [authentication_flows](../studybuddy-docs/market_research/authentication_flows.md)                         | Auth-flow patterns research                                                          |
| [demo_feedback](../studybuddy-docs/market_research/demo_feedback.md)                                       | **Canonical** verbatim quotes + test cases from K-12 demo reviewers (see Overlap §4) |
| [going_public_infrastructure_plan](../studybuddy-docs/market_research/going_public_infrastructure_plan.md) | Infrastructure plan for going-public scale                                           |
| [FEEDBACK_TRACKER](../StudyBuddy_OnDemand/docs/feedback/FEEDBACK_TRACKER.md)                               | Running log of UX and product feedback from external reviewers — one section per session with grounded analysis and tracked action items |
| [STRATEGIC_FEEDBACK](../StudyBuddy_OnDemand/docs/feedback/STRATEGIC_FEEDBACK.md)                           | Strategic and market-direction feedback from reviewers — competitive positioning bets, partnership leads, product-direction signals |

### 14. Sales, Demo & Promo Material

| Doc                                                                                            | Purpose                                                                                                                                   |
| ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| [DEMO_WALKTHROUGH](../studybuddy-docs/docs/dev/DEMO_WALKTHROUGH.md)                            | Click-by-click demo script for live demos                                                                                                 |
| [DEMO_SCRIPT (promos)](../studybuddy-docs/docs/promos/DEMO_SCRIPT.md)                          | Sales-call demo script (audience-facing)                                                                                                  |
| [ProductDemo](../studybuddy-docs/docs/promos/ProductDemo.md)                                   | Product-demo presentation                                                                                                                 |
| [DEMO_FEEDBACK (promos)](../studybuddy-docs/docs/promos/DEMO_FEEDBACK.md)                      | Sales-team summary of K-12 demo feedback (Themes/Implications); canonical verbatim in `market_research/demo_feedback.md` (see Overlap §4) |
| [MARKETING_PLAN](../studybuddy-docs/docs/promos/MARKETING_PLAN.md)                             | Go-to-market plan                                                                                                                         |
| [SchoolDistrictDeppDive](../studybuddy-docs/docs/promos/SchoolDistrictDeppDive.md)             | School-district deep-dive deck                                                                                                            |
| [SeriesAGrowthStory](../studybuddy-docs/docs/promos/SeriesAGrowthStory.md)                     | Series-A growth narrative                                                                                                                 |
| [StudyBuddy_Product_Packaging](../studybuddy-docs/docs/promos/StudyBuddy_Product_Packaging.md) | Product-packaging slide deck                                                                                                              |
| [StudyBuddy_VC_Deck_Final](../studybuddy-docs/docs/promos/StudyBuddy_VC_Deck_Final.md)         | VC pitch deck (final)                                                                                                                     |
| [TechDeepDive](../studybuddy-docs/docs/promos/TechDeepDive.md)                                 | Technical deep-dive deck                                                                                                                  |
| [USER_STORY_PRODUCTION_GUIDE](../studybuddy-docs/docs/promos/USER_STORY_PRODUCTION_GUIDE.md)   | Production guide for user-story video content                                                                                             |
| [USER_STORY_STORYBOARD](../studybuddy-docs/docs/promos/USER_STORY_STORYBOARD.md)               | User-story storyboard                                                                                                                     |
| [ashish-larivee-meeting-prep](../studybuddy-docs/docs/promos/ashish-larivee-meeting-prep.md)   | Meeting-prep notes for Ashish Larivee                                                                                                     |
| [PROMO_CANONICAL_OVERVIEW (StudyBuddy)](../StudyBuddy_OnDemand/docs/PROMO_CANONICAL_OVERVIEW.md) | Canonical StudyBuddy overview for promo work — paste into Claude.ai to draft teacher emails, school admin one-pagers, investor blurbs, or demo invitations |
| [WHATSAPP_DEMO_INVITE](../StudyBuddy_OnDemand/docs/outreach/WHATSAPP_DEMO_INVITE.md)             | Reusable WhatsApp message template for inviting people to try the live demo, with WhatsApp formatting and seeding prerequisites |
| [PROMO_CANONICAL_OVERVIEW (mambakkam)](PROMO_CANONICAL_OVERVIEW.md)                              | Canonical mambakkam.net overview for promo and outreach work — paste into Claude.ai to draft diaspora emails, heritage posts, or community announcements |

### 15. Reference

| Doc                                                                | Purpose                                               |
| ------------------------------------------------------------------ | ----------------------------------------------------- |
| [GLOSSARY](../studybuddy-docs/GLOSSARY.md)                         | Term definitions across the StudyBuddy domain         |
| [CHEATSHEET](../studybuddy-docs/CHEATSHEET.md)                     | Quick-reference cheatsheet                            |
| [DEVELOPER_BRIEF](../studybuddy-docs/DEVELOPER_BRIEF.md)           | Developer onboarding brief                            |
| [AGENTS (studybuddy-docs)](../studybuddy-docs/AGENTS.md)           | Agent-design notes                                    |
| [AGENTS (web)](../StudyBuddy_OnDemand/web/AGENTS.md)               | Web-side agent notes                                  |
| [CHANGES (studybuddy-docs)](../studybuddy-docs/CHANGES.md)         | studybuddy-docs changelog                             |
| [CHANGES (StudyBuddy_OnDemand)](../StudyBuddy_OnDemand/CHANGES.md) | StudyBuddy_OnDemand changelog                         |
| [PROJECT_WISDOM](../StudyBuddy_OnDemand/docs/PROJECT_WISDOM.md)    | Cross-cutting lessons learned                         |
| [CLAUDE.md (root)](../StudyBuddy_OnDemand/CLAUDE.md)               | Claude Code root instructions for StudyBuddy_OnDemand |
| [CLAUDE.md (web)](../StudyBuddy_OnDemand/web/CLAUDE.md)            | Claude Code instructions for the web sub-tree         |
| [README (mambakkam-net)](README.md)                                | This repo's intro                                     |
| [README (studybuddy-docs)](../studybuddy-docs/README.md)           | studybuddy-docs intro                                 |
| [README (StudyBuddy_OnDemand)](../StudyBuddy_OnDemand/README.md)   | StudyBuddy_OnDemand intro                             |
| [README (web)](../StudyBuddy_OnDemand/web/README.md)               | Web sub-tree intro                                    |
| [RESUME](../StudyBuddy_OnDemand/docs/RESUME.md)                    | Git-tracked resumption checkpoint — records where work left off, what's in flight, and what to pick up next on any machine |

---

## Cross-repo overlaps (de-duplication candidates)

Docs that cover overlapping ground across repos. Worth periodically reviewing
whether to consolidate, cross-link more aggressively, or accept the split.

### Overlap §1 — Demo launch plan exists in TWO repos (resolved: rename-synced 2026-05-17)

- [`mambakkam-net/Plans/DEMO_LAUNCH_PLAN.md`](Plans/DEMO_LAUNCH_PLAN.md) — operator runbook for the mambakkam.net first-tenant launch
- [`StudyBuddy_OnDemand/docs/DEMO_LAUNCH_PLAN.md`](../StudyBuddy_OnDemand/docs/DEMO_LAUNCH_PLAN.md) — StudyBuddy second-tenant launch plan for the same event

Both reference the same May 17 cutover and reference each other in their
companion-docs sections. Kept as two files (one per tenant) by design so each
repo has a self-contained operator doc.

**Status:** Both swept consistent on 2026-05-17 (CX22→CX23, `studybuddy.app→usestudybuddy.com`).
**Residual risk:** Future edits in one may not propagate to the other. The
nightly drift check (`scripts/docs_index/check_drift.py`) only catches
filesystem drift, not content drift between these two. Worth a follow-up: a
content-diff alert when both files change in the same commit without matching
edits.

### Overlap §2 — Hosting/deployment docs across 8 files in 3 repos (resolved: scope-clarified 2026-05-17)

| File                                         | Repo                | What it owns                                                                   |
| -------------------------------------------- | ------------------- | ------------------------------------------------------------------------------ |
| `Plans/DEPLOYMENT_PLAN.md`                   | mambakkam-net       | mambakkam.net deployment + cost on the shared CX23                             |
| `docs/dev/DEMO_HOSTING_GUIDE.md`             | studybuddy-docs     | Shared CX23 demo-hosting architecture + demo-mode simplifications              |
| `docs/DEPLOYMENT.md`                         | studybuddy-docs     | Deployment-architecture diagrams (dev → CI → staging → prod, visual reference) |
| `PRODUCTION_DEPLOYMENT.md`                   | studybuddy-docs     | Step-by-step AWS production deployment procedure                               |
| `CLOUD_HOSTING.md`                           | studybuddy-docs     | Cloud-platform decision matrix (AWS/GCP/Azure) + what-to-buy                   |
| `COST_PLAN.md`                               | studybuddy-docs     | Revenue model + 3-tier cost projections + break-even                           |
| `market_research/deployment_environments.md` | studybuddy-docs     | Pointer index after 2026-05-08 split                                           |
| `docs/DEMO_HOSTING_READINESS.md`             | StudyBuddy_OnDemand | Demo-launch readiness checklist + status snapshot                              |

**Status:** Not actual content duplication — these are 8 docs with 8 distinct
ownership boundaries (architecture vs procedure vs cost vs readiness vs visual
diagrams). On 2026-05-17 each got a top-of-doc "Owns / Adjacent in this hosting
cluster" header making the boundary explicit + pointing to the most relevant
siblings + back to this index.
**Future consolidation candidate:** `docs/DEPLOYMENT.md` (Diagram 4) vs
`PRODUCTION_DEPLOYMENT.md` — the diagrams could fold into the procedure doc
if the audience overlap is high enough. Deferred until someone actually wants
to maintain a single deployment doc.

### Overlap §3 — Branding/tagline exists in two places

- [`StudyBuddy_OnDemand/docs/BRANDING_TAGLINE_OPTIONS.md`](../StudyBuddy_OnDemand/docs/BRANDING_TAGLINE_OPTIONS.md) — internal exploration
- [`studybuddy-docs/docs/promos/TaglineOptions.md`](../studybuddy-docs/docs/promos/TaglineOptions.md) — outside-audience presentation

Different audiences — likely a real split, not duplication. Just be aware.

### Overlap §4 — Demo-feedback in two places (resolved: cross-linked 2026-05-17)

- [`studybuddy-docs/market_research/demo_feedback.md`](../studybuddy-docs/market_research/demo_feedback.md) — **canonical** for verbatim quotes + test cases (`TC-SR-*`)
- [`studybuddy-docs/docs/promos/DEMO_FEEDBACK.md`](../studybuddy-docs/docs/promos/DEMO_FEEDBACK.md) — sales-team summary (Themes / Implications / Status framing)

**Status:** Both files have reciprocal cross-link headers as of 2026-05-17.
The split is deliberate (research vs sales audience). If verbatim quotes ever
diverge, `market_research/` wins.
**Future consolidation candidate:** If the sales-team framing turns out to
duplicate `Themes` content already in market_research, fold them.

### Overlap §5 — Architecture docs at 3 levels of granularity

- `studybuddy-docs/ARCHITECTURE.md` — top level
- `studybuddy-docs/BACKEND_ARCHITECTURE.md` — backend-specific
- `StudyBuddy_OnDemand/mobile/ARCHITECTURE.md` — mobile-specific

These are intentionally tiered. Not duplication; just be aware that ARCHITECTURE.md
in the root and `mobile/ARCHITECTURE.md` are about different things despite
sharing a name.

### Overlap §6 — Two CHANGES.md files

Each repo has its own changelog. **Not duplication**; just be sure to find the
right one. mambakkam-net doesn't have a `CHANGES.md` of its own — its changelog
lives at the bottom of each `Plans/*.md` file (per-doc Change Log table).

---

## What is NOT indexed

Deliberately excluded from this index — file there's a reason to add later, but
they're not "documentation" in the operator sense:

| Path                                                                                                             | Why excluded                                                   |
| ---------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `mambakkam-net/src/data/landmarks/*`, `people/*`, `work/*`                                                       | Site content (Astro collections), not operator docs            |
| `mambakkam-net/src/pages/privacy.md`, `terms.md`                                                                 | Public-facing legal pages                                      |
| `mambakkam-net/LICENSE.md`, `vendor/README.md`                                                                   | Legal / third-party                                            |
| `studybuddy-docs/.venv-decks/**`                                                                                 | Python venv contents                                           |
| `StudyBuddy_OnDemand/venv/**`                                                                                    | Python venv contents                                           |
| `StudyBuddy_OnDemand/sample_content/**`                                                                          | Curriculum lesson materials, not docs                          |
| `StudyBuddy_OnDemand/.claude/commands/*.md`                                                                      | Operator slash commands (look in `.claude/commands/` directly) |
| `StudyBuddy_OnDemand/.claude/worktrees/**`                                                                       | Per-worktree duplicates of repo files                          |
| `StudyBuddy_OnDemand/web/docs/PHASE_W*_{PRE,POST}.md`                                                            | Sprint-cycle artifacts (ephemeral)                             |
| `StudyBuddy_OnDemand/web/test-results/**`                                                                        | Test-run output                                                |
| `StudyBuddy_OnDemand/web/tests/e2e/README.md`, `backend/tests/eval/README.md`, `backend/.pytest_cache/README.md` | Test-suite internals                                           |
| `StudyBuddy_OnDemand/TRASH-FILES.md`                                                                             | Deletion plan (transient)                                      |
| `StudyBuddy_OnDemand/ux_test_data/UX_TESTING_GUIDE.md`                                                           | Test-data subdirectory                                         |
| `**/node_modules/**`                                                                                             | Dependency trees                                               |

---

## Maintenance

**Right now (v1):** Hand-curated. Adding a new doc means appending a row to the
correct topic table here.

**Nightly drift check (live since 2026-05-17):**
[`scripts/docs_index/check_drift.py`](scripts/docs_index/check_drift.py) runs
via local cron and writes `DRIFT_REPORT.md` (gitignored) to the working tree
whenever the filesystem and this index diverge. See
[`scripts/docs_index/README.md`](scripts/docs_index/README.md) for usage,
cron setup, and how to handle each drift type.

**Future v2 — auto-regen:** A `topics.yaml` config + `build_index.py` would
let the script rebuild topic tables automatically (path patterns → topics,
with manual purpose overrides). Deferred because the hand-written purposes
are valuable and overwriting them risks accuracy. Roadmap in
`scripts/docs_index/README.md`.

**Future v3 — conflate with `doc_audit`:** The dormant
[`StudyBuddy_OnDemand/scripts/doc_audit/`](../StudyBuddy_OnDemand/scripts/doc_audit/)
toolkit (link integrity, test counts, migrations) could share the same nightly
cron. Detail in the same README.

---

## Change Log

| Date       | Version | Change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ---------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-05-17 | 1.0     | Initial hand-curated index. 14 topic tables + 6 cross-repo overlap warnings + exclusion list. Built after the CX22→CX23 + cost-table sweep across 9 docs revealed how scattered hosting docs are across the 3 repos.                                                                                                                                                                                                                                                                                                                                  |
| 2026-05-17 | 1.1     | Overlap cleanup pass: (§1) CX22→CX23 + studybuddy.app→usestudybuddy.com sweep applied to `StudyBuddy_OnDemand/docs/DEMO_LAUNCH_PLAN.md` so both launch-plan files are consistent; (§2) added "Owns / Adjacent in this hosting cluster" headers to 7 hosting docs across all 3 repos so each doc's scope is explicit at first read; (§4) reciprocal cross-link headers added to the two `DEMO_FEEDBACK` files marking `market_research/demo_feedback.md` as canonical for verbatim quotes. §3/§5/§6 left as-is (intentional splits, not duplications). |
| 2026-05-18 | 1.2     | Cleared the 18 untracked-on-disk entries flagged by the 2026-05-17 drift run: added all 17 `docs/epics/EPIC_NN_*.md` files to §12 (one row per epic mirroring the `epics/INDEX.md` status board, EPIC_14 number unused) + added `web/docs/TEST_CASES.md` to §9. Indexed total: 111 → 129; drift report should now show 0 untracked.                                                                                                                                                                                                                   |
| 2026-05-18 | 1.3     | Added `Plans/HOSTING_ACTIVITY_LOG.md` to §4 — new chronological log of operator actions on live infra (provisioning, deploys, incidents). First entry covers the 2026-05-18 cold-start launch including the §A Origin Cert mismatch and §B Universal SSL disable incidents. Will be appended to over time.                                                                                                                                                                                                                                            |
| 2026-06-10 | 1.4     | Nightly drift sweep: +16 rows (§4 +1, §6 +6, §9 +1, §10 +1, §11 +1, §13 +2, §14 +3, §15 +1), -0 rows. New docs: ADR-004/005/006, DESIGN/SPEC curriculum_mgmt, SCHOOL_USER_MANAGEMENT, SCHOOL_ONBOARDING_TEMPLATE, CURRICULUM_ONBOARDING_FLOW, VISUAL_VALIDATION_GUIDE, RESPONSIVE_TARGET, FEEDBACK_TRACKER, STRATEGIC_FEEDBACK, PROMO_CANONICAL_OVERVIEW (×2), WHATSAPP_DEMO_INVITE, RESUME. |
