# Mentible-lite static demo (`/demos/mentible`)

Host a **public Mentible web demo at `https://mambakkam.net/demos/mentible/`** with
**no new domain and no backend** — it rides the existing static mambakkam.net deploy.

This file documents the build + drop-in. The mambakkam.net side is already wired
(this is the "slot"); what remains is generating the Expo-web export and copying it in.

---

## Hard prerequisite — it must be backend-free

This only works if the Mentible web build is **client-only**: the browser talks to the
LLM provider **directly with a user-supplied key (BYOK)**, with no call to the FastAPI
generation backend.

If the web build still calls the Mentible backend, a static host cannot serve it
(there is no API origin, and CORS will block it). In that case this path does **not**
apply — use the **subdomain + backend** option instead (`mentible.<owned-domain>`
reverse-proxied to a container, like `demo.usestudybuddy.com`).

> Confirm a client-only/BYOK web mode exists in `StudyBuddy_SelfLearner/mobile`
> before relying on this. The slot below is ready regardless.

---

## What is already wired on the mambakkam.net side

| Piece                  | Where                                            | Why                                                                                                 |
| ---------------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| Served slot            | `public/demos/mentible/`                         | Astro copies `public/*` verbatim into `dist/` → served at `/demos/mentible/`                        |
| SPA deep-link fallback | `nginx/nginx.conf` (`location /demos/mentible/`) | Expo-router web is a single-page app; deep links fall back to its `index.html`, not the village 404 |
| Prettier ignore        | `.prettierignore` → `public/demos`               | Bundled export assets are minified; never hand-format them (would re-break CI)                      |
| ESLint ignore          | `eslint.config.js` ignores → `public/demos`      | Same — don't lint the bundled JS                                                                    |
| Interim placeholder    | `public/demos/mentible/index.html`               | Makes the route live now; overwritten by the export                                                 |

---

## Build + drop-in steps

Run in `../StudyBuddy_SelfLearner/mobile` (Expo SDK 52, expo-router 4):

1. **Set the web base path** so asset + router URLs resolve under the subpath.
   In `app.json`:

   ```json
   { "expo": { "experiments": { "baseUrl": "/demos/mentible" } } }
   ```

2. **Export the web build:**

   ```bash
   npx expo export --platform web      # outputs to mobile/dist/
   ```

3. **Copy into the mambakkam.net slot** (replacing the placeholder):

   ```bash
   rm -rf <mambakkam-net>/public/demos/mentible/*
   cp -r mobile/dist/* <mambakkam-net>/public/demos/mentible/
   ```

4. **Verify + ship from mambakkam.net:**

   ```bash
   npm run build                       # confirm dist/demos/mentible/index.html exists
   npm run check                       # prettier/eslint skip public/demos — should stay green
   git add public/demos/mentible nginx/nginx.conf
   git commit -m "feat(demo): publish Mentible-lite web demo at /demos/mentible"
   ```

   The push deploys via the normal `Deploy mambakkam.net` workflow; nginx serves the
   files, with the SPA fallback handling client-side routes.

---

## Caveats

- **Brand.** `mambakkam.net/demos/mentible` puts Mentible under the village/personal
  brand. Fine for an interim/shareable demo; Mentible's own domain is the eventual
  home (it is "pending domain clearance").
- **Base path is baked in.** The export is built for `/demos/mentible` specifically.
  If the path ever changes, rebuild with the new `baseUrl` — you can't just move the
  folder.
- **`noindex`.** The placeholder is `noindex`; decide whether the real demo should be
  indexable before launch.
