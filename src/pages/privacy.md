---
title: 'Privacy Policy'
layout: '~/layouts/MarkdownLayout.astro'
---

_Last updated_: August 24, 2026

This Privacy Policy explains what information is collected and how it is used across
**mambakkam.net** and the personal software projects operated under **WeGoFwd2020** by
Sivakumar Mambakkam. Contact: [wegofwd2020@gmail.com](mailto:wegofwd2020@gmail.com).

## This website

mambakkam.net is a static personal/portfolio website. It does not require an account,
does not run advertising, and does not sell personal data. Pages are served through a
content-delivery network (Cloudflare), which processes standard request metadata (such as
IP address and user agent) to deliver and protect the site. If you email an address listed
on the site, your message and email address are used only to reply to you.

## WeGoFwd2020 applications and Google user data

Some WeGoFwd2020 tools are personal, single-operator utilities that the operator authorizes
to access their **own** Google account data through Google APIs. The relevant tool here is a
private **expense-capture utility** used by the account owner (`wegofwd2020@gmail.com`) only.

**What Google data is accessed.** With the account owner's explicit OAuth consent, the tool
reads the owner's **Gmail messages** (read-only) in order to identify bills, receipts, and
invoices and extract expense details (merchant, date, amount, category).

**How the data is used.** The extracted expense information is written to a **private ledger
stored locally** on the owner's own machine. The tool is used solely by, and for, the
account owner to organize their own expenses. The data is **not** used for advertising, is
**not** sold, and is **not** shared for any purpose unrelated to this feature.

**Automated processing.** To classify and extract fields, the content of candidate expense
emails is sent to the **Anthropic (Claude) API** for automated processing. Anthropic acts as
a processing provider for this step; the data is transmitted over an encrypted connection and
used only to return the extracted result. No other third parties receive the data.

**No human access.** No person other than the account owner reads the Gmail content, except
as required by law.

**Storage and retention.** The ledger and any cached tokens live on the owner's local machine
(access tokens are stored with restrictive file permissions). There is no external server that
stores the owner's Gmail content. The owner can revoke the tool's access at any time from
[Google Account permissions](https://myaccount.google.com/permissions), and can delete the
local ledger to remove stored data.

### Limited Use disclosure

The use and transfer of information received from Google APIs to any other app adhere to the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including the **Limited Use** requirements. Specifically, Google user data is used only to
provide or improve the user-facing feature described above (expense capture for the account
owner), is not transferred or used for serving advertisements, is not sold, and is not used
for any purpose other than that feature except as strictly necessary to provide it or where
required by law.

## Your choices

- Revoke the application's access to your Google account at
  [myaccount.google.com/permissions](https://myaccount.google.com/permissions).
- Contact [wegofwd2020@gmail.com](mailto:wegofwd2020@gmail.com) with any privacy question or
  to request deletion of data held about you.

## Changes to this policy

This policy may be updated from time to time; the "Last updated" date above reflects the most
recent change.
