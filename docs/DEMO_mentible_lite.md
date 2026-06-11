# Mentible demo on mambakkam.net (`/demos/mentible`)

Host a **public Mentible demo with no new domain**, riding the existing Hetzner VPS
that already serves mambakkam.net + the StudyBuddy demo. Two same-origin pieces:

```
Browser
  └─ https://mambakkam.net/demos/mentible/   ← static Expo-web export (frontend)
        │  fetch
        └─ https://mambakkam.net/mentible-api/api/v1/...   ← FastAPI backend
                                                              (sibling Docker stack)
```

Same origin → **no new subdomain, no DNS record, no Origin Cert change, no CORS.**

---

## Correction — Mentible is NOT backend-free

An earlier draft assumed a client-only (BYOK, browser→provider) build was possible.
**It isn't.** `mobile/src/api/client.ts` routes everything — `generate`, `structure`,
and `export` — through the FastAPI backend, and BYOK keys are _sent to that backend_
(`types/book.ts: api_key`, `hooks/useGenerateTopic.ts`); there are zero direct
browser→provider calls. So the demo needs the backend running and reachable. The
chosen approach keeps it on the same VPS, proxied at a same-origin path.

---

## Components

| Piece                 | Repo / file                                         | Role                                                                       |
| --------------------- | --------------------------------------------------- | -------------------------------------------------------------------------- |
| Frontend slot         | `mambakkam-net/public/demos/mentible/`              | Astro copies `public/*` → `dist/`; served at `/demos/mentible/`            |
| Frontend SPA fallback | `mambakkam-net/nginx/nginx.conf`                    | App-internal nginx: deep links fall back to the export's `index.html`      |
| Lint ignores          | `mambakkam-net/.prettierignore`, `eslint.config.js` | Keep bundled/minified export assets out of the CI `check` job              |
| Backend reverse-proxy | `mambakkam-net/infra/nginx/mambakkam.net.conf`      | Host nginx: `location /mentible-api/` → `127.0.0.1:8092` (prefix stripped) |
| Backend stack         | `StudyBuddy_SelfLearner/docker-compose.demo.yml`    | `api` (FastAPI, 127.0.0.1:8092) + `redis`, prod-shaped, resource-capped    |

---

## Before deploying — validate it actually works

Mentible is `status: in-progress` and has not been seen generating end-to-end. Run a
keyed smoke test against the local stack first (backend already runs via the dev
`docker compose`; web on :8081):

1. Open `http://localhost:8081` → Settings → paste an `sk-ant-…` key.
2. Topic "Quadratic formula" (KaTeX) and "TCP three-way handshake" (Mermaid) → generate.
3. Structure a book, then export EPUB/PDF.

Don't deploy a broken demo.

---

## Deploy (operator, on the VPS)

### 1. Backend stack

```bash
# On the VPS, alongside /opt/mambakkam and /opt/studybuddy:
sudo git clone https://github.com/wegofwd2020-hub/StudyBuddy_SelfLearner /opt/mentible
cd /opt/mentible
printf 'BYOK_MASTER_KEY=%s\n' "$(openssl rand -hex 32)" | sudo tee .env.demo
sudo docker compose -f docker-compose.demo.yml --env-file .env.demo up -d --build --remove-orphans
curl -fs http://127.0.0.1:8092/readyz        # → {"status":"ok","redis":"ok"}
```

### 2. Host nginx route

The `location /mentible-api/` block ships in `mambakkam-net/infra/nginx/mambakkam.net.conf`,
which is symlinked into `sites-enabled`. Pull it onto the box, then reload **manually**
(host nginx is NOT auto-reloaded — a syntax error would also take down the co-tenant
StudyBuddy vhost):

```bash
sudo git -C /opt/mambakkam pull
sudo nginx -t && sudo systemctl reload nginx
curl -fs https://mambakkam.net/mentible-api/readyz   # same-origin, through Cloudflare
```

### 3. Frontend export

In `StudyBuddy_SelfLearner/mobile` (Expo SDK 52, expo-router 4):

1. Set the web base path in `app.json`:

   ```json
   { "expo": { "experiments": { "baseUrl": "/demos/mentible" } } }
   ```

2. Build, pointing the app at the same-origin backend path:

   ```bash
   EXPO_PUBLIC_API_BASE_URL=https://mambakkam.net/mentible-api \
     npx expo export --platform web        # → mobile/dist/
   ```

3. Drop into the slot (replacing the placeholder) and ship from mambakkam-net:

   ```bash
   rm -rf <mambakkam-net>/public/demos/mentible/*
   cp -r mobile/dist/* <mambakkam-net>/public/demos/mentible/
   cd <mambakkam-net>
   npm run build && npm run check          # public/demos is lint-ignored; stays green
   git add public/demos/mentible
   git commit -m "feat(demo): publish Mentible web demo at /demos/mentible"
   ```

   The push deploys mambakkam.net via the normal `Deploy mambakkam.net` workflow.

---

## Caveats

- **Load.** The shared CX23 is small; the compose caps the api at 0.5 cpu / 384M.
  `POST /export` with `diagrams=true` renders for minutes — the nginx route allows
  `proxy_read_timeout 300s` for it.
- **`BYOK_MASTER_KEY`** is a real secret (generate once with `openssl rand -hex 32`),
  kept only in `/opt/mentible/.env.demo`, never committed.
- **Baked URLs.** The export hard-codes both `baseUrl=/demos/mentible` and the backend
  URL. Changing either path means a rebuild, not a file move.
- **Brand.** `mambakkam.net/demos/mentible` puts Mentible under the village brand —
  fine for an interim/shareable demo; its own domain is the eventual home.
- **`noindex`.** The placeholder is `noindex`; decide whether the real demo should be
  indexable before launch.
