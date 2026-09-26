# Reference: custom templates (`customTemplate[]`) and `cvt_*` encoding

Custom templates are tag/variable/client/transformation definitions that aren't built into
GTM — either installed from the Community Template Gallery or written as own code.

## The entry

Each `customTemplate[]` element has:

- `templateId` — numeric string, unique in the container.
- `name`, `accountId`, `containerId`, `fingerprint`.
- `galleryReference` — present **iff** installed from the Gallery:
  `{host, owner, repository, version, signature, galleryTemplateId?}`.
- `templateData` — a long string with `___SECTION___`-delimited parts:
  `___TERMS_OF_SERVICE___`, `___INFO___`, `___TEMPLATE_PARAMETERS___`,
  `___SANDBOXED_JS_FOR_WEB_TEMPLATE___` or `___SANDBOXED_JS_FOR_SERVER___`,
  `___WEB_PERMISSIONS___` or `___SERVER_PERMISSIONS___`, `___TESTS___`, `___NOTES___`.

The parsed `___INFO___` declares `type` (`TAG` / `MACRO` / `CLIENT` / `TRANSFORMATION`) and
`containerContexts` (`["WEB"]` or `["SERVER"]`).

## The encoding rule (the thing that breaks imports)

A tag/variable/client that **uses** a custom template has a `cvt_*` `type` in one of two forms:

| template source | `type` value | example |
| --- | --- | --- |
| Gallery **with** `galleryTemplateId` | `cvt_<galleryTemplateId>` | `cvt_5TP8W` |
| Own code, or gallery **without** `galleryTemplateId` | `cvt_<containerId>_<templateId>` | `cvt_2222222_154` |

So to add a tag on an installed template: read the template's `galleryReference.galleryTemplateId`
(if present) → `cvt_<that>`; else `cvt_<containerId>_<templateId>`. If the template isn't in the
container yet, add the `customTemplate[]` entry **first** or the import fails with "unknown template".

`scripts/validate.py` builds this map and flags any `cvt_*` type with no matching template.

## Don't hand-edit `templateData`

The sandboxed JS plus the `signature` in `galleryReference` are how GTM validates Gallery
integrity. Copy whole `customTemplate[]` entries between containers; never surgically patch the
sandboxed JS or alter the signature.

## Templates you'll meet in this multi-market / sGTM architecture

Recognizable by gallery id (→ `cvt_<id>`):

- **Cookie Monster** (Simo Ahava, `PH3XM`) — prolong non-Google cookies, HttpOnly (pattern 6).
- **sha256 Hasher** (Simo Ahava, `NFBZ7`) — hash PII before CAPI (pattern 14).
- **Unique Event ID** (Stape, `M63B8`) — zero-param UUID per event (pattern 9).
- **JSON converter** (Stape, `MQRVK`) — `parse`/`stringify` server-side (pattern 12).
- **Facebook Conversion API / Meta Pixel** (Stape / Facebook) — CAPI + web pixel.
- **TikTok Pixel / TikTok Events API** (Stape) — web + S2S.
- **GTM Consent State** (Ayudante, `M6BW3`) — capture consent object for forwarding (pattern 17).

Own-code templates (→ `cvt_<containerId>_<templateId>`) commonly include an **ID Lookup**
(hostname→ID, pattern 1), a **Durable ID Resolver** (browser↔server freshest cookie, pattern 7),
a **JSON.parse** helper, and regional S2S/SEM tags. Regional ad platforms (Sklik/SEM, Heureka,
on-site search, CRO tools) usually ship as community templates and often as a web-pixel template
plus a separate server S2S variant.

## Ready-made `.tpl` sources in `../templates/`

Complete own-code template exports (the `.tpl` `___SECTION___` format — same content that fills a
`templateData` blob) live in [`../templates/`](../templates/), so a build can embed the real source
instead of a reconstruction: **ID Lookup** (`id-lookup.tpl`, pattern 1), a **Write to Firestore**
server tag, and a **buyer_accepts_marketing → consent** web variable. To use one, add a
`customTemplate[]` entry whose `templateData` is the file's **byte-exact** contents (fresh
`templateId`, this container's `accountId`/`containerId`, no `galleryReference`), then reference it
as `cvt_<containerId>_<templateId>`. They're also directly importable via GTM's Template Editor.
See [`../templates/README.md`](../templates/README.md).
