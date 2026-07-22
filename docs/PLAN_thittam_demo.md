# Thittam Static Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish a five-page, click-through Thittam demo at `https://mambakkam.net/demos/thittam/` as static files, with no backend and no new VPS process.

**Architecture:** Add a demo mode to `thittam/web` that swaps its two HTTP transport functions for a lookup against fixtures recorded from a locally seeded XYZ_CBA tenant. Build the app with `output: 'export'` under `basePath: /demos/thittam`, then commit the resulting `out/` into `mambakkam-net/public/demos/thittam/`, which the existing astrowind container already serves.

**Tech Stack:** Next.js 16 (App Router, all-client pages), React 19, TypeScript 5, Vitest (added by Task 1), Tailwind 4, Astro 5 (mambakkam-net), nginx, bash.

**Design doc:** [`DESIGN_thittam_demo.md`](DESIGN_thittam_demo.md) — read it before Task 1.

## Global Constraints

- **Two repos.** Tasks 1–7 are in `thittam/`; Task 8 is in `mambakkam-net/`. Never commit across both in one commit.
- **The demo is read-only.** `POST`/`PATCH`/`DELETE` must fail with a clear "not available in this demo" error. Never fake a successful write.
- **Fixtures are recorded, never hand-authored.** If an endpoint cannot be captured, the page leaves the slice. This rule is why the slice is five pages.
- **The slice is exactly:** `/login`, `/productions`, `/productions/[id]`, `/budgets`, `/budgets/[id]`.
- **Demo mode is compile-time dead code in normal builds.** Every demo branch is guarded by `env.demoMode`, which reads `process.env.NEXT_PUBLIC_DEMO === "1"`.
- **Zero outbound requests is the acceptance bar.** A demo build that reaches the network is a failed build, not a cosmetic issue.
- **Demo tenant:** XYZ_CBA. **Demo login:** `rajesh.kumar@xyzcba.com` / `demo1234` (owner / super_admin, per `seeds/demo/xyz-cba/007_iam_roles.sql`).
- **Only three services expose REST:** `iam` :9086, `project-management` :9080, `budget-planning` :9081. Do not add slice pages that call anything else.

---

## File Structure

**Created in `thittam/`:**

| Path | Responsibility |
|---|---|
| `web/vitest.config.mts` | Test runner config with the `@/` path alias (`.mts` — see Task 1) |
| `web/src/demo/flag.ts` | The single `isDemo` predicate — nothing else imports `process.env.NEXT_PUBLIC_DEMO` |
| `web/src/demo/keys.ts` | Request-key construction and normalisation. Pure, no I/O. |
| `web/src/demo/keys.test.ts` | Tests for the above |
| `web/src/demo/transport.ts` | Fixture lookup: key → recorded body, or a thrown `ApiError` |
| `web/src/demo/transport.test.ts` | Tests for the above |
| `web/src/demo/fixtures.generated.json` | Recorded responses. Written by the capture script, committed. |
| `web/src/demo/params.ts` | Derives `[id]` values from the fixture file for `generateStaticParams` |
| `web/src/demo/nav.ts` | The slice's allowed routes; filters the sidebar in demo mode |
| `web/src/app/(dashboard)/productions/[id]/view.tsx` | The existing client component, moved |
| `web/src/app/(dashboard)/budgets/[id]/view.tsx` | The existing client component, moved |
| `scripts/capture-demo-fixtures.sh` | Records fixtures against a live local stack |

**Modified in `thittam/`:**

| Path | Change |
|---|---|
| `web/package.json` | Add `vitest`, `test` and `build:demo` scripts |
| `web/src/env.ts` | Add the `demoMode` getter |
| `web/src/lib/api/client.ts` | Demo branch at the top of `request()` |
| `web/src/lib/api/auth.ts` | Demo branch at the top of `authRequest()` |
| `web/src/app/(auth)/login/page.tsx` | Demo redirect target, hidden SSO button, credentials hint |
| `web/src/components/layout/sidebar.tsx` | Filter nav through `demo/nav.ts` |
| `web/src/app/(dashboard)/productions/[id]/page.tsx` | Becomes a server wrapper |
| `web/src/app/(dashboard)/budgets/[id]/page.tsx` | Becomes a server wrapper |
| `web/next.config.ts` | Env-gated export config |

**Modified in `mambakkam-net/`:**

| Path | Change |
|---|---|
| `public/demos/thittam/` | The exported build (new, committed) |
| `nginx/nginx.conf` | Two location blocks |
| `.prettierignore`, `eslint.config.js` | Ignore the bundled export |
| `scripts/launch/smoke.sh` | Assert `/demos/thittam/` returns 200 |
| `src/data/work/thittam.md` | "Try the demo" link |

**Fixture file shape.** One JSON object, one file, so the import is static and the export build has nothing to resolve at runtime:

```json
{
  "_meta": {
    "capturedAt": "2026-07-22T10:00:00Z",
    "tenant": "xyz-cba",
    "demoEmail": "rajesh.kumar@xyzcba.com"
  },
  "responses": {
    "POST /api/v1/auth/login": { "access_token": "...", "refresh_token": "..." },
    "GET /api/v1/productions": { "productions": [] },
    "GET /api/v1/productions/<uuid>": {}
  }
}
```

---

### Task 1: Demo flag and test harness

`thittam/web` has no unit test runner today — only Playwright e2e. The demo transport is pure logic and deserves real tests, so this task adds Vitest and the one flag every later task depends on.

**Files:**
- Create: `web/vitest.config.mts`
- Create: `web/src/demo/flag.ts`
- Create: `web/src/demo/flag.test.ts`
- Modify: `web/package.json`
- Modify: `web/src/env.ts`

**Interfaces:**
- Consumes: nothing
- Produces: `isDemo(): boolean` from `@/demo/flag`; `env.demoMode: boolean` from `@/env`

- [ ] **Step 1: Add Vitest**

```bash
cd web
npm install -D vitest@^2 @vitejs/plugin-react@^4 vite-tsconfig-paths@^5
```

- [ ] **Step 2: Create the Vitest config**

`web/vitest.config.mts` — note the `.mts` extension. `web/package.json` has no `"type": "module"`, so a `.ts` config is bundled as CommonJS, and `vite-tsconfig-paths@5` is ESM-only with no CJS build — the config fails to load before any test runs. `.mts` forces Vite to load it as ESM. Do **not** add `"type": "module"` to `package.json` instead: it would break `web/playwright.config.ts`, which uses CommonJS `__dirname`.

```ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import tsconfigPaths from "vite-tsconfig-paths";

export default defineConfig({
  plugins: [react(), tsconfigPaths()],
  test: {
    environment: "node",
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
  },
});
```

`vite-tsconfig-paths` is what makes the `@/` alias resolve in tests without duplicating the mapping from `tsconfig.json`.

- [ ] **Step 3: Add the test script**

In `web/package.json`, add to `"scripts"`:

```json
"test": "vitest run",
"test:watch": "vitest"
```

- [ ] **Step 4: Write the failing test**

`web/src/demo/flag.test.ts`:

```ts
import { describe, it, expect, afterEach } from "vitest";
import { isDemo } from "./flag";

const original = process.env.NEXT_PUBLIC_DEMO;

afterEach(() => {
  process.env.NEXT_PUBLIC_DEMO = original;
});

describe("isDemo", () => {
  it("is true when NEXT_PUBLIC_DEMO is exactly '1'", () => {
    process.env.NEXT_PUBLIC_DEMO = "1";
    expect(isDemo()).toBe(true);
  });

  it("is false when unset", () => {
    delete process.env.NEXT_PUBLIC_DEMO;
    expect(isDemo()).toBe(false);
  });

  it("is false for other truthy-looking values", () => {
    process.env.NEXT_PUBLIC_DEMO = "true";
    expect(isDemo()).toBe(false);
  });
});
```

The third case matters: `"true"` returning `false` is deliberate. One spelling only, so a typo in a build command fails loudly rather than half-enabling demo mode.

- [ ] **Step 5: Run it and watch it fail**

Run: `cd web && npm test`
Expected: FAIL — `Failed to resolve import "./flag"`

- [ ] **Step 6: Write the implementation**

`web/src/demo/flag.ts`:

```ts
/**
 * Demo mode: the app serves recorded fixtures instead of calling services.
 *
 * Exactly "1" — no other spelling is accepted, so a typo in a build command
 * fails visibly rather than half-enabling the demo.
 *
 * Next inlines NEXT_PUBLIC_* at build time, so in a normal build this folds to
 * `false` and every `if (isDemo())` branch is eliminated from the bundle.
 */
export function isDemo(): boolean {
  return process.env.NEXT_PUBLIC_DEMO === "1";
}
```

- [ ] **Step 7: Run the tests and watch them pass**

Run: `cd web && npm test`
Expected: PASS — 3 passed

- [ ] **Step 8: Expose it on `env`**

In `web/src/env.ts`, add to the `env` object, after the `apiUrl` getter:

```ts
  /** True when this build serves recorded fixtures instead of live services. */
  get demoMode(): boolean {
    return isDemo();
  },
```

and at the top of the file:

```ts
import { isDemo } from "@/demo/flag";
```

- [ ] **Step 9: Verify nothing broke**

Run: `cd web && npx tsc --noEmit && npm run lint`
Expected: no errors

- [ ] **Step 10: Commit**

```bash
git add web/package.json web/package-lock.json web/vitest.config.mts web/src/demo/flag.ts web/src/demo/flag.test.ts web/src/env.ts
git commit -m "feat(web): add demo-mode flag and a Vitest harness"
```

---

### Task 2: Request keys

Fixtures are looked up by a string key built from the request. Query strings are the wrinkle: `listProductions` appends `?status=active` via `qs()` (`src/lib/api/productions.ts:79`), and a capture will not have every filter combination. The rule is to try the exact key first, then fall back to the path without its query.

**Files:**
- Create: `web/src/demo/keys.ts`
- Create: `web/src/demo/keys.test.ts`

**Interfaces:**
- Consumes: nothing
- Produces: `requestKey(method: string, path: string): string` and `lookupKeys(method: string, path: string): string[]` from `@/demo/keys`

- [ ] **Step 1: Write the failing tests**

`web/src/demo/keys.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { requestKey, lookupKeys } from "./keys";

describe("requestKey", () => {
  it("joins an upper-cased method and the path", () => {
    expect(requestKey("get", "/api/v1/productions")).toBe(
      "GET /api/v1/productions",
    );
  });

  it("keeps the query string", () => {
    expect(requestKey("GET", "/api/v1/budgets?status=draft")).toBe(
      "GET /api/v1/budgets?status=draft",
    );
  });
});

describe("lookupKeys", () => {
  it("returns one key when there is no query string", () => {
    expect(lookupKeys("GET", "/api/v1/productions")).toEqual([
      "GET /api/v1/productions",
    ]);
  });

  it("returns the exact key first, then the query-stripped key", () => {
    expect(lookupKeys("GET", "/api/v1/budgets?status=draft")).toEqual([
      "GET /api/v1/budgets?status=draft",
      "GET /api/v1/budgets",
    ]);
  });

  it("does not emit a duplicate when the query string is empty", () => {
    expect(lookupKeys("GET", "/api/v1/budgets?")).toEqual([
      "GET /api/v1/budgets",
    ]);
  });
});
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd web && npm test`
Expected: FAIL — `Failed to resolve import "./keys"`

- [ ] **Step 3: Write the implementation**

`web/src/demo/keys.ts`:

```ts
/**
 * Fixture keys are "<METHOD> <path>", where path is exactly what the API
 * modules build — including any query string from qs().
 */
export function requestKey(method: string, path: string): string {
  return `${method.toUpperCase()} ${path}`;
}

/**
 * Keys to try, most specific first.
 *
 * A capture cannot cover every filter combination, so a request carrying a
 * query string falls back to the unfiltered recording. A bare "?" with nothing
 * after it is not a real query — it collapses to just the unfiltered key.
 */
export function lookupKeys(method: string, path: string): string[] {
  const queryStart = path.indexOf("?");
  if (queryStart === -1) return [requestKey(method, path)];

  const bare = requestKey(method, path.slice(0, queryStart));

  // Nothing after the "?" → no real query, only the bare key.
  if (queryStart === path.length - 1) return [bare];

  return [requestKey(method, path), bare];
}
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd web && npm test`
Expected: PASS — 8 passed (3 from Task 1, 5 here)

- [ ] **Step 5: Commit**

```bash
git add web/src/demo/keys.ts web/src/demo/keys.test.ts
git commit -m "feat(web): add demo fixture request-key helpers"
```

---

### Task 3: Demo transport

**Files:**
- Create: `web/src/demo/transport.ts`
- Create: `web/src/demo/transport.test.ts`
- Create: `web/src/demo/fixtures.generated.json` (placeholder — Task 4 overwrites it)

**Interfaces:**
- Consumes: `lookupKeys` from `@/demo/keys`; `ApiError` from `@/lib/api/client`
- Produces: `demoRespond<T>(method: string, path: string): T` and `demoMeta(): DemoMeta` from `@/demo/transport`, where `DemoMeta = { capturedAt: string; tenant: string; demoEmail: string }`

**Note on the import direction:** `transport.ts` imports `ApiError` from `client.ts`, and Task 5 has `client.ts` import `demoRespond` from `transport.ts`. That is a cycle. Avoid it by having `transport.ts` import `ApiError` from a leaf module. `ApiError` is currently declared in `client.ts:6`; Step 1 moves it to `web/src/lib/api/error.ts` and re-exports it from `client.ts` so no existing import breaks.

- [ ] **Step 1: Extract `ApiError` to a leaf module**

Create `web/src/lib/api/error.ts` by moving the class verbatim from `client.ts:6-22`:

```ts
import type { ApiErrorBody } from "./types";

export class ApiError extends Error {
  public readonly code: string;
  public readonly details: Record<string, unknown> | undefined;
  public readonly requestId: string;
  public readonly status: number;

  constructor(status: number, body: ApiErrorBody) {
    super(body.message);
    this.name = "ApiError";
    this.code = body.code;
    this.details = body.details;
    this.requestId = body.request_id;
    this.status = status;
  }
}
```

In `client.ts`, delete the class and replace it with a re-export so every existing `import { ApiError } from "@/lib/api/client"` keeps working:

```ts
export { ApiError } from "./error";
import { ApiError } from "./error";
```

- [ ] **Step 2: Verify the extraction changed nothing**

Run: `cd web && npx tsc --noEmit && npm run lint`
Expected: no errors

- [ ] **Step 3: Commit the extraction on its own**

```bash
git add web/src/lib/api/error.ts web/src/lib/api/client.ts
git commit -m "refactor(web): move ApiError to a leaf module"
```

- [ ] **Step 4: Add a placeholder fixture file**

`web/src/demo/fixtures.generated.json` — Task 4 overwrites this with a real capture. It exists now so the import type-checks:

```json
{
  "_meta": {
    "capturedAt": "1970-01-01T00:00:00Z",
    "tenant": "xyz-cba",
    "demoEmail": "rajesh.kumar@xyzcba.com"
  },
  "responses": {}
}
```

- [ ] **Step 5: Write the failing tests**

`web/src/demo/transport.test.ts`:

```ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { ApiError } from "@/lib/api/error";

const fixtures = {
  _meta: {
    capturedAt: "2026-07-22T10:00:00Z",
    tenant: "xyz-cba",
    demoEmail: "rajesh.kumar@xyzcba.com",
  },
  responses: {
    "GET /api/v1/productions": { productions: [{ id: "p1" }] },
    "POST /api/v1/auth/login": { access_token: "demo", refresh_token: "demo" },
  },
};

vi.mock("./fixtures.generated.json", () => ({ default: fixtures }));

let demoRespond: typeof import("./transport").demoRespond;
let demoMeta: typeof import("./transport").demoMeta;

beforeEach(async () => {
  const mod = await import("./transport");
  demoRespond = mod.demoRespond;
  demoMeta = mod.demoMeta;
});

describe("demoRespond", () => {
  it("returns the recorded body for a known request", () => {
    expect(demoRespond("GET", "/api/v1/productions")).toEqual({
      productions: [{ id: "p1" }],
    });
  });

  it("falls back to the unfiltered recording when a query string misses", () => {
    expect(demoRespond("GET", "/api/v1/productions?status=active")).toEqual({
      productions: [{ id: "p1" }],
    });
  });

  it("returns a deep copy so callers cannot mutate the fixtures", () => {
    const first = demoRespond<{ productions: { id: string }[] }>(
      "GET",
      "/api/v1/productions",
    );
    first.productions[0].id = "mutated";
    const second = demoRespond<{ productions: { id: string }[] }>(
      "GET",
      "/api/v1/productions",
    );
    expect(second.productions[0].id).toBe("p1");
  });

  it("throws a 501 ApiError for an unrecorded read", () => {
    expect(() => demoRespond("GET", "/api/v1/expenses")).toThrowError(ApiError);
    try {
      demoRespond("GET", "/api/v1/expenses");
    } catch (err) {
      expect((err as ApiError).status).toBe(501);
      expect((err as ApiError).code).toBe("DEMO_NOT_RECORDED");
    }
  });

  it("throws a 501 DEMO_READ_ONLY for any write, even a recorded path", () => {
    try {
      demoRespond("PATCH", "/api/v1/productions");
      throw new Error("should have thrown");
    } catch (err) {
      expect((err as ApiError).code).toBe("DEMO_READ_ONLY");
    }
  });

  it("still serves the recorded login POST", () => {
    expect(demoRespond("POST", "/api/v1/auth/login")).toEqual({
      access_token: "demo",
      refresh_token: "demo",
    });
  });
});

describe("demoMeta", () => {
  it("exposes the captured metadata", () => {
    expect(demoMeta().demoEmail).toBe("rajesh.kumar@xyzcba.com");
  });
});
```

Two behaviours worth noticing in those tests. Writes are rejected *before* the fixture lookup, so a recorded path cannot be mutated by accident — except `POST /api/v1/auth/login`, which is a write by HTTP verb but a read in spirit and is explicitly allowed. And every response is deep-copied, because React Query hands these objects to components that may sort or splice them in place; without the copy one page visit would corrupt the next.

- [ ] **Step 6: Run them and watch them fail**

Run: `cd web && npm test`
Expected: FAIL — `Failed to resolve import "./transport"`

- [ ] **Step 7: Write the implementation**

`web/src/demo/transport.ts`:

```ts
import { ApiError } from "@/lib/api/error";
import { lookupKeys, requestKey } from "./keys";
import fixtures from "./fixtures.generated.json";

export interface DemoMeta {
  capturedAt: string;
  tenant: string;
  demoEmail: string;
}

interface FixtureFile {
  _meta: DemoMeta;
  responses: Record<string, unknown>;
}

const file = fixtures as unknown as FixtureFile;

/** Writes that are really reads. Login is a POST but changes no state. */
const ALLOWED_WRITES = new Set(["POST /api/v1/auth/login"]);

function demoError(status: number, code: string, message: string): ApiError {
  return new ApiError(status, {
    code,
    message,
    details: undefined,
    request_id: "demo",
  });
}

export function demoMeta(): DemoMeta {
  return file._meta;
}

/**
 * Resolve a request against the recorded fixtures.
 *
 * Throws rather than returning a fallback: a demo that silently shows nothing
 * hides its own gaps, and the app already renders ApiError properly.
 */
export function demoRespond<T>(method: string, path: string): T {
  const upper = method.toUpperCase();

  if (upper !== "GET" && !ALLOWED_WRITES.has(requestKey(upper, path))) {
    throw demoError(
      501,
      "DEMO_READ_ONLY",
      "This is a read-only demo — changes cannot be saved.",
    );
  }

  for (const key of lookupKeys(upper, path)) {
    if (Object.prototype.hasOwnProperty.call(file.responses, key)) {
      // Deep copy: React Query hands this object to components that may sort
      // or splice in place, which would otherwise corrupt the next lookup.
      return structuredClone(file.responses[key]) as T;
    }
  }

  throw demoError(
    501,
    "DEMO_NOT_RECORDED",
    `This page is not part of the demo (${requestKey(upper, path)}).`,
  );
}
```

- [ ] **Step 8: Enable JSON imports if TypeScript objects**

If `tsc --noEmit` reports the JSON import cannot be resolved, add to `web/tsconfig.json` under `compilerOptions`:

```json
"resolveJsonModule": true
```

- [ ] **Step 9: Run the tests and watch them pass**

Run: `cd web && npm test && npx tsc --noEmit`
Expected: PASS — 15 passed (8 prior + 7 here); no type errors

- [ ] **Step 10: Commit**

```bash
git add web/src/demo/transport.ts web/src/demo/transport.test.ts web/src/demo/fixtures.generated.json web/tsconfig.json
git commit -m "feat(web): add the demo fixture transport"
```

---

### Task 4: Fixture capture script

This is the only task that needs a running stack. It records what the three gateways actually return.

**Files:**
- Create: `scripts/capture-demo-fixtures.sh`
- Modify: `web/src/demo/fixtures.generated.json` (overwritten by running the script)

**Interfaces:**
- Consumes: a live local stack (`make db-bootstrap WITH_SEED=1` then `make dev-start`)
- Produces: `web/src/demo/fixtures.generated.json` in the shape Task 3 reads

- [ ] **Step 1: Write the script**

`scripts/capture-demo-fixtures.sh`:

```bash
#!/usr/bin/env bash
# Record demo fixtures from a live, seeded local stack.
#
# Captures only the five-page slice: login, productions (+detail), budgets
# (+detail). Everything else in the web tier calls services that expose no
# grpc-gateway — see mambakkam-net/docs/DESIGN_thittam_demo.md.
#
# Usage:
#   make db-bootstrap WITH_SEED=1
#   make dev-start
#   ./scripts/capture-demo-fixtures.sh
set -euo pipefail

IAM="${IAM_URL:-http://localhost:9086}"
PROJECT="${PROJECT_URL:-http://localhost:9080}"
BUDGET="${BUDGET_URL:-http://localhost:9081}"
EMAIL="${DEMO_EMAIL:-rajesh.kumar@xyzcba.com}"
PASSWORD="${DEMO_PASSWORD:-demo1234}"
OUT="web/src/demo/fixtures.generated.json"

command -v jq >/dev/null || { echo "FATAL: jq is required"; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
: > "$work/pairs.jsonl"

# record <key> <base> <path> [json-body]
# Fails the whole run on any non-2xx: a demo built on error bodies is worse
# than no demo.
record() {
  local key="$1" base="$2" path="$3" body="${4:-}"
  local code out
  out="$work/body.json"

  if [[ -n "$body" ]]; then
    code=$(curl -sS -o "$out" -w '%{http_code}' \
      -X POST "$base$path" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer ${TOKEN:-}" \
      -d "$body")
  else
    code=$(curl -sS -o "$out" -w '%{http_code}' \
      "$base$path" -H "Authorization: Bearer ${TOKEN:-}")
  fi

  if [[ "$code" != 2* ]]; then
    echo "FATAL: $key -> HTTP $code" >&2
    head -c 400 "$out" >&2; echo >&2
    exit 1
  fi

  jq -c --arg k "$key" '{key: $k, value: .}' "$out" >> "$work/pairs.jsonl"
  echo "  ok  $key"
}

echo "==> login"
login_body=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" \
  '{email: $e, password: $p}')
record "POST /api/v1/auth/login" "$IAM" "/api/v1/auth/login" "$login_body"
TOKEN=$(jq -r '.value.access_token' < <(tail -1 "$work/pairs.jsonl"))
[[ "$TOKEN" != "null" && -n "$TOKEN" ]] || { echo "FATAL: no access_token"; exit 1; }

echo "==> config"
record "GET /api/v1/config/entity-labels" "$PROJECT" "/api/v1/config/entity-labels"
record "GET /api/v1/config/phase-types"   "$PROJECT" "/api/v1/config/phase-types"
record "GET /api/v1/config/budget-categories" "$BUDGET" "/api/v1/config/budget-categories"

echo "==> productions"
record "GET /api/v1/productions" "$PROJECT" "/api/v1/productions"
prod_ids=$(jq -r 'select(.key == "GET /api/v1/productions")
  | .value.productions[]?.id' "$work/pairs.jsonl")
[[ -n "$prod_ids" ]] || { echo "FATAL: productions list is empty — is the seed loaded?"; exit 1; }

for id in $prod_ids; do
  record "GET /api/v1/productions/$id" "$PROJECT" "/api/v1/productions/$id"
  record "GET /api/v1/productions/$id/phases" "$PROJECT" "/api/v1/productions/$id/phases"
  record "GET /api/v1/productions/$id/crew"   "$PROJECT" "/api/v1/productions/$id/crew"
done

echo "==> budgets (per production — no tenant-wide list endpoint exists)"
# The web tier fans out one budgets query per production; there is NO bare
# GET /api/v1/budgets (see web/src/app/(dashboard)/budgets/page.tsx:47 and
# listBudgets(), which sends ?production_id=). Mirror that here.
for pid in $prod_ids; do
  record "GET /api/v1/budgets?production_id=$pid" "$BUDGET" "/api/v1/budgets?production_id=$pid"
done
budget_ids=$(jq -r 'select(.key | startswith("GET /api/v1/budgets?production_id="))
  | .value.budgets[]?.id' "$work/pairs.jsonl" | sort -u)
[[ -n "$budget_ids" ]] || { echo "FATAL: no budgets across any production — is the seed loaded?"; exit 1; }

for id in $budget_ids; do
  record "GET /api/v1/budgets/$id" "$BUDGET" "/api/v1/budgets/$id"
  record "GET /api/v1/budgets/$id/line-items" "$BUDGET" "/api/v1/budgets/$id/line-items"
done

echo "==> writing $OUT"
jq -s --arg email "$EMAIL" '
  {
    _meta: {
      capturedAt: (now | todate),
      tenant: "xyz-cba",
      demoEmail: $email
    },
    responses: (map({(.key): .value}) | add)
  }
' "$work/pairs.jsonl" > "$OUT"

echo
echo "Captured $(jq '.responses | length' "$OUT") responses."
echo "REVIEW BEFORE COMMITTING — an endpoint can return 200 with an empty list."
jq -r '.responses | to_entries[]
  | "\(.key)\t\(.value | if type == "object" then
      (to_entries | map(select(.value | type == "array"))
        | map("\(.key)=\(.value | length)") | join(",")) else "" end)"' "$OUT"
```

- [ ] **Step 2: Make it executable and commit it before running it**

```bash
chmod +x scripts/capture-demo-fixtures.sh
git add scripts/capture-demo-fixtures.sh
git commit -m "feat: add the demo fixture capture script"
```

Committing the script separately from its output keeps the (large) fixture diff reviewable on its own.

- [ ] **Step 3: Bring up the stack**

```bash
make db-bootstrap WITH_SEED=1
make dev-start
```

Wait for the log lines `gateway ready on :9080`, `:9081` and `:9086`. If any service fails to start, stop here and fix that first — do not proceed with a partial capture.

- [ ] **Step 4: Run the capture**

Run: `./scripts/capture-demo-fixtures.sh`
Expected: a run of `ok <key>` lines, then a count and a per-key array-length summary.

If it exits non-zero, the failing key and the response body are printed. A `401` means the seeded password is not `demo1234`; a `404` means that endpoint does not exist and the affected page must leave the slice — update `DESIGN_thittam_demo.md` before continuing.

- [ ] **Step 5: Read the summary before trusting it**

Check the printed array lengths. `GET /api/v1/productions` with `productions=0` is a `200` that means the seed did not load. Re-run `make db-reset` and capture again rather than committing an empty demo.

- [ ] **Step 6: Confirm the transport tests still pass against real data**

Run: `cd web && npm test`
Expected: PASS — the transport tests mock the fixture module, so they are unaffected. This step confirms the real file is still valid JSON of the right shape.

- [ ] **Step 7: Commit the fixtures**

```bash
git add web/src/demo/fixtures.generated.json
git commit -m "chore(web): record demo fixtures from the XYZ_CBA seed"
```

---

### Task 5: Wire the transport into both seams

**Files:**
- Modify: `web/src/lib/api/client.ts`
- Modify: `web/src/lib/api/auth.ts`

**Interfaces:**
- Consumes: `demoRespond` from `@/demo/transport`; `env.demoMode` from `@/env`
- Produces: no new exports — both transports now short-circuit in demo mode

- [ ] **Step 1: Branch inside `ApiClient.request()`**

In `web/src/lib/api/client.ts`, add the import:

```ts
import { demoRespond } from "@/demo/transport";
```

and insert as the **first statement** of `private async request<T>(...)`, before the `headers` object is built:

```ts
    // Demo builds never touch the network. This must come before any URL is
    // resolved: env.ts falls back to window.location.hostname, which would
    // otherwise produce requests to mambakkam.net:9086 that hang.
    if (env.demoMode) {
      return demoRespond<T>(method, path);
    }
```

`env` is already imported at the top of the file.

- [ ] **Step 2: Branch inside `authRequest()`**

`web/src/lib/api/auth.ts` does not use `ApiClient` — it has its own `fetch`. Add the import:

```ts
import { demoRespond } from "@/demo/transport";
```

and insert as the first statement of `async function authRequest<T>(path, body)`:

```ts
  if (env.demoMode) {
    return demoRespond<T>("POST", path);
  }
```

Miss this one and login still hits the network in a demo build.

- [ ] **Step 3: Verify types and lint**

Run: `cd web && npx tsc --noEmit && npm run lint`
Expected: no errors

- [ ] **Step 4: Prove it end to end in the browser**

```bash
cd web
NEXT_PUBLIC_DEMO=1 npm run dev
```

Open `http://localhost:3100/login` with the network panel open, sign in as `rajesh.kumar@xyzcba.com` / `demo1234`, and visit `/productions` and `/budgets`.

Expected: pages render seeded data, and the network panel shows **no XHR/fetch to :9080, :9081 or :9086**. Any such request means a seam was missed — find it before continuing.

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/api/client.ts web/src/lib/api/auth.ts
git commit -m "feat(web): serve fixtures from both transports in demo mode"
```

---

### Task 6: Static-export the dynamic routes

`generateStaticParams()` cannot be exported from a `"use client"` file, so each `[id]` route splits into a server wrapper plus the existing client component.

**Files:**
- Create: `web/src/demo/params.ts`
- Create: `web/src/demo/params.test.ts`
- Create: `web/src/app/(dashboard)/productions/[id]/view.tsx`
- Create: `web/src/app/(dashboard)/budgets/[id]/view.tsx`
- Modify: `web/src/app/(dashboard)/productions/[id]/page.tsx`
- Modify: `web/src/app/(dashboard)/budgets/[id]/page.tsx`

**Interfaces:**
- Consumes: `fixtures.generated.json`
- Produces: `idsForCollection(collection: string): string[]` from `@/demo/params`

- [ ] **Step 1: Write the failing test**

`web/src/demo/params.test.ts`:

```ts
import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("./fixtures.generated.json", () => ({
  default: {
    _meta: { capturedAt: "", tenant: "xyz-cba", demoEmail: "a@b.c" },
    responses: {
      "GET /api/v1/productions": {},
      "GET /api/v1/productions/p1": {},
      "GET /api/v1/productions/p2": {},
      "GET /api/v1/productions/p1/phases": {},
      "GET /api/v1/budgets/b1": {},
    },
  },
}));

let idsForCollection: typeof import("./params").idsForCollection;

beforeEach(async () => {
  idsForCollection = (await import("./params")).idsForCollection;
});

describe("idsForCollection", () => {
  it("finds every recorded detail id", () => {
    expect(idsForCollection("productions").sort()).toEqual(["p1", "p2"]);
  });

  it("ignores nested sub-resources", () => {
    expect(idsForCollection("productions")).not.toContain("phases");
  });

  it("ignores the bare list key", () => {
    expect(idsForCollection("productions")).not.toContain("");
  });

  it("works for a different collection", () => {
    expect(idsForCollection("budgets")).toEqual(["b1"]);
  });

  it("returns an empty array for an unrecorded collection", () => {
    expect(idsForCollection("expenses")).toEqual([]);
  });
});
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd web && npm test`
Expected: FAIL — `Failed to resolve import "./params"`

- [ ] **Step 3: Write the implementation**

`web/src/demo/params.ts`:

```ts
import fixtures from "./fixtures.generated.json";

const file = fixtures as unknown as { responses: Record<string, unknown> };

/**
 * The `[id]` values to pre-render, derived from what was actually recorded.
 *
 * Reading these from the fixtures rather than a hand-kept list means a
 * re-capture cannot leave the route list stale.
 */
export function idsForCollection(collection: string): string[] {
  const prefix = `GET /api/v1/${collection}/`;
  const ids = new Set<string>();

  for (const key of Object.keys(file.responses)) {
    if (!key.startsWith(prefix)) continue;
    const rest = key.slice(prefix.length);
    // Skip sub-resources like ".../p1/phases" and any trailing-slash artefact.
    if (rest === "" || rest.includes("/")) continue;
    ids.add(rest);
  }

  return [...ids];
}
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd web && npm test`
Expected: PASS — 21 passed

- [ ] **Step 5: Split the productions detail route**

```bash
cd web
git mv "src/app/(dashboard)/productions/[id]/page.tsx" \
       "src/app/(dashboard)/productions/[id]/view.tsx"
```

In the new `view.tsx`, rename the default export to a named one — change `export default function ProductionDetailPage(` to `export function ProductionDetailView(`. Keep `"use client"` at the top and change nothing else.

Then create `web/src/app/(dashboard)/productions/[id]/page.tsx`:

```tsx
import { idsForCollection } from "@/demo/params";
import { ProductionDetailView } from "./view";

// Server component: generateStaticParams cannot live in a "use client" file.
export function generateStaticParams() {
  return idsForCollection("productions").map((id) => ({ id }));
}

export default function ProductionDetailPage() {
  return <ProductionDetailView />;
}
```

No prop threading is needed: the component already reads the route param itself via `useParams<{ id: string }>()` (`productions/[id]/page.tsx:385`, becoming `view.tsx:385`). Leave that alone.

- [ ] **Step 6: Split the budgets detail route the same way**

```bash
git mv "src/app/(dashboard)/budgets/[id]/page.tsx" \
       "src/app/(dashboard)/budgets/[id]/view.tsx"
```

Rename its default export to `export function BudgetDetailView(`, then create `web/src/app/(dashboard)/budgets/[id]/page.tsx`:

```tsx
import { idsForCollection } from "@/demo/params";
import { BudgetDetailView } from "./view";

// Server component: generateStaticParams cannot live in a "use client" file.
export function generateStaticParams() {
  return idsForCollection("budgets").map((id) => ({ id }));
}

export default function BudgetDetailPage() {
  return <BudgetDetailView />;
}
```

- [ ] **Step 7: Verify the normal build still works**

Run: `cd web && npx tsc --noEmit && npm run build`
Expected: build succeeds. `generateStaticParams` is harmless in a normal build — it just pre-renders those ids.

- [ ] **Step 8: Commit**

```bash
git add web/src/demo/params.ts web/src/demo/params.test.ts "web/src/app/(dashboard)/productions/[id]" "web/src/app/(dashboard)/budgets/[id]"
git commit -m "feat(web): split the [id] routes for static export"
```

---

### Task 7: Demo UX — landing, credentials, navigation

Three things make the demo coherent rather than merely functional: it must land somewhere that works, tell visitors how to sign in, and not offer links to pages that are not there.

**Files:**
- Create: `web/src/demo/nav.ts`
- Create: `web/src/demo/nav.test.ts`
- Modify: `web/src/app/(auth)/login/page.tsx`
- Modify: `web/src/components/layout/sidebar.tsx`

**Interfaces:**
- Consumes: `isDemo` from `@/demo/flag`; `demoMeta` from `@/demo/transport`
- Produces: `DEMO_LANDING: string` and `isRouteInDemo(href: string): boolean` from `@/demo/nav`

- [ ] **Step 1: Write the failing test**

`web/src/demo/nav.test.ts`:

```ts
import { describe, it, expect } from "vitest";
import { DEMO_LANDING, isRouteInDemo } from "./nav";

describe("DEMO_LANDING", () => {
  it("is /productions, not the dashboard", () => {
    // The dashboard calls reporting-analytics, which exposes no grpc-gateway.
    expect(DEMO_LANDING).toBe("/productions");
  });
});

describe("isRouteInDemo", () => {
  it("allows the slice", () => {
    expect(isRouteInDemo("/productions")).toBe(true);
    expect(isRouteInDemo("/budgets")).toBe(true);
  });

  it("rejects pages whose services have no REST surface", () => {
    expect(isRouteInDemo("/")).toBe(false);
    expect(isRouteInDemo("/expenses")).toBe(false);
    expect(isRouteInDemo("/inventory")).toBe(false);
    expect(isRouteInDemo("/reports")).toBe(false);
    expect(isRouteInDemo("/billing")).toBe(false);
  });

  it("rejects /projects, which is a dead link in the app itself", () => {
    expect(isRouteInDemo("/projects")).toBe(false);
  });
});
```

That last case is a real bug in the app, not a demo concern: `sidebar.tsx:90` links to `/projects`, but no such route exists — the directory is `productions`. The demo nav must not reproduce a 404.

- [ ] **Step 2: Run it and watch it fail**

Run: `cd web && npm test`
Expected: FAIL — `Failed to resolve import "./nav"`

- [ ] **Step 3: Write the implementation**

`web/src/demo/nav.ts`:

```ts
/**
 * Where the demo lands after login.
 *
 * NOT "/" — the dashboard is driven by six reporting-analytics endpoints
 * (src/lib/api/dashboard.ts) and that service exposes no grpc-gateway, so
 * nothing could be recorded for it.
 */
export const DEMO_LANDING = "/productions";

/** The only routes reachable in a demo build. */
const DEMO_ROUTES = new Set(["/login", "/productions", "/budgets"]);

export function isRouteInDemo(href: string): boolean {
  return DEMO_ROUTES.has(href);
}
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd web && npm test`
Expected: PASS — 27 passed

- [ ] **Step 5: Fix the login redirect and hide SSO**

In `web/src/app/(auth)/login/page.tsx`, add the imports:

```ts
import { isDemo } from "@/demo/flag";
import { DEMO_LANDING } from "@/demo/nav";
import { demoMeta } from "@/demo/transport";
```

Change the post-login redirect (currently `router.replace("/")`):

```ts
      await login(values.email, values.password);
      router.replace(isDemo() ? DEMO_LANDING : "/");
```

Hide the SSO button — lines 146–153, the `<button type="button" onClick={handleSsoLogin}>` containing `<ShieldCheck />` and "Sign in with SSO". It navigates to `${NEXT_PUBLIC_PLATFORM_API_URL}/api/v1/auth/sso/authorize`, a dead host in a static build. Wrap that whole `<button>` element, plus whatever divider sits directly above it:

```tsx
{!isDemo() && (
  <button
    type="button"
    onClick={handleSsoLogin}
    /* keep the existing className verbatim */
  >
    <ShieldCheck className="h-4 w-4" />
    Sign in with SSO
  </button>
)}
```

Hide the "Forgot your password?" link the same way — lines 155–162, an `<a href="/forgot-password">`. There is no `forgot-password` route in `src/app/` at all, so it 404s in the demo (and in the product; see Follow-ups):

```tsx
{!isDemo() && (
  <p className="mt-6 text-center text-xs text-[var(--thittam-muted-foreground,#64748b)]">
    {/* the existing <a href="/forgot-password"> link, unchanged */}
  </p>
)}
```

Add the credentials hint immediately after the `<p>` that reads "Enter your credentials to access your account.":

```tsx
{isDemo() && (
  <div className="mb-6 rounded-md border border-blue-200 bg-blue-50 px-4 py-3 text-sm text-blue-800 dark:border-blue-800 dark:bg-blue-950 dark:text-blue-200">
    <p className="font-medium">Demo — read-only</p>
    <p className="mt-1">
      Sign in as <code>{demoMeta().demoEmail}</code> with password{" "}
      <code>demo1234</code>. Data is a recorded snapshot; changes cannot be
      saved.
    </p>
  </div>
)}
```

- [ ] **Step 6: Pre-fill the form in demo mode**

The `useForm` call at lines 27–29 currently passes only a resolver and has no `defaultValues` key. Add one:

```ts
  } = useForm<LoginValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: isDemo()
      ? { email: demoMeta().demoEmail, password: "demo1234" }
      : { email: "", password: "" },
  });
```

- [ ] **Step 7: Filter the sidebar**

In `web/src/components/layout/sidebar.tsx`, add:

```ts
import { isDemo } from "@/demo/flag";
import { isRouteInDemo } from "@/demo/nav";
```

The component already filters items by permission at line 246, inside `menu.map(...)`, and already skips a section when nothing survives. Compose the demo filter onto that one line rather than restructuring anything:

```ts
          const visibleItems = section.items
            .filter(canSee)
            .filter((item) => !isDemo() || isRouteInDemo(item.href));
```

The existing `if (visibleItems.length === 0) return null;` on the next line then hides any section that empties out — so the "Main" group collapses to just Productions and Budgets with no further work.

Note this also suppresses the `/projects` entry (line 90), which is a dead link: its `href` is `/projects` but the route directory is `productions`, and there are no rewrites.

- [ ] **Step 8: Verify in the browser**

```bash
cd web && NEXT_PUBLIC_DEMO=1 npm run dev
```

At `http://localhost:3100/login`: the credentials hint shows, the form is pre-filled, there is no SSO button. Signing in lands on `/productions`. The sidebar shows only Productions and Budgets. Network panel still shows zero service calls.

Then run `npm run dev` without the flag and confirm the login page looks exactly as it did before — no hint, SSO present, redirect to `/`.

- [ ] **Step 9: Commit**

```bash
git add web/src/demo/nav.ts web/src/demo/nav.test.ts "web/src/app/(auth)/login/page.tsx" web/src/components/layout/sidebar.tsx
git commit -m "feat(web): demo landing page, credentials hint and nav filter"
```

---

### Task 8: The export build

**Files:**
- Modify: `web/next.config.ts`
- Modify: `web/package.json`

**Interfaces:**
- Consumes: everything above
- Produces: `web/out/` — a static site rooted at `/demos/thittam`

- [ ] **Step 1: Add the env-gated export config**

`web/next.config.ts`:

```ts
import type { NextConfig } from "next";

const demo = process.env.NEXT_PUBLIC_DEMO === "1";

const nextConfig: NextConfig = demo
  ? {
      output: "export",
      basePath: "/demos/thittam",
      // nginx serves directories; trailing slashes make try_files $uri $uri/ work.
      trailingSlash: true,
      // The Image Optimization API needs a server. A static export has none.
      images: { unoptimized: true },
    }
  : {};

export default nextConfig;
```

- [ ] **Step 2: Add the build script**

In `web/package.json` `"scripts"`, add. The `demo.invalid` sentinels matter: `env.ts` otherwise derives service URLs from `window.location.hostname`, so any missed seam would quietly try `https://mambakkam.net:9086` and hang. Pointed at an unresolvable host, a leak fails instantly instead.

```json
"build:demo": "NEXT_PUBLIC_DEMO=1 NEXT_PUBLIC_IAM_URL=http://demo.invalid NEXT_PUBLIC_PROJECT_URL=http://demo.invalid NEXT_PUBLIC_BUDGET_URL=http://demo.invalid NEXT_PUBLIC_PLATFORM_API_URL=http://demo.invalid next build"
```

- [ ] **Step 3: Build**

Run: `cd web && npm run build:demo`
Expected: build succeeds and `out/` exists.

If it fails with "Page ... is missing generateStaticParams", an `[id]` route outside the slice is being rendered. Confirm only `productions/[id]` and `budgets/[id]` have wrappers, and that no in-slice page links into another dynamic route.

- [ ] **Step 4: Confirm the output shape**

```bash
cd web
ls out/demos/thittam/productions/
test -d out/demos/thittam/_next && echo "assets ok"
```

Expected: an `index.html`, one directory per recorded production id, and `assets ok`.

- [ ] **Step 5: Serve it exactly as nginx will**

```bash
cd web/out && python3 -m http.server 8099
```

Open `http://localhost:8099/demos/thittam/login/`. Walk login → productions → a production → budgets → a budget.

Expected: every page renders; the network panel shows requests only to `localhost:8099`. **A single request to `demo.invalid` is a failure** — it means a transport seam was missed. Fix it before continuing.

- [ ] **Step 6: Confirm the normal build is untouched**

Run: `cd web && npm run build`
Expected: a normal server build, no `out/` regenerated, no `basePath` in the output.

- [ ] **Step 7: Commit**

```bash
git add web/next.config.ts web/package.json
git commit -m "feat(web): add the static demo export build"
```

---

### Task 9: Publish to mambakkam-net

Everything here is in the `mambakkam-net` repo. Work on a branch off `main`.

**Files:**
- Create: `mambakkam-net/public/demos/thittam/**` (the copied export)
- Modify: `mambakkam-net/nginx/nginx.conf`
- Modify: `mambakkam-net/.prettierignore`, `mambakkam-net/eslint.config.js`
- Modify: `mambakkam-net/scripts/launch/smoke.sh`
- Modify: `mambakkam-net/src/data/work/thittam.md`

**Interfaces:**
- Consumes: `thittam/web/out/`
- Produces: `https://mambakkam.net/demos/thittam/`

- [ ] **Step 1: Branch**

```bash
cd ../mambakkam-net
git switch -c demo/thittam main
```

- [ ] **Step 2: Add the ignores before copying anything in**

Bundled output must not reach the CI `check` job. In `.prettierignore` add:

```
public/demos/thittam/
```

In `eslint.config.js`, add `"public/demos/thittam/**"` to the existing `ignores` array — the same array that already excludes the Mentible export.

- [ ] **Step 3: Copy the export**

```bash
rm -rf public/demos/thittam
cp -r ../thittam/web/out/demos/thittam public/demos/thittam
test -f public/demos/thittam/login/index.html && echo ok
```

Note the source path is `out/demos/thittam`, not `out` — `basePath` nests the output.

- [ ] **Step 4: Add the nginx blocks**

In `nginx/nginx.conf`, alongside the existing Mentible blocks:

```nginx
# ── Thittam static demo (Next.js export) ──────────────────────────────────
# Content-hashed Next assets MUST resolve to a real file or a real 404 —
# never fall back to index.html. Serving HTML under a .js URL is what
# poisoned the Cloudflare cache during the Mentible deploy and hung the app
# on a blank shell. Hashed filenames are safe to cache forever.
location ^~ /demos/thittam/_next/ {
    try_files $uri =404;
    add_header Cache-Control "public, max-age=31536000, immutable" always;
}

# Genuine SPA deep links fall back to the demo's own index.html. Keep that
# HTML uncached so a new deploy is picked up at once.
location /demos/thittam/ {
    try_files $uri $uri/ /demos/thittam/index.html;
    add_header Cache-Control "no-cache" always;
}
```

This is the app-level nginx inside the astrowind container. `infra/nginx/mambakkam.net.conf` needs no change — there is no backend to proxy.

- [ ] **Step 5: Build the site and check the gates**

Run: `npm run build && npm run check`
Expected: both pass. If `check` flags files under `public/demos/thittam/`, Step 2 was missed or the ignore path is wrong.

- [ ] **Step 6: Verify through the real container**

```bash
docker compose up -d --build
curl -sf -o /dev/null -w '%{http_code}\n' http://localhost:8081/demos/thittam/
curl -sf -o /dev/null -w '%{http_code}\n' http://localhost:8081/demos/thittam/login/
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8081/demos/thittam/_next/does-not-exist.js
```

Expected: `200`, `200`, then `404`. That third one is the important assertion — a `200` there means the SPA fallback is swallowing asset requests and will poison the CDN cache.

- [ ] **Step 7: Add the smoke assertion**

In `scripts/launch/smoke.sh`, next to the existing demo checks, add a `/demos/thittam/` 200 assertion following the file's established helper and style.

- [ ] **Step 8: Link it from the work page**

In `src/data/work/thittam.md`, add a demo link following the pattern the atri-sangam listing already uses (see `docs/DESIGN_atri_sangam_listing.md`). Describe it accurately — a read-only snapshot covering productions and budgets, not the whole product.

- [ ] **Step 9: Commit**

```bash
git add public/demos/thittam .prettierignore eslint.config.js nginx/nginx.conf scripts/launch/smoke.sh src/data/work/thittam.md
git commit -m "feat(demos): publish the Thittam static demo at /demos/thittam"
```

- [ ] **Step 10: Hand off to the operator**

The host nginx is never auto-reloaded — a syntax error would take down the co-tenant StudyBuddy vhost too. Deploy is:

```bash
sudo git -C /opt/mambakkam pull
sudo docker compose -f /opt/mambakkam/docker-compose.yml up -d --build
curl -fsS -o /dev/null -w '%{http_code}\n' https://mambakkam.net/demos/thittam/
```

No host-nginx reload is needed for this change, since only the container's own config changed.

---

## Follow-ups (not in this plan)

- File the web-tier-vs-REST-surface gap against `project-critique/thittam-critique.md`: seven services expose no grpc-gateway, so `/expenses`, `/inventory`, `/reports`, `/notifications`, `/documents` and `/billing` call endpoints nothing serves.
- File two dead links found while planning: `web/src/components/layout/sidebar.tsx:90` points the main nav at `/projects`, but the route directory is `productions` and there are no rewrites; and `src/app/(auth)/login/page.tsx:157` links to `/forgot-password`, for which no route exists at all.
- grpc-gateway registration for `expense-tracking`, `inventory-management` and `reporting-analytics`, which would unlock those pages for the product and let the demo slice grow.
