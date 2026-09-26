# Custom templates (`.tpl`)

Ready-made **GTM custom templates** — the frequently-reused own-code templates behind several of
the patterns in [`../SKILL.md`](../SKILL.md). Each `.tpl` file is a complete template export in
GTM's `___SECTION___` format (the format produced by the Template Editor's **Export** and consumed
by **Import**, and the same source that lives inside a container's `customTemplate[].templateData`
blob).

These serve two purposes:

1. **Part of the skill.** When you ask Claude to build a container that needs one of these (an
   ID-Lookup variable, a Firestore writer, a consent mapper), it has the real template source to
   embed as a `customTemplate[]` entry — not just a description.
2. **Separately downloadable.** Grab any `.tpl` on its own and import it straight into GTM.

## What's here

| file | display name | `INFO.type` | context | what it does |
| --- | --- | --- | --- | --- |
| `id-lookup.tpl` | ID Lookup | `MACRO` (variable) | WEB | Returns the correct account/tracking ID for the current context by evaluating an ordered set of rules — debug-mode override, non-production rules, and production lookups by custom variable or by hostname (with optional `www.` stripping). The keystone of a one-container-many-markets setup (**SKILL.md pattern 1**). First matching rule wins. |
| `write-to-firestore.tpl` | Hephaestus - Write to Firestore | `TAG` | SERVER | Writes a set of attributes to a Firestore document. Two modes: **Replace entire document**, or **Edit or add** (per-attribute "overwrite if exists" control, reading the existing doc first). Needs the `access_firestore` (`read_write`) and `logging` permissions declared in the template. |
| `consent-from-buyer-marketing.tpl` | buyer_accepts_marketing → consent | web template variable | WEB | Maps a boolean `buyer_accepts_marketing` field (e.g. a Shopify webhook value) to a Google Consent Mode v2 state object — granting `ad_storage`, `ad_user_data`, `ad_personalization`, `analytics_storage`, `personalization_storage` on consent, with `functionality_storage` / `security_storage` always granted. |

All three are **own-code** templates (their `INFO` carries the placeholder `"id": "cvt_temp_public_id"`,
not a `galleryReference`), so a tag/variable that uses one is encoded
`cvt_<containerId>_<templateId>` — see the encoding rule below.

## Import into GTM directly

- **Template Editor:** GTM → *Templates* → *New* (Tag or Variable template) → ⋮ menu → **Import**,
  then pick the `.tpl` file.
- The template appears under your container's own templates and can be added like any tag/variable.

`write-to-firestore.tpl` is a **server** template — import it in a **Server** container's Template
Editor. `id-lookup.tpl` and `consent-from-buyer-marketing.tpl` are **web** templates.

## Use one inside a container JSON (the `customTemplate[]` workflow)

To add one of these to a container export that Claude is building or editing:

1. **Add the `customTemplate[]` entry.** Create an entry whose `templateData` is the **entire,
   byte-exact contents of the `.tpl` file** (don't hand-edit it — the sandboxed JS is validated by
   GTM). Give it a fresh `templateId` (`scripts/next_id.py`) and the container's `accountId` /
   `containerId`. Since these are own-code, there is **no** `galleryReference`.
2. **Encode the consuming entity's `type`** as `cvt_<containerId>_<templateId>` — the own-code form
   (Gallery templates would use `cvt_<galleryTemplateId>`; these have no gallery id). See
   [`../references/custom-templates.md`](../references/custom-templates.md).
3. **Add the tag/variable** that uses it, with its parameters matching the template's
   `___TEMPLATE_PARAMETERS___` keys.
4. **Validate** with `scripts/validate.py` — it flags any `cvt_*` type with no matching
   `customTemplate[]` entry.

> Add the `customTemplate[]` entry **before** the tag/variable that references it, or import fails
> with "unknown template".

## Adding your own

Drop any exported `.tpl` in this folder and add a row to the table above (display name from its
`___INFO___.displayName`, `INFO.type`, `containerContexts`, and a one-line description). Keep the
file exactly as GTM exported it. Don't commit templates that embed real IDs, tokens, or hostnames
— template *inputs* (configured per container) are fine, hard-coded secrets are not.
