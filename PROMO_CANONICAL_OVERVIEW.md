# mambakkam.net — Canonical Overview (for promo / outreach work)

> **Purpose of this doc.** A single source-of-truth you can paste into
> the top of any Claude.ai conversation when drafting promo or outreach
> material for mambakkam.net — diaspora outreach emails, visitor /
> heritage-tourism posts, professional-services intro emails, LinkedIn
> posts that link to the site, Tamil / regional press blurbs, community
> update announcements. Tight enough to fit in one prompt; specific
> enough that Claude doesn't have to guess.
>
> **How to use.** Open a Claude.ai Project (or a new conversation),
> paste this whole doc as the first message, then say what you want:
> *"Draft a 200-word LinkedIn post inviting diaspora to visit the village
> the next time they're in Tamil Nadu."* Iterate from there. Update this
> doc — not your individual chats — when the village or the site
> evolves.
>
> **Last refreshed:** 2026-05-19.

---

## The one-line pitch

> **A farming village in Tamil Nadu — and its corner of the web.**

*Site tagline (live on the homepage):* Mambakkam · Tamil Nadu · India

*Homepage Tamil headline:* மாம்பாக்கம்

*Homepage subtitle:* A farming village in Kalavai Taluk, near the Palar river — rooted in paddy fields, groundnut, and sugarcane, and home to its temples, its land, and its people.

---

## What it is (in three sentences)

mambakkam.net is the web presence of **Mambakkam village** (Tamil: மாம்பாக்கம்) — a farming community in Kalavai Taluk, Ranipet District, Tamil Nadu, India. The site is village-first: it celebrates the village's land, temples, people, and history; only one chapter is dedicated to the professional work of one person from the village.

The site is a personal labour by Sivakumar Mambakkam (Enterprise Architect, distributed-systems / cloud-platforms) to give the village a place on the internet that is **theirs** — not an aggregator listing, not a Wikipedia stub, not a tourism portal. A space the diaspora can point at and say *"this is where we are from."*

It is not a business. It does not collect emails, sell subscriptions, or run ads. It exists because village identity is worth preserving in writing while there are still people who remember.

---

## The framing — "village is the primary brand"

This is the load-bearing decision and it shapes every page.

| What it is | What it is NOT |
|---|---|
| A community website for Mambakkam village | A personal portfolio site with "village" as a flavour |
| Village identity (land, temples, people, history) leads | Software products + enterprise architecture lead |
| The Work / Services chapter is small and downstream | The Work / Services chapter is the homepage |
| Tamil + English mixed where the village name appears | English-only with optional translation |
| Diaspora and community first; clients distant second | Clients first; community as proof-of-authenticity |

If someone visits the homepage and walks away thinking *"this is a village"* — the framing works. If they walk away thinking *"this is a software engineer with a village hobby"* — the framing has slipped. The hero image (a village photo, not a Siva headshot), the Tamil headline, the temple-shrine landmarks at the top of the menu, all reinforce the village-first frame.

---

## Who it's for, in the order of who shows up

1. **The diaspora.** People from Mambakkam (or whose parents / grandparents are from Mambakkam) who now live elsewhere — in Chennai, Bangalore, the Gulf, North America, Europe. The site gives them a way to see what's happening in the village, who's there, what the temple looks like today. The strongest signal of success: a diaspora cousin shares the link in a family WhatsApp group.

2. **Heritage / cultural visitors.** People planning a trip to Tamil Nadu who want to see something off the typical Chennai-Pondicherry-Madurai trail. The Landmarks pages (Ellaiyamman, Pillaiyar, Ayyanar shrines, the new temple under construction) are the draw. The site is not a tourism portal — it doesn't claim hotel listings or operate as TripAdvisor — but it gives a curious visitor enough to add Mambakkam to a Tamil Nadu itinerary.

3. **Community members.** Other residents of Mambakkam who want to see the village's web presence, contribute photos or stories, or use it to introduce themselves to relatives. Long-term, the People collection grows here.

4. **Professional contacts (downstream — Siva's "Work" + "Services" chapters).** Recruiters, hiring managers, or potential clients who land on the site after seeing Siva's LinkedIn or a referral. They get the village context first, then a clear path to the professional bio + services + products. The juxtaposition is intentional: it signals depth (someone whose roots are real), not gimmick.

5. **Press / writers / researchers.** Anyone writing about Tamil village heritage, the Palar river basin, or rural Tamil Nadu administration may stumble in. The site is verified-fact-first (taluk + district + coordinates + administrative status all triple-checked) so it's safe to cite.

---

## What's live right now (as of 2026-05-19)

- **Live site:** `https://mambakkam.net` — Astro 5 + AstroWind + Tailwind, hosted on Hetzner Cloud, fronted by Cloudflare. Lighthouse 90+. Live since 2026-05-18.
- **Nav structure:** Village (About, Land & Agriculture) · Landmarks · People · Work (Products, Services) · News.
- **Pages built:** `/` (homepage) · `/village` · `/land` · `/landmarks` + 4 landmark detail pages · `/people` + 1 person detail page (Siva) · `/work` + 5 product detail pages · `/services` · `/news` (blog).
- **Landmarks documented (4):** Ellaiyamman Temple · Pillaiyar Temple · Ayyanar Shrine · new temple (under construction).
- **People documented (1, with more planned):** Sivakumar Mambakkam (Enterprise Architect).
- **Work / products listed (5):** StudyBuddy OnDemand, Thittam, StudyBuddy Q, AI Learning Platform, StudyBuddy Free.
- **Services documented:** Enterprise Architecture, Distributed Systems Design, Cloud-native Platforms.
- **Map:** interactive Leaflet / OpenStreetMap pin on `/` and `/village` (coordinates 12.6779°N, 79.3964°E).
- **Accessibility:** dyslexia-friendly font + reading-mode toggle (one of the few site features the diaspora has specifically commented on).
- **Languages:** English primary, with Tamil for the village name (மாம்பாக்கம்) and a person's name in the People collection. Full Tamil translation of long-form copy is in backlog, not yet shipped.

---

## Verified village facts (use these EXACTLY — they were triple-checked 2026-05-08)

| Field | Value |
|---|---|
| Village name | Mambakkam (மாம்பாக்கம்) |
| Pincode | 632318 |
| Taluk | **Kalavai Taluk** (not Walajah — older sources are wrong) |
| District | Ranipet (carved from Vellore District in 2019) |
| State | Tamil Nadu, India |
| Postal head office | Valapandal |
| Approximate coordinates | 12.6779°N, 79.3964°E |
| Distance from Vellore | ~45 km east |
| Local body | Mambakkam Gram Panchayat |
| Population (2009 census-era — stale) | ~2,561 |
| Households (2009 census-era) | ~638 |
| Area | ~566 hectares |
| Primary crops | paddy (rice), groundnut, sugarcane |
| Nearby river | Palar |
| Nearest larger town | Kalavai |

If a draft references something not in this table (a population number, a specific temple festival date, a school count), **double-check the underlying source before publishing.** The web is full of stale data about small villages; treat anything outside this table as unverified.

---

## Voice + tone (paste this into Claude.ai when you want it to write copy)

- **Rooted, not romanticised.** This is a real working farming village — paddy, groundnut, sugarcane. Not a postcard. Not a "hidden gem." Not a "where time stands still" village. Show it as it is.
- **Tamil grace, English clarity.** The village name appears in Tamil (மாம்பாக்கம்) at least once per piece if the audience would recognise it. Body copy is English unless explicitly writing for a Tamil-language audience.
- **First-person plural for the village.** "We grow rice here." "Our temple under construction." Not "they grow rice." The site is BY the village, not ABOUT the village.
- **Specific over general.** "The new temple is going up stone by stone" beats "we're building something special." "Paddy, groundnut, sugarcane" beats "agricultural crops."
- **No buzzwords from either side.** Don't say "smart village," "digital transformation of rural India," "AI-powered community" — community first; tech is downstream. And don't say "sleepy village" or "pastoral idyll" — patronising.
- **Acknowledge what's there AND what's missing.** Saying "we're still building the People collection" or "the Tamil translation is in backlog" is honest and signals the site is alive.
- **Founder framing for Siva's chapter:** he's "from the village" not "the owner of the village website." The chapter is downstream of the village identity.
- **Diaspora-aware.** Names spell themselves the way they do in family WhatsApp groups — don't anglicise overzealously. Mambakkam (not Mampakkam). Siva or Sivakumar (not Shiva).

---

## What NOT to claim (yet)

- Don't claim Tamil-language version is live (it isn't — only specific words).
- Don't claim a population figure newer than 2009 (real census-era data is stale; newer numbers floating online are unverified).
- Don't claim the new temple is complete (it's under construction).
- Don't claim there's a community newsletter / mailing list (none exists; site is read-only).
- Don't claim a guest book / commenting system (intentionally not built).
- Don't claim Mambakkam has a school / hospital / police station unless you've verified — small villages often share services with adjacent panchayats.
- Don't claim diaspora numbers or "Mambakkam community in X city" — anecdotal at best.
- Don't claim partnership with the Gram Panchayat or any government body (it's an independent volunteer site).
- Don't claim Siva is the "founder of StudyBuddy" in any commercial sense — StudyBuddy is one of his projects; the site's professional chapter lists products and services without positioning him as a CEO / founder.

---

## A note on the Work / Services chapter (when promo touches Siva's professional side)

The Work and Services pages exist because the site is village-first, and Siva is one person from the village whose work is worth showcasing. They are intentionally **downstream** of the village identity — never the front door.

When a promo deliverable is specifically about Siva's professional work (a LinkedIn post about a service offering, a referral to a client, etc.), it should:

- Acknowledge the village in the framing if possible (a one-line "from Mambakkam village in Tamil Nadu" beats a generic engineer bio).
- Link to the relevant `/work/<product>` or `/services` page, not just the homepage.
- Avoid making the village seem like a personal branding device. The village is real; the professional chapter is a thin layer.

If a piece can't honour the village-first framing (e.g. a corporate RFP response), don't link the site at all — link to LinkedIn instead. The website is for audiences who can sit with the village context for 30 seconds before getting to the engineer.

---

## Useful URLs + facts to cite

- **Live site:** `https://mambakkam.net`
- **Founder / site author:** Sivakumar Mambakkam, Enterprise Architect
- **LinkedIn:** `https://www.linkedin.com/in/sivamambakkam`
- **Tech stack (only if asked):** Astro 5 + AstroWind template + Tailwind CSS + Leaflet (OpenStreetMap); hosted on Hetzner Cloud, fronted by Cloudflare.
- **Companion / commercial site:** `https://demo.usestudybuddy.com` (one of the products in the Work chapter).

---

## Audience translation matrix

Different audiences need different framings of the same site. When asking Claude.ai for promo material, **always specify the audience**:

| Audience | Lead with | Bury / drop |
|---|---|---|
| Diaspora | "Your village now has a corner of the web" | Engineering bio, service offerings |
| Heritage / cultural visitor | "Four temples, the Palar river basin, ~45 km east of Vellore" | The Work / Services chapter entirely |
| Community member / future contributor | "Send us photos; we'll add them to the People collection" | Anything sounding commercial |
| Tamil-language press | Tamil headline lead, then English context | Western tech-stack name-drops |
| Indian English-language press | Village heritage angle + the "village-first not personal-portfolio" framing | Tone-down the engineer chapter — it dilutes the heritage story |
| Recruiter / hiring manager | Enterprise Architect with X years on distributed systems, link to `/services` | Long village pages — point at LinkedIn instead |
| Potential professional client | Specific service (Enterprise Architecture / Distributed Systems / Cloud Platforms), link to `/services` then the homepage as proof of depth | Long village pages unless they ask |

---

*This doc is updated as the village or the site evolves. If you find
yourself correcting Claude.ai with the same fact twice across different
chats, that fact belongs here. The next promo-prompt iteration should
be one step shorter, not one fact longer.*
