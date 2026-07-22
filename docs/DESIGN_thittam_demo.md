# Thittam static demo on mambakkam.net (`/demos/thittam`)

**Status:** design approved 2026-07-22, not yet implemented
**Repos touched:** `wegofwd2020-hub/thittam` (fixtures + demo build) · `wegofwd2020-hub/mambakkam-net` (hosting)

Host a public, click-through Thittam demo at `https://mambakkam.net/demos/thittam/`
as **static files only** — no backend, no new VPS process, no new compose stack.

---

## Why this is not the Mentible pattern

The Mentible demo (`docs/DEMO_mentible_lite.md`) is a static frontend plus one
live FastAPI container proxied at a same-origin path:

```
static export → /demos/mentible/     +     /mentible-api/ → 127.0.0.1:8092 (FastAPI + redis)
```

Thittam cannot follow that shape. It is 10 Go microservices (iam,
project-management, budget-planning, expense-tracking, general-ledger,
inventory-management, notifications, document, reporting-analytics, billing)
plus a Next.js web tier, Postgres 16 (tenant-per-schema), NATS, Redis and MinIO.

Two hard blockers to a live demo:

1. **No container images exist.** `find thittam -name 'Dockerfile*'` returns
   nothing. `infra/k8s/services/*.yaml` reference
   `ghcr.io/wegofwd2020-hub/thittam/<svc>:latest` images that no pipeline builds.
   Local dev runs the services as bare Go processes under tmuxinator
   (`make run-all`); `infra/local/docker-compose.yml` containerises only the
   backing infra (postgres, redis, nats, minio).
2. **The VPS has no room.** The shared Hetzner CX23 already carries the astrowind
   container, the StudyBuddy demo stack, the Mentible api + redis, and the
   Prometheus/Grafana monitoring stack. A trimmed Thittam stack is another
   ~3–4 GB.

So the demo is **static export + recorded fixtures**. Closing the image gap is
worthwhile independently (it also blocks the documented k8s path), but it is out
of scope here.

---

## Architecture

No new process, no new port, no `/thittam-api/` route. Purely additive static
files served by the container that already serves `public/*`.

```
thittam/web  ──NEXT_PUBLIC_DEMO=1 next build──►  out/
                    │  copy
                    ▼
mambakkam-net/public/demos/thittam/   ──astro build──►  dist/demos/thittam/
                    │
   Cloudflare → host nginx :443 → 127.0.0.1:8081 (existing astrowind container)
```

### Why static export is viable

Audited `thittam/web` on 2026-07-22:

| Check | Result |
|---|---|
| `next.config.ts` | empty — nothing conflicts with `output: 'export'` |
| middleware | none |
| server actions (`"use server"`) | none |
| route handlers (`route.ts`) | none |
| pages | 29, **all 29 are `"use client"`** |
| data access | funnels through `src/lib/api/client.ts` and `src/lib/api/auth.ts` |
| dynamic routes | 7 `[id]` segments; 2 are in scope |

Every page being a client component is what makes this cheap: there is no
server-render path to replace, only a transport to stub.

---

## Scope — the guided slice

Five pages telling one coherent XYZ_CBA (movie production, INR) story:

1. `/login` — demo credentials, pre-filled
2. `/productions` — landing page after login
3. `/productions/[id]`
4. `/budgets`
5. `/budgets/[id]`

Two `[id]` detail views — which is where the two route wrappers below come from.

### Why the slice is this small: only 3 of 10 services expose REST

This is the constraint that sets the scope, so it is worth stating plainly.
Thittam's browser client can only reach services that register a grpc-gateway.
Measured 2026-07-22 with
`grep -rl 'RegisterHandlerFromEndpoint\|runtime.NewServeMux' cmd/*/`:

| Service | grpc-gateway | Port |
|---|---|---|
| `iam` | ✅ | :9086 |
| `project-management` | ✅ | :9080 |
| `budget-planning` | ✅ | :9081 |
| `expense-tracking` | ❌ gRPC only | — |
| `inventory-management` | ❌ gRPC only | — |
| `reporting-analytics` | ❌ gRPC only | — |
| `billing`, `document`, `general-ledger`, `notifications` | ❌ gRPC only | — |

`scripts/dev-start.sh` confirms it — "gateway ready" is logged on exactly :9080,
:9081 and :9086.

So `resolveBaseUrl` (`web/src/lib/api/client.ts:33`) having only three branches
is not an oversight; it is the entire REST surface. Every other path falls
through to `env.iamApiUrl` and 404s there:

| Page | Calls | Reachable |
|---|---|---|
| `/login` | `/api/v1/auth/login` → :9086 | ✅ |
| `/productions[/id]` | `/api/v1/productions` → :9080 | ✅ |
| `/budgets[/id]` | `/api/v1/budgets` → :9081 | ✅ |
| `/expenses[/id]` | `/api/v1/expenses` → falls to :9086 | ❌ |
| `/inventory[/id]` | `/api/v1/assets` → falls to :9086 | ❌ |
| `/` dashboard | `/v1/reports/dashboard/*` → falls to :9086 | ❌ |

There is nothing to record from for the unreachable pages, and hand-authoring
their fixtures is ruled out — a screen whose numbers no code produced is worse
than an absent screen. Hence five pages.

**The dashboard is not the landing page.** `/login` redirects to `/productions`
in demo mode. `src/lib/api/dashboard.ts:134` drives `/` from six
reporting-backed endpoints under `BASE = "/v1/reports/dashboard"`, none of which
resolve. (Note that path is `/v1/...`, not `/api/v1/...` — a second reason it
would never route correctly.)

### Separate finding, not a demo problem

Thittam's web tier is ahead of its REST surface by seven services: `/expenses`,
`/inventory`, `/reports`, `/notifications`, `/documents` and `/billing` call
endpoints that no running process serves. Those pages appear non-functional in
the product, not merely in a demo — consistent with the critique's note that
Playwright covers only a budgets journey. Worth filing against
`project-critique/thittam-critique.md` independently of this work.

Routes outside the slice are reachable only if their fixtures exist; otherwise
navigation entries to them are hidden in demo mode. A visibly broken page is
worse than an absent one.

`seeds/demo/xyz-cba/` supplies the data — 10 SQL files covering tenant, users,
productions, budgets, expenses, inventory, ledger, IAM roles, document folders
and notification templates. The demo tells a story that already exists; nothing
is invented.

---

## Components

| # | Location | Purpose |
|---|---|---|
| 1 | `thittam/scripts/capture-demo-fixtures.sh` | Hits each slice endpoint against a locally seeded stack, writes real JSON. Any non-2xx aborts the script. |
| 2 | `thittam/web/src/demo/fixtures/*.json` | Recorded XYZ_CBA responses. Committed. |
| 3 | `thittam/web/src/demo/transport.ts` | Lookup keyed `"GET /api/v1/productions"`. Unknown key throws an explicit `ApiError`. |
| 4 | `thittam/web/src/demo/manifest.ts` | Path→fixture map, plus the `[id]` values feeding `generateStaticParams`. |
| 5 | `client.ts` + `auth.ts` demo branches | ~5 lines at the top of each transport function, guarded by `env.demoMode`. |
| 6 | 2 route wrappers | `productions/[id]`, `budgets/[id]` |
| 7 | `thittam/web/next.config.ts` | Env-gated export config |
| 8 | `mambakkam-net/nginx/nginx.conf` | Two location blocks (below) |
| 9 | `mambakkam-net` work page | "Try the demo" link on `/work/thittam` |

### The two transport seams

`ApiClient.request()` (`web/src/lib/api/client.ts:120`) is the single private
method every verb funnels through — `method + path + body → JSON`. All 12
`src/lib/api/*.ts` modules, every React Query hook, and all 29 pages stay
untouched.

**`src/lib/api/auth.ts:6` does not use `ApiClient`.** It defines its own
`authRequest()` with a raw `fetch` against `env.platformApiUrl`. It needs the
same demo branch. Stubbing only `client.ts` leaves login hitting the network.

### Route wrappers

`generateStaticParams()` cannot be exported from a `"use client"` file. For each
of the 2 in-scope `[id]` routes, `page.tsx` becomes a thin server component that
exports `generateStaticParams()` (ids read from the fixture manifest) and renders
the existing client component, moved unchanged to `view.tsx`. Mechanical.

### Next config

Env-gated so the normal build is unaffected:

```ts
const demo = process.env.NEXT_PUBLIC_DEMO === "1";

const nextConfig: NextConfig = demo
  ? {
      output: "export",
      basePath: "/demos/thittam",
      trailingSlash: true,       // matches nginx try_files $uri $uri/
      images: { unoptimized: true },
    }
  : {};
```

---

## Auth in demo mode

The existing flow works statically as-is. `AuthProvider`
(`web/src/lib/auth/context.tsx:50`) keeps `thittam_access_token`,
`thittam_refresh_token` and `thittam_tenant_id` in `localStorage` — no cookies,
no server session. `ProtectedRoute` redirects via client-side `router.replace`.

- Demo `login()` accepts the seeded XYZ_CBA credentials (`email + demo1234`) and
  returns a canned `TokenPair`. Any other input returns the real
  `INVALID_CREDENTIALS` `ApiError`, so the failure path stays honest.
- The login page shows the demo credentials and pre-fills them.
- **The SSO button must be hidden.** `web/src/app/(auth)/login/page.tsx:55`
  navigates to `${NEXT_PUBLIC_PLATFORM_API_URL}/api/v1/auth/sso/authorize`. Left
  enabled, it sends visitors to a dead host. Gate on `!env.demoMode`.

### The hostname-fallback trap

`web/src/env.ts:17` derives service URLs from `window.location.hostname` when the
`NEXT_PUBLIC_*` vars are unset. In a demo build that resolves to
`https://mambakkam.net:9086` — requests that hang, then fail slowly.

Two defences:

1. The demo branch sits at the **top** of both transport functions, before any
   URL is resolved.
2. The demo build sets every `NEXT_PUBLIC_*_URL` to a sentinel
   (`http://demo.invalid`) so a leak fails instantly and loudly rather than
   hanging.

---

## Write mutations

`POST` / `PATCH` / `DELETE` return a canned "not available in this demo"
`ApiError`, rendered by the existing error UI. No fake optimistic writes — a demo
that appears to save and then forgets is worse than one that says it is
read-only.

---

## Nginx

Mirrors the Mentible blocks in `nginx/nginx.conf`. Next emits content-hashed
assets under `_next/`:

```nginx
# Content-hashed Next assets: resolve to a real file or a real 404.
# NEVER fall back to index.html — serving HTML under a .js/.woff2 URL is what
# poisoned the Cloudflare cache during the Mentible deploy and hung the app on
# a blank shell.
location ^~ /demos/thittam/_next/ {
    try_files $uri =404;
    add_header Cache-Control "public, max-age=31536000, immutable" always;
}

# Genuine SPA deep links fall back to the app's own index.html. Keep the HTML
# uncached so a new deploy is picked up at once.
location /demos/thittam/ {
    try_files $uri $uri/ /demos/thittam/index.html;
    add_header Cache-Control "no-cache" always;
}
```

This is the **app-level** nginx (`nginx/nginx.conf`, inside the astrowind
container), not the host vhost. No change to `infra/nginx/mambakkam.net.conf` is
needed — there is no backend to proxy.

---

## Publish flow

Manual, matching the Mentible and atri-sangam precedent.

```bash
# thittam/ — local stack up and seeded
make dev-start && make seed
./scripts/capture-demo-fixtures.sh          # → web/src/demo/fixtures/
cd web && npm run build:demo                # → out/ (new script, see below)

# mambakkam-net/
rm -rf public/demos/thittam
cp -r ../thittam/web/out public/demos/thittam
npm run build && npm run check
git add public/demos/thittam && git commit

# operator, on the VPS
sudo git -C /opt/mambakkam pull
sudo docker compose up -d --build
```

`build:demo` does not exist yet — `thittam/web/package.json` currently has only
`dev`, `build`, `start`, `lint` and the `test:e2e:*` scripts. Add:

```json
"build:demo": "NEXT_PUBLIC_DEMO=1 NEXT_PUBLIC_IAM_URL=http://demo.invalid NEXT_PUBLIC_PROJECT_URL=http://demo.invalid NEXT_PUBLIC_BUDGET_URL=http://demo.invalid NEXT_PUBLIC_PLATFORM_API_URL=http://demo.invalid next build"
```

Housekeeping in `mambakkam-net`, both already required by the Mentible export:
add `public/demos/thittam/` to `.prettierignore` and to the `eslint.config.js`
ignores, or the minified bundle fails the CI `check` job.

**`DOCS_INDEX.md`** is hand-curated (v1, no nightly workflow yet);
`scripts/docs_index/check_drift.py` reports a doc on disk that is missing from
it. This design doc is already indexed under §6 Architecture. Add the runbook
there too when it is written. Note the index is currently 35 docs behind
overall — the drift check is advisory, not a CI gate.

---

## Testing

Three gates, cheapest first:

1. **Capture-time.** Any non-2xx during fixture capture fails the script. Drift
   between the demo and the real API surfaces here, before anything is built.
2. **Build-time.** `next build` with `output: 'export'` fails hard on any
   un-exportable route. This is the check that the `generateStaticParams`
   wrappers are correct.
3. **Pre-deploy.** Serve `out/` locally under `/demos/thittam/` and walk the
   slice with the network panel open. **Zero outbound requests is the pass
   condition** — one leaked call means a seam was missed.

Then add a `/demos/thittam/` 200 assertion to
`mambakkam-net/scripts/launch/smoke.sh`.

---

## Accepted risks

- **Public client bundle.** `thittam` is a private repo; a static export
  publishes its minified front-end source, route structure and API contract
  shapes. No credentials are exposed, and the atri-sangam demo set the precedent,
  but Thittam is a much larger surface. Accepted knowingly on 2026-07-22.
- **Fixture rot.** Committed fixtures are a snapshot. Thittam's last substantive
  commit was 2026-05-13 so the surface is stable today, but the mitigation is the
  re-runnable capture script, not vigilance.
- **Thin pages.** `seeds/demo/xyz-cba/003_productions.sql` and
  `004_budgets.sql` back the whole slice directly. Still review the captured
  fixtures before committing them — an endpoint can return `200` with an empty
  list, which the capture script will not catch.
- **A small demo.** Five pages is a modest showing for a system this size, and
  it deliberately shows the two services that are furthest along rather than the
  breadth of the architecture. The honest alternative — building three
  grpc-gateways first — was considered and deferred.

---

## Out of scope

- Dockerfiles for the 10 services and a published image pipeline (needed for any
  live demo, and for the documented k8s path — worth doing, separately).
- Any live backend, VPS upsize, or second host.
- The multi-tenant switching story (XYZ Construction) — one tenant only.
- grpc-gateway registration for `expense-tracking`, `inventory-management` and
  `reporting-analytics`. Building these would unlock `/expenses`, `/inventory`
  and the dashboard for both the demo and the product, and is the natural
  follow-up — but it is Go service work, not demo work.
