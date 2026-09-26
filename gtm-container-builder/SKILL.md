---
name: gtm-container-builder
description: Read, write, validate, and edit Google Tag Manager (GTM) container JSON exports, Web and Server-side. Use when the user mentions a GTM export, GTM-XXXXXX container, containerVersion, exportFormatVersion, sGTM / server containers, first-party serving, scaffolding or importing a container, validating reference integrity, diffing or renaming a container, or custom templates (cvt_*). Also covers multi-market single-container setups (hostname->ID Lookup variables, market-scoped triggers), regex-consolidated ecommerce triggers, source-gating, browser/server event_id dedup, cookie prolongation for non-Google click IDs (CookieMonster, freshest-cookie resolvers, ITP), MCC-vs-sub-account Google Ads IDs, centralized gtcs/gtes settings, the GA4->sGTM hit as a cross-vendor transport bus, vendor event-name mapping (regex or smm/remm tables), server-side PII hashing before CAPI, first-party loader (gtm_client), edge geo (vr / headers), and consent-state forwarding. Tags: GA4, Google Ads, Floodlight, Meta CAPI, TikTok, UET.
---

# GTM Container Builder

A skill for working with GTM container JSON exports — the format produced by **Admin → Export Container** in the GTM UI, and consumed by **Admin → Import Container**.

There are two modes:

- **Edit an existing export** — open a `.json` the user uploaded, change/add/remove entities, save it back as a valid importable file.
- **Build a new container from scratch** — scaffold a fresh `containerVersion` shell and fill it with tags, triggers, variables that the user can import into a brand-new container or workspace.

Both modes share the same rules. The single most important thing to get right is **referential integrity**: GTM containers are a graph (tags reference triggers, triggers reference variables, variables reference variables, tags reference other tags via setup/teardown), and a broken reference causes import to fail or runtime to break silently.

## Step 0 — Orient before doing anything

Before reading any tag or making any edit, always check the file's identity:

```python
data      = json.load(open(path))
container = data["containerVersion"]
ctx       = container["container"]["usageContext"][0]    # "WEB" or "SERVER"
public_id = container["container"]["publicId"]           # "GTM-XXXXXX"
account   = container["container"]["accountId"]          # numeric string
cid       = container["container"]["containerId"]        # NUMERIC, not GTM-XXXXXX
name      = container["container"]["name"]
tagging   = container["container"].get("taggingServerUrls")  # SERVER only
features  = container["container"]["features"]           # supportClients, supportTransformations…
```

**`usageContext` decides everything that follows.** WEB and SERVER containers have different valid tag types, different valid variable types, and different available built-in variables. SERVER containers also have `client[]` and `transformation[]` arrays that WEB containers never use; their `container.features` will have `supportClients: true` and `supportTransformations: true`. If you skip this step you will produce a file that GTM rejects on import.

Other top-level fields you'll see on every real export:

- `exportFormatVersion` — currently `2`. Keep it.
- `exportTime` — informational, regenerated on next export.
- `containerVersion.path` — `accounts/<accountId>/containers/<containerId>/versions/<n>`. Internally derived; don't fight it but keep accountId/containerId consistent if you edit it.
- `containerVersion.containerVersionId` — usually `"0"` for workspace exports, a numeric string for published versions.
- `containerVersion.tagManagerUrl` — convenience link, informational.
- `container.tagIds` — array, typically `["GTM-XXXXXX"]` matching `publicId`.
- `container.fingerprint`, `containerVersion.fingerprint`, and a `fingerprint` on every entity — millisecond-ish timestamps GTM uses for change detection. Safe to leave, regenerate, or omit; GTM rewrites them on import.

Run `scripts/inspect.py <file>` to get a one-screen summary (context, name, counts of each entity type, taggingServerUrls, folders, custom-template inventory). Always do this first on any uploaded export before doing anything else with it.

## The two workflows

### Editing an existing export

1. **Inspect first.** Run `scripts/inspect.py` to see what's inside. Don't assume from the filename.
2. **Locate the entities you'll touch.** Tags, triggers, and variables are independent arrays — modifications to one usually require updates to others. If you're adding a new tag that fires on a new event, you'll likely add both a `tag` entry and a `trigger` entry, and the tag's `firingTriggerId` must point at the new trigger's `triggerId`.
3. **Preserve the existing `accountId` and `containerId`** everywhere. Every entity has its own copies of these; they must all match the container they live in.
4. **Use unique numeric IDs.** Run `scripts/next_id.py <file>` to get the next free `tagId` / `triggerId` / `variableId` / `clientId` / `folderId` / `templateId` / `zoneId`. Reusing an existing ID will overwrite or corrupt.
5. **Don't worry about `fingerprint`.** It's a millisecond timestamp GTM uses for change detection. When the user imports your edited file, GTM regenerates fingerprints. You can leave the old values alone, update them to `str(int(time.time()*1000))`, or omit the field — all three work.
6. **Validate before handing it back.** Run `scripts/validate.py <file>` to catch broken references, ID collisions, and missing required fields.

### Building a new container from scratch

1. **Ask for the context.** WEB or SERVER? You can't infer this.
2. **Scaffold the shell** with `scripts/scaffold.py --context WEB|SERVER --name "..." --public-id GTM-XXXXXX --account-id ... --container-id ...`. If the user doesn't know the IDs yet, use placeholders — but tell them they must replace them before import, or import into a real container that will overwrite them.
3. **Add entities.** Use IDs starting at `"1"` and increment.
4. **Validate.** Same `scripts/validate.py` as above.

The user can then import the result via GTM UI → Admin → Import Container, choosing "Overwrite" or "Merge".

## Mental model in 60 seconds

A GTM export is a single JSON file wrapping a `containerVersion`:

```
containerVersion
├── container          — metadata (accountId, containerId, publicId, usageContext, features, tagIds, taggingServerUrls)
├── tag[]              — the things that fire (HTML snippets, GA4 events, pixels, Floodlight, Ads conversions, CAPI…)
├── trigger[]          — the conditions that make tags fire
├── variable[]         — named values that tags and triggers read
├── folder[]           — organizational only, optional (`folderId` ↔ entities' `parentFolderId`)
├── builtInVariable[]  — GTM's predefined variables that are "enabled" in this container
├── customTemplate[]   — tag/variable/client/transformation templates (Gallery-installed or own code)
├── zone[]             — WEB only, optional — sub-container delegation
├── client[]           — SERVER only — incoming-request handlers (gaaw_client, custom)
└── transformation[]   — SERVER only — modify event data before tags fire
```

Inside each entity, configuration lives in a recursive `parameter[]` structure where each parameter is one of:

```
{ "type": "TEMPLATE",          "key": "...",  "value": "string with {{variable name}}" }
{ "type": "BOOLEAN",           "key": "...",  "value": "true"|"false" }
{ "type": "INTEGER",           "key": "...",  "value": "42" }
{ "type": "LIST",              "key": "...",  "list": [ { type:"MAP", map:[...] }, ... ] }
{ "type": "MAP",                              "map":  [ Parameter, Parameter, ... ] }
{ "type": "TAG_REFERENCE",     "key": "...",  "value": "<tag NAME>", "isWeakReference": false }
{ "type": "TRIGGER_REFERENCE",                "value": "<trigger ID>" }
```

**TEMPLATE values use `{{variable name}}` to interpolate variables** — this is the single most important syntax convention. The name inside braces must match the `name` field of a variable or built-in variable. Spaces, dots, hyphens are all fine inside the braces. See `references/parameter-format.md` for the full grammar.

**References are tracked these ways**, and they trip people up:

| Reference                     | What it stores               | Example                              |
| ----------------------------- | ---------------------------- | ------------------------------------ |
| `firingTriggerId` (on tag)    | numeric `triggerId` strings  | `["327"]`                            |
| `blockingTriggerId` (on tag)  | numeric `triggerId` strings  | `["105"]`                            |
| `parentFolderId` (on tag/trigger/variable) | numeric `folderId` string | `"70"`                  |
| `setupTag` / `teardownTag` (on tag) | tag NAME inside an object | `[{"tagName":"GA4 - Config","stopOnSetupFailure":true}]` |
| `TRIGGER_REFERENCE` (in list) | numeric `triggerId` string   | `{"type":"TRIGGER_REFERENCE","value":"374"}` |
| `TAG_REFERENCE` (in list)     | the tag's `name` string      | `{"type":"TAG_REFERENCE","value":"campaign \| FB \| Lead form","isWeakReference":false}` |
| `{{var name}}` in TEMPLATE    | the variable's `name` string | `"{{Page Hostname}}"`                |
| `customTemplate.templateId` ↔ `cvt_*` tag/var type | see custom-template section | `templateId: "188"` ↔ `cvt_<containerId>_188` |

Triggers are referenced by **ID**. Tags are referenced by **name** (for sequencing). Variables are referenced by **name in `{{...}}` syntax**. Folders are referenced by **ID**. Don't mix them up.

### Reserved built-in trigger IDs

A small set of numeric IDs in the high (≥ 2,000,000,000) range are reserved built-in triggers that **never appear as objects in `trigger[]`** but are referenced directly by tags' `firingTriggerId`:

| ID            | Meaning (WEB/SERVER)                          |
| ------------- | --------------------------------------------- |
| `2147479553`  | All Pages (Page View) — WEB                   |
| `2147479572`  | Initialization - All Pages — WEB              |
| `2147479573`  | Consent Initialization - All Pages — WEB      |
| `2147479574`  | All Events / Any Event — SERVER               |

If you see one of these in a `firingTriggerId` and you can't find a matching trigger in `trigger[]`, that's expected — it's a built-in. `validate.py` recognizes these and won't flag them.

### The magic `{{_event}}` variable

Both WEB and SERVER containers use `{{_event}}` inside `customEventFilter[].parameter` to match the incoming event name. You will see this pattern on **every** `CUSTOM_EVENT` trigger:

```json
{
  "type": "CUSTOM_EVENT",
  "customEventFilter": [{
    "type": "EQUALS",
    "parameter": [
      {"type": "TEMPLATE", "key": "arg0", "value": "{{_event}}"},
      {"type": "TEMPLATE", "key": "arg1", "value": "add_to_cart"}
    ]
  }]
}
```

`{{_event}}` is a runtime-only built-in — it does **not** need to appear in `builtInVariable[]`. Use `MATCH_REGEX` with a pipe (`a|b|c`) to fire one trigger on multiple events.

## Custom templates: gallery vs own-code

Custom templates live in `customTemplate[]`. Each entry has:

- `templateId` — numeric string, unique within the container
- `name`, `accountId`, `containerId`, `fingerprint`
- `galleryReference` — present iff the template was installed from the Community Template Gallery; structured `{host, owner, repository, version, signature, galleryTemplateId?}`
- `templateData` — a long string holding the actual template definition, organized into named sections delimited by `___SECTION___`:
  - `___TERMS_OF_SERVICE___`, `___INFO___`, `___TEMPLATE_PARAMETERS___`, `___SANDBOXED_JS_FOR_WEB_TEMPLATE___` or `___SANDBOXED_JS_FOR_SERVER___`, `___WEB_PERMISSIONS___` or `___SERVER_PERMISSIONS___`, `___TESTS___`, `___NOTES___`

The `INFO` section (parsed JSON) declares the template's `type` (one of `TAG`, `MACRO`, `CLIENT`, `TRANSFORMATION`) and `containerContexts` (`["WEB"]` or `["SERVER"]`).

**The critical encoding rule:** tags, variables, and clients that *use* a custom template have a `type` field of `cvt_*` in one of two forms, depending on whether the template is Gallery-installed:

| Template source                                      | Tag/var/client `type` value                        | Example                            |
| ---------------------------------------------------- | -------------------------------------------------- | ---------------------------------- |
| Gallery (has `galleryReference.galleryTemplateId`)   | `cvt_<galleryTemplateId>`                          | `cvt_5TP8W` (Facebook CAPI)        |
| Own code, or gallery without `galleryTemplateId`     | `cvt_<containerId>_<templateId>`                   | `cvt_31573773_188`                 |

So when adding a new tag that uses an installed custom template, derive the `type` value from the custom template's `galleryReference.galleryTemplateId` if present, otherwise from `<containerId>_<templateId>`. If you don't have the template in this container yet, you must add the `customTemplate[]` entry first.

**Don't hand-edit `templateData`.** The sandboxed JS plus the `signature` in `galleryReference` are how GTM validates Gallery integrity. Copy whole `customTemplate[]` entries between containers; don't surgically patch the sandboxed JS.

**Ready-made own-code templates live in `templates/`.** That folder holds complete `.tpl` exports (the same `___SECTION___` format that fills a `templateData` blob) for the reusable own-code templates behind these patterns — e.g. **ID Lookup** as a WEB/SERVER pair (`id-lookup-web.tpl` keying off `getUrl("host")`, `id-lookup-server.tpl` keying off `getEventData('page_hostname')` — the pattern-1 hostname→ID variable for each context), a **Write to Firestore** server tag, and a **buyer_accepts_marketing → consent** web variable. When a build needs one, read the matching `.tpl` and embed its **byte-exact** contents as a new `customTemplate[]` entry (fresh `templateId`, this container's `accountId`/`containerId`, no `galleryReference` since they're own-code), then reference it as `cvt_<containerId>_<templateId>`. The files are also directly importable in GTM's Template Editor. See `templates/README.md` for the catalogue and the full `.tpl` → `customTemplate[]` workflow.

## Where to read more

The catalogue files in `references/` document every type code you'll meet in real exports:

| Read this when you need…                                    | File                              |
| ----------------------------------------------------------- | --------------------------------- |
| The full top-level shell, WEB vs SERVER differences         | `references/container-shell.md`   |
| How `parameter[]` works in detail, all value types          | `references/parameter-format.md`  |
| Tag types (`gaawe`, `html`, `googtag`, `flc`, `awct`, `cvt_*`…) | `references/tag-types.md`     |
| Trigger types and filter operators                           | `references/trigger-types.md`     |
| Variable types (`v`, `c`, `jsm`, `smm`, `remm`, `ed`, `sgtmk`…) | `references/variable-types.md` |
| `client[]` and `transformation[]` (SERVER only)              | `references/server-specific.md`   |
| Anatomy of the `templateData` blob in custom templates       | `references/custom-templates.md`  |
| Ready-made own-code `.tpl` templates to embed or import       | `templates/README.md`             |

Each of those reference files links into `examples/` where one real-world JSON example of each entity type is stored. When asked to produce a specific tag/trigger/variable type, **read the matching example first** — it shows the exact field set you need, in the order GTM expects.

## Helper scripts

All scripts live in `scripts/` and run on Python 3 with the standard library only (no installs):

```bash
# Summary of what's in a container — always run this first
python scripts/inspect.py path/to/GTM-XXXXX.json

# Validate structure, reference integrity, ID uniqueness
python scripts/validate.py path/to/GTM-XXXXX.json

# Get the next free numeric ID for each entity type
python scripts/next_id.py path/to/GTM-XXXXX.json

# Scaffold an empty WEB or SERVER container
python scripts/scaffold.py --context WEB \
    --name "My container" --public-id GTM-AAAA111 \
    --account-id 1234567 --container-id 7654321 \
    > new-container.json

# Compare two exports (e.g. before/after edit)
python scripts/diff_containers.py old.json new.json
```

`validate.py` is the one to run before handing any output back to the user. It checks:

- All entities carry matching `accountId` / `containerId`
- No duplicate IDs within `tag[]`, `trigger[]`, `variable[]`, `client[]`, `folder[]`, `customTemplate[]`, `zone[]`
- Every `firingTriggerId` / `blockingTriggerId` / `TRIGGER_REFERENCE` points at an existing trigger **or** is one of the reserved built-in IDs (`2147479553`, `2147479572`, `2147479573`, `2147479574`)
- Every `TAG_REFERENCE` and every `setupTag` / `teardownTag` `tagName` points at an existing tag
- Every `{{variable name}}` in TEMPLATE values resolves to an existing variable or built-in variable (excluding the special runtime `{{_event}}`)
- Every `cvt_*` type value resolves to a `customTemplate[]` entry under the correct encoding rule
- Every `parentFolderId` points at an existing `folder[]` entry
- WEB-only types don't appear in SERVER containers and vice versa (`flc`, `fls`, `awct`, `gclidw`, `gaawe`, `googtag`, `html` are WEB; `sgtmadsct`, `sgtmadscl`, `sgtmadsremarket`, `sgtmgaaw` are SERVER; `client[]` / `transformation[]` are SERVER-only)
- Required fields (`name`, `type`, `parameter` where applicable) are present

## Editing pattern that works

When the user asks for a specific change ("add a GA4 event tag for `add_to_cart`"), the reliable sequence is:

1. **Run inspect.py** — confirm context, see existing GA4-related entities to copy style from.
2. **Find a similar tag already in the file** — same product (GA4, FB, Floodlight, etc.), similar shape (event tag, not config tag) — and read its full JSON. This is your template.
3. **Determine the trigger.** Does a `CUSTOM_EVENT` trigger for `add_to_cart` already exist? Search `trigger[]` for one whose `customEventFilter` matches that event name on `{{_event}}`. If not, create one.
4. **Get fresh IDs** with `next_id.py` for everything new.
5. **Build the new entity by patterning on the existing similar one** — keep `accountId`, `containerId`, and (if it makes sense) `parentFolderId` from siblings, vary only the meaningful fields (`name`, `eventName`, `firingTriggerId`, parameter values).
6. **Append to the relevant array**, don't rewrite the whole file.
7. **Validate.**
8. **Hand back the updated file.**

When asked "add a tag that does X" and the container has no precedent, fall back to the example in `examples/` for the same `type` code.

## Tag-level extras worth knowing

Real-world tags carry these optional fields. None are required, but they change semantics when set:

- `tagFiringOption` — `"ONCE_PER_EVENT"` (default for most), `"ONCE_PER_LOAD"`, or `"UNLIMITED"`. Floodlight tags typically use `ONCE_PER_LOAD`.
- `priority` — `{"type":"INTEGER","value":"99999"}`. Higher fires earlier when multiple tags share a trigger. GA4 config tags and Conversion Linkers are usually set to `99999`–`100000` so they fire first.
- `paused` — `true` means the tag exists but won't fire. Useful for staged rollouts.
- `liveOnly` — if `true`, tag fires only in the live container, not in Preview.
- `notes` — free-text. Surface this to users; ignore it for logic.
- `monitoringMetadata` — `{"type":"MAP"}` (empty) by default. Can carry custom labels for monitoring; leave the empty MAP if you don't need it (GTM expects the key to exist on many tag types).
- `setupTag` / `teardownTag` — sequencing. Each is an array of `{"tagName": "<NAME>", "stopOnSetupFailure": true?}`. The setup tag fires *before* this tag; teardown fires *after*. References by tag **name**, not ID. Common pattern: a `*-Config` HTML tag is set as the setupTag of every product-specific event tag, so the SDK is initialised exactly once before each event.
- `consentSettings` — see below. Almost always present on WEB tags.

## Consent settings

`consentSettings` controls whether the tag is gated by Google Consent Mode v2. Shape:

```json
"consentSettings": {
  "consentStatus": "NEEDED",
  "consentType": {
    "type": "LIST",
    "list": [
      {"type": "TEMPLATE", "value": "ad_storage"},
      {"type": "TEMPLATE", "value": "analytics_storage"}
    ]
  }
}
```

Three values for `consentStatus`:

- `NOT_SET` — no enforcement (tag fires regardless). Common on **SERVER** containers (consent is enforced before the request leaves the browser, not server-side).
- `NEEDED` — tag is gated; the `consentType.list` lists the consent signals required. Most common values seen in the wild: `ad_storage`, `analytics_storage`, `ad_user_data`, `ad_personalization`, `personalization_storage`, `functionality_storage`, `security_storage`.
- `NOT_NEEDED` — explicit "this tag is essential, do not gate it".

**Don't drop `consentSettings` silently** — that effectively downgrades a `NEEDED` tag to "fires without consent". If you're unsure, copy the value from a sibling tag of the same product (e.g. all Google Ads conversion tags typically need `ad_storage`).

## Variable-level extras

- `formatValue` — usually `{}` (empty). Holds optional transformation rules; e.g. `{"convertUndefinedToValue": {"type":"TEMPLATE","value":"0"}}` to coerce `undefined` to `"0"`. Other keys: `convertNullToValue`, `convertTrueToValue`, `convertFalseToValue`, `caseConversionType` (`"LOWERCASE"` / `"UPPERCASE"`).
- `parentFolderId` — see folder section.
- `notes` — free-text.

## Trigger-level extras

Each trigger type uses a different set of fields. The most common shapes seen in practice:

| Trigger type        | Filter field name      | Other notable fields                                  |
| ------------------- | ---------------------- | ----------------------------------------------------- |
| `CUSTOM_EVENT`      | `customEventFilter`    | (always uses `{{_event}}` as `arg0`)                  |
| `PAGEVIEW` / `DOM_READY` / `WINDOW_LOADED` / `HISTORY_CHANGE` / `INIT` / `CONSENT_INIT` | `filter`               | optional `autoEventFilter` for variants               |
| `SERVER_PAGEVIEW`   | `filter`               | SERVER only                                           |
| `LINK_CLICK` / `CLICK` / `FORM_SUBMISSION` | `filter`               | `waitForTags`, `waitForTagsTimeout`, `checkValidation`, `uniqueTriggerId`     |
| `TIMER`             | `autoEventFilter`      | `eventName` (`"gtm.timer"`), `interval` (ms), `limit` |
| `ELEMENT_VISIBILITY`| `filter`               | `selectorType`, `elementSelector`, `visibilityRatio`, etc. |
| `SCROLL_DEPTH`      | `filter`               | `verticalThresholdsPercent` / `horizontalThresholdsPercent`, `verticalThresholdUnits` |
| `TRIGGER_GROUP`     | n/a                    | references child triggers via `parameter` LIST        |

All filter entries follow the same shape: `{"type": <OPERATOR>, "parameter":[{"type":"TEMPLATE","key":"arg0","value":"..."}, {"type":"TEMPLATE","key":"arg1","value":"..."}]}`. Add `{"type":"BOOLEAN","key":"negate","value":"true"}` to invert; `{"type":"BOOLEAN","key":"ignore_case","value":"true"}` for case-insensitive string matching.

## Server-side specifics

`client[]` entries handle incoming requests on the tagging server. Two patterns dominate:

1. **`gaaw_client`** — the official GA4 client. Key parameters: `cookieManagement` (`"server"`/`"js"`/`"manual"`), `cookieName` (default `"FPID"`), `cookieDomain` (`"auto"`), `cookieMaxAgeInSec`, `cookiePath`, `activateDefaultPaths`, `migrateFromJsClientId`. Setting `cookieManagement: "server"` is the core of first-party serving — see "Real-world patterns → First-party serving" below.
2. **`cvt_*` custom-template clients** (e.g. Stape's "Data Client", which has type `cvt_<containerId>_<templateId>` because it's typically own-code). Same encoding rule as tags.

Server-side GA4-event-receiving is almost always handled by a `gaaw_client` parsing the incoming hit and emitting events; downstream tags (FB CAPI, Reddit CAPI, Microsoft UET CAPI, Google Ads server `sgtmadsct`, Floodlight equivalents) fire on `CUSTOM_EVENT` triggers matching those event names.

`transformation[]` runs *between* the client parsing a request and tags firing — used to enrich, hash, or strip event data. Same `cvt_*` encoding for custom-template transformations.

## Real-world patterns: multi-market e-commerce + sGTM + first-party serving

Patterns distilled from production multi-country e-commerce setups — one WEB container serving several country domains, paired with a SERVER container doing first-party serving. The whole point of these patterns is to stay **DRY**: one tag per platform instead of one-per-market. When you build or edit an entity in a container that shows these patterns, follow them rather than inventing per-market duplicates. All values below are placeholders — never hard-code a real ID, hostname, or conversion label.

### 1. One container, many markets — the hostname → ID Lookup variable

The keystone of a multi-market container. A single own-code custom-template variable (`INFO.type: MACRO`, works in both WEB and SERVER) maps the **current hostname → the right ID for that market**, so one tag serves every country. The same template is instantiated many times, once per ID it needs to resolve.

Instances seen in practice: GA4 Measurement ID, Google Ads Conversion ID, Meta Pixel ID, Meta Catalog Suffix, Meta Test Event Code, analytics/heatmap IDs, on-site-search IDs, Merchant Center ID / feed country / feed language, and — critically — the **Server Container URL** (see pattern 5).

The parameter shape is a hostname lookup table:

```json
{"type":"BOOLEAN","key":"productionHostnameLookupCheckbox","value":"true"},
{"type":"BOOLEAN","key":"productionHostnameLookupTableStripWWW","value":"true"},
{"type":"LIST","key":"productionHostnameLookupTable","list":[
  {"type":"MAP","map":[
    {"type":"TEMPLATE","key":"matchType","value":"equals"},
    {"type":"TEMPLATE","key":"value","value":"example.cz"},
    {"type":"TEMPLATE","key":"id","value":"<ID-FOR-CZ>"}
  ]},
  {"type":"MAP","map":[
    {"type":"TEMPLATE","key":"matchType","value":"equals"},
    {"type":"TEMPLATE","key":"value","value":"example.pl"},
    {"type":"TEMPLATE","key":"id","value":"<ID-FOR-PL>"}
  ]}
]}
```

The tag then just references the resolved value: GA4 `googtag` uses `{{ID Lookup - GA4 Measurement ID}}` as `tagId`; `gaawe` uses it as `measurementIdOverride`; Meta uses `{{ID Lookup - Meta Pixel ID}}` as `pixelId`. The config/event tags become tiny — a handful of parameters — because everything market-specific is pushed into the lookup.

**WEB vs SERVER difference:** the WEB variant keys off the page hostname (built-in). The SERVER variant can't use `{{Page Hostname}}` (it doesn't exist server-side) — it keys off the incoming event's hostname (an `ed` Event Data variable like `{{Event Data - page_hostname}}`). Same UI, different source. Keep both in sync when a market is added.

### 2. Market scoping without duplicating tags

When something genuinely applies to **one market only** (a local-market ad platform, a market-specific feed), scope by hostname rather than ID Lookup:

- **WEB:** add a trigger filter `{{Page Hostname}} EQUALS www.example.cz`, or `MATCH_REGEX www.example.cz|www.example.pl` for a couple of markets.
- **SERVER:** add `{{Event Data - page_hostname}} CONTAINS example.cz`.
- **Naming:** suffix the market-scoped entity with ` | CZ` (ISO-ish market code). Keep an un-suffixed global variant for entities that fire everywhere.

The same hostname scoping applies to **PAGEVIEW** triggers, not just custom events — you'll see `All Pages | CZ` (`{{Page Hostname}} EQUALS www.example.cz`), `All Pages | CZ/PL` (`MATCH_REGEX www.example.cz|www.example.pl`), and page-type-scoped variants like `Page View - Category | CZ` (`{{DLV - page_type}} EQUALS category` **and** hostname). Same ` | MARKET` naming.

Prefer pattern 1 (ID Lookup) whenever the same platform runs in every market — reserve hostname scoping for genuinely single-market tags, or you'll rebuild the duplication ID Lookup exists to avoid.

### 3. Regex-consolidated event triggers (ecommerce families)

Instead of N single-event `CUSTOM_EVENT` triggers, fire a whole family from one `MATCH_REGEX` trigger:

```
{{_event}}  MATCH_REGEX  ^(view_item|view_cart|add_to_cart|remove_from_cart|begin_checkout|add_shipping_info|add_payment_info)$
```

- **Anchor with `^(...)$`.** Without anchors, `add_to_cart` also matches `add_to_cart_extra`. Anchoring is the difference between a clean trigger and silent over-firing.
- **Two casings coexist because vendors disagree on event names.** GA4 / Google Ads / GA4-style downstream use **snake_case** (`view_item`, `add_to_cart`, `purchase`). Meta / CAPI-style use **PascalCase** (`PageView|ViewContent|AddToCart|Purchase|InitiateCheckout|AddPaymentInfo|AddShippingInfo|RemoveFromCart|ViewCart`). Name the triggers `... snake_case Regex` and `... PascalCase Regex` so the intent is obvious.
- **Keep single-event triggers too** for tags that must fire on exactly one event (purchase, sign_up) or that carry extra per-event filters.
- **Reality check:** production containers often have *unanchored* server-side regexes (`view_item|add_to_cart|...` with no `^(...)$`). They usually work because server event names are controlled, but they're fragile — when you touch one, anchor it. When a family also needs source-gating, the web trigger pairs the regex with `{{DLV - dl_source}} EQUALS <bridge>` (pattern 4); the server equivalent restricts by `{{Client Name}}` and/or hostname instead.
- Same trick works on a Server client trigger: an `ALWAYS` trigger filtered on `{{Client Name}} EQUALS GA4` **and** `{{Event Name}} MATCH_REGEX ...` restricts a client-scoped tag to a known event set.

### 4. Source-gating to prevent event contamination

Nearly every custom-event trigger in a robust container carries a **second filter** that confirms the event came from your intended dataLayer bridge, e.g. `{{DLV - dl_source}} EQUALS <your-bridge-source>`. Third-party scripts, plugins, and CMS add-ons routinely push events with names like `add_to_cart`; without a source gate they fire your tags with garbage payloads. Stamp a discriminator in every push from your bridge and gate on it.

Related discriminator: `eventModel.send_to` separates Google Ads gtag events from GA4 events that share a name. It's used **both ways** in practice:

- On the **Ads** path, gate positively: `{{DLV - eventModel.send_to}} CONTAINS AW-`.
- On the **GA4 / general** path, gate with the **negated** form (`CONTAINS AW-`, `negate=true`) so your GA4 or vendor tags don't double-fire on the duplicate event that gtag emits for Ads.
- You can also negate a **specific** destination (`EQUALS AW-<conversion-id>`, `negate=true`) to exclude exactly one Ads account while letting the rest through.

GA4 config events won't carry an `AW-` destination, so the positive/negative pair cleanly splits the two streams.

### 5. First-party serving, end to end

The web container and the server container have to agree on a first-party endpoint per market:

- **WEB side.** A Google Tag Configuration Settings variable (`gtcs`) centralizes shared config and sets `server_container_url = {{ID Lookup - Server Container URL}}` — so each market's Google Tag ships hits to its own first-party subdomain (e.g. `https://hub.example.cz`). The same `gtcs`/`gtes` (Event Settings) variables also centralize `user_data`, `user_id`, `page_hostname`, `ecommerce`, and the shared `event_id` (pattern 9) once, instead of repeating them on every tag. Reference them via the tag's `configSettingsVariable` / `eventSettingsVariable` keys.
- **SERVER side.** `taggingServerUrls` are the first-party subdomains of each market (not the raw `*.run.app` origin — that stays in the list as the underlying host but the first-party domains are what browsers talk to). The `gaaw_client` runs with `cookieManagement: "server"`, `cookieName: "FPID"`, a long `cookieMaxAgeInSec` (~2y), and `migrateFromJsClientId: true`, so the Google identity cookie is written **server-side as first-party HttpOnly** — sidestepping ITP's 7-day cap on JS-set cookies.

Net split of responsibility: the **Google** identity cookie (FPID) is handled by `gaaw_client`; **every other** click/browser cookie is handled by CookieMonster (next pattern). The `gaaw_client` config seen in practice: `cookieManagement:"server"`, `cookieName:"FPID"`, `cookieMaxAgeInSec:"63072000"` (2y), `cookieDomain:"auto"`, `cookiePath:"/"`, `activateDefaultPaths:true`, `migrateFromJsClientId:true`.

For serving the **loader script** first-party as well (not just the cookie), add a `gtm_client` alongside — see pattern 15.

### 6. Prolonging non-Google click IDs with CookieMonster (ITP mitigation)

Google's FPID is already server-managed. Non-Google click/browser IDs (Meta `_fbc` / `_fbp`, and any local ad-platform click/session cookies) are still JS-set and therefore ITP-capped. **CookieMonster** (Simo Ahava's server template, gallery `cvt_PH3XM`) re-writes them as first-party HttpOnly cookies with long TTLs on every hit, so the identifiers survive.

- **Fire it on the client trigger** (the `ALWAYS`/client-scoped trigger that matches every incoming GA4 hit), so cookies are refreshed continuously rather than once.
- **Per-cookie map** shape:

```json
{"type":"MAP","map":[
  {"type":"TEMPLATE","key":"name","value":"meta_click"},
  {"type":"TEMPLATE","key":"value","value":"{{cookie._fbc | freshest}}"},
  {"type":"TEMPLATE","key":"expiration","value":"7776000"},
  {"type":"TEMPLATE","key":"domain","value":"auto"},
  {"type":"TEMPLATE","key":"sameSite","value":"lax"},
  {"type":"BOOLEAN","key":"httpOnly","value":"true"},
  {"type":"BOOLEAN","key":"setEmpty","value":"true"},
  {"type":"BOOLEAN","key":"encodeValue","value":"false"}
]}
```

- `httpOnly: true` is what makes the cookie server-set and thus ITP-durable — don't drop it. Typical TTLs: click IDs ~90d (`7776000`), browser IDs ~365d (`31536000`), session IDs shorter.
- **`| freshest`** is CookieMonster syntax: when the same cookie exists more than once (a JS-set copy plus the server-set copy), take the freshest value. Read the *same* freshest value into the matching CAPI tag so what you store and what you send agree.
- `consentStatus` is usually `NOT_SET` on this tag — consent is enforced upstream on the web before the hit ever reaches the server.

### 7. Companion "freshest cookie" resolver variables

Alongside CookieMonster there's typically an own-code *Durable ID Resolver* variable (browser ↔ server cookie) instantiated once per click ID and **named literally after its source**, e.g. a variable called `cookie._fbc | freshest`. Naming the variable after what it reads makes the wiring self-documenting: the exact same variable feeds CookieMonster (which rewrites the cookie) and the CAPI tag (which sends it), which is what guarantees the stored value and the transmitted value match.

The resolver reads **both** copies of an identifier — the browser-set cookie and the server-written one — and returns the freshest. The critical wiring: the resolver's `serverCookie` parameter must equal the **cookie name CookieMonster writes**. Concretely, CookieMonster maps `{{cookie._fbc | freshest}}` → server cookie `meta_click`; the resolver `cookie._fbc | freshest` is configured `browserCookie:"_fbc"`, `serverCookie:"meta_click"`, `strategy:"newest"` (with `tsMode`/`tsIndex` telling it where the timestamp sits inside the value). They reference each other by that shared name — a mismatch silently breaks prolongation.

Instantiate one resolver per non-Google ID. In practice that's more than just Meta: `_fbc` / `_fbp`, regional ad-platform click IDs, and any first-party session/user "durable" IDs the site sets — each gets its own `cookie.<name> | freshest` resolver and its own CookieMonster row.

### 8. Server transformations to trim vendor payloads

A built-in `tf_exclude_params` transformation strips a list of parameters from the event *before a downstream tag fires* — useful when one vendor shouldn't receive the full GA4/transport payload (e.g. drop `ecommerce`, `items`, `client_id`, `ga_session_id`, `ga_session_number`, and the cross-vendor transport params like `meta_contents` / `meta_content_ids` before a local-platform S2S tag). Transformations run after the client parses the request and before tags fire.

**Scoping is not done with triggers** — a transformation has no `firingTriggerId`. It is scoped by one of:

- `affectedTags` (LIST) — specific tags by name, or
- `affectedTagTypes` (LIST of `{tagType: "<type-code>"}`) — every tag of a given type (this is how you target "the Seznam S2S tag" via its own-code `cvt_<containerId>_<templateId>` type), or
- `matchingConditionsEnabled: true` + a `booleanExpressionString` for a condition-based scope.

`allTagsExcept: true` inverts the selection. The excluded-parameter list lives in `excludedParamsTable` as a LIST of `{excludedParams: "<name>"}` MAPs. Scoping by `affectedTagTypes` keeps the strip attached to the vendor even if the tag is renamed.

### 9. Browser/server dedup with a shared `event_id`

Generate a unique event id **once on the web** (a dedicated variable — commonly Stape's *Unique Event ID*, `cvt_M63B8`, which takes **zero parameters** and emits a fresh UUID per event), write it into `gtes` as `event_id` so it rides along GA4 → sGTM, and send the *same* id to the browser pixel (`eventId`) and to the server CAPI tag. Matching `event_id` is how Meta/TikTok/etc. dedupe the browser hit against the server hit. One id per event — never regenerate it server-side, or dedup breaks.

### 10. MCC vs sub-account — shared Constant vs per-market ID Lookup

Not every ID varies per market. The rule that keeps the container DRY:

- **Same value across all markets → a Constant** (`c`). Classic case: a single Google Ads **MCC** conversion ID that covers every market. The tag references it as `AW-{{Google Ads MCC Conversion ID}}` (the `AW-` prefix lives in the tag, the constant holds only the digits).
- **Differs per market → an ID Lookup** (pattern 1), or, server-side, a native **`remm` Regex Table** keyed on `{{Event Data - page_hostname}}` (`fullMatch:true`, `ignoreCase:true`, rows like `^(www\.)?example\.cz$` → `<conversion-id>`). Here the resolved value usually already includes the `AW-` prefix, so the tag is just `{{ID Lookup - GAds Sub-accounts Conversion ID}}`.

A real setup therefore runs **two** Google Ads config tags side by side — `... - Config MCC` (on the constant) and `... - Config Sub-accounts` (on the lookup) — sharing the *same* `configSettingsVariable` / `eventSettingsVariable` pair and the same triggers. The server container mirrors this with two `sgtmadsremarket` tags. Same principle applies to any platform where one account spans markets while others are per-market: single-market vendors (a local retargeting ID, a price-comparison API key) are plain Constants; multi-market vendors are ID Lookups.

### 11. Centralized `gtcs`/`gtes` settings — the minimalistic tag

This is *why* the event tags are so small. A **Google Tag Configuration Settings** (`gtcs`) variable and a **Google Tag Event Settings** (`gtes`) variable hold every shared parameter once, and the tags reference them via `configSettingsVariable` / `eventSettingsVariable`. Keep a **separate pair per Google destination** (one for GA4, one for Google Ads) so their parameter sets don't collide.

- `gtcs` (config-time): `user_data`, `user_id`, `server_container_url = {{ID Lookup - Server Container URL}}`, `page_hostname`, `ecommerce`. Shape: a LIST `configSettingsTable` of `{parameter, parameterValue}` MAPs.
- `gtes` (per-event): everything the events need — `page_type`, `page_language`, `logged_in`, `user_data`, `user_id`, `event_id = {{Unique Event ID}}`, `page_hostname`, `server_container_url`, `ecommerce`, plus a `userProperties` LIST for GA4 user properties. Shape: LIST `eventSettingsTable` of `{parameter, parameterValue}` MAPs (+ optional `userProperties` LIST of `{name, value}`).

With both in place a GA4 event tag collapses to ~5 parameters: `sendEcommerceData:true`, `getEcommerceDataFrom:"dataLayer"`, `eventName:{{Event}}`, `measurementIdOverride:{{ID Lookup - GA4 Measurement ID}}`, `eventSettingsVariable:{{Google Tag Event Settings}}`. Note `eventName:{{Event}}` — the built-in event name is passed straight through, so **one** `gaawe` tag on **one** regex trigger (pattern 3) serves the whole ecommerce family instead of one tag per event. When you add an event, you usually add nothing to the tag — you extend the regex trigger and, if needed, the settings variable.

### 12. The GA4 → sGTM hit as a cross-vendor transport bus

The highest-leverage pattern in these containers, and easy to miss. The `gtes` doesn't only carry GA4's own fields — it also carries **other vendors' payloads**, each JSON-stringified, e.g. `meta_contents`, `meta_content_ids`, `meta_content_name`, `meta_content_category`, `meta_num_items`, `seznam_contents`, and a stringified consent state. So the single GA4 event hit ferries Meta/regional-vendor data to sGTM, and the server fans out to each CAPI/S2S tag — instead of every web pixel opening its own connection to its own server endpoint.

The round trip, with symmetric names:

1. **Web builds** the vendor array (a `jsm` var, e.g. `FB - contents`).
2. **Web stringifies** it (`JS - contents.stringify`) — GA4 event params must be scalars, so arrays/objects travel as JSON strings.
3. **It rides in `gtes`** under a namespaced key (`meta_contents`).
4. **Server reads it** as an `ed` variable (`Event Data - meta_contents`).
5. **Server parses it back** with a JSON-converter template (Stape `cvt_MQRVK`, `actionType:"parse"`, `rawData:{{Event Data - meta_contents}}`) or an own-code `JSON.parse` variable — named `Parsed - meta_contents`.
6. **The CAPI tag consumes** the parsed object.

Keep the `JS - x.stringify` (web) and `Parsed - x` (server) names paired so the bus is traceable end to end. This piggybacking is what lets you run Meta/TikTok/regional CAPI **without** a second browser→server request per vendor.

### 13. Reconciling vendor event-name casing — triggers vs mapping tables

Vendors disagree on event names (Google: snake_case `add_to_cart`; Meta: PascalCase `AddToCart`). Two techniques coexist, often in the same container:

- **MATCH_REGEX triggers per casing** (pattern 3): a `snake_case Regex` trigger and a `PascalCase Regex` trigger, each firing the matching family.
- **Name-mapping tables**: an `smm` **Lookup Table** (or server `smm`) with `input:{{Event}}` mapping `add_to_cart → AddToCart`, `view_item → ViewContent`, `purchase → Purchase`, `begin_checkout → InitiateCheckout`, `add_payment_info → AddPaymentInfo`, `add_shipping_info → AddShippingInfo`, `remove_from_cart → RemoveFromCart`, `view_cart → ViewCart`, `page_view → PageView`. The tag then fires on the **snake_case** family trigger and sets its event name to `{{Lookup Table - Meta Event Names}}` — no separate PascalCase trigger needed.

The lookup-table approach means one trigger family and one tag; the regex-trigger approach is more explicit about *which* vendor fires when. Use whichever the surrounding container already uses; don't mix both for the same tag.

### 14. Server-side PII hashing before CAPI

CAPI/Advanced-Matching tags need SHA-256-hashed email/phone, not raw values. Wrap each raw `ed` user-data field in a hasher template (Simo Ahava's *sha256 Hasher*, `cvt_NFBZ7`): `input:{{Event Data - user_data.email}}`, `encoding:"hex"`. Name the result after what it produces — `Event Data - user_data.sha256_email_address` — and feed **that** to the CAPI tag, never the raw field. One hasher instance per PII field (email, phone, …). Normalization (lowercase/trim) should happen upstream or in the template; don't hash an un-normalized value or match rates drop.

### 15. First-party serving of the loader itself — `gtm_client`

Pattern 5 makes the *identity cookie* first-party. This makes the **loader script** first-party too, removing the last `googletagmanager.com` request. Alongside `gaaw_client`, add a **`gtm_client`** (type `gtm_client`) with:

- `allowedContainerIds` — LIST of `{containerId: "GTM-XXXXXX", path: "/<loader-path>"}`. The web container is then loaded from `https://<first-party-subdomain>/<loader-path>` instead of `googletagmanager.com/gtm.js`.
- `isPathMandatory: true`, `activateResponseCompression: true`.
- `activateGeoResolution: true` and `region: {{Visitor Region}}` — turns on edge geo so downstream server logic can read it.

Net effect: `gtm.js` and all subsequent hits are same-site first-party, so the browser applies first-party cookie lifetimes throughout. The web container's own tag/loader must be configured to request that first-party path (this is set on the Google Tag / loader side, not in the JSON here).

### 16. Edge geo resolution — `vr` and request-header variables

With `activateGeoResolution` on (pattern 15), the tagging server can read the visitor's geo from the load balancer without an IP-lookup tag:

- **`vr` (Visitor Region)** variable — `{"key":"resolutionOptions","value":"requestHeaders"}`.
- **`rh` (Request Header)** variables — e.g. `Request Header - X-Gclb-Country`, `Request Header - X-Gclb-Region` (headers a Google Cloud load balancer injects).

Use these to region-gate server tags, feed `region` back into a client, or drive a market lookup when hostname isn't a reliable market signal.

### 17. Consent-state forwarding, web → server

Consent Mode is enforced in the browser, but server tags sometimes need to *see* the state. Capture it on the web with a consent-state template variable (Ayudante's *GTM Consent State*, `cvt_M6BW3`, `selectTarget:"all"` for the whole object), stringify it (a `jsm` var), and ship it in `gtes` under a key like `gtm_consent_state`. Server-side, read it as `Event Data - gtm_consent_state` and parse it (pattern 12). Now a server tag can branch on granted/denied signals even though nothing was enforced server-side. Server-tag `consentStatus` typically stays `NOT_SET` regardless — this pattern is about *visibility*, not enforcement.

### Naming conventions worth adopting

Consistent prefixes make a container self-documenting and make it easy to pattern-match when adding entities. Common scheme:

| Prefix / suffix              | Meaning                                                        |
| ---------------------------- | ------------------------------------------------------------- |
| `DLV - <path>`               | Data Layer Variable reading `<path>` (e.g. `DLV - ecommerce.items`) |
| `CE - <event>` / `Custom Event - <x>` | a `CUSTOM_EVENT` trigger                              |
| `... (regex)` / `... snake_case Regex` / `... PascalCase Regex` | a `MATCH_REGEX` family trigger      |
| `ID Lookup - <platform>`     | a hostname→ID lookup variable (pattern 1)                     |
| `JS - <x>`                   | Custom JS (`jsm`) variable                                    |
| `JS - <x>.stringify`         | Custom JS that JSON-stringifies a value for transport         |
| `UPD - user_data`            | User-Provided Data (`awec`) variable                          |
| `cookie.<name> \| freshest`  | freshest-cookie resolver variable (pattern 7)                 |
| `<Platform> - Config` / `<Platform> - Event - <x>` | tags, split into one config tag + per-event tags |
| `<Platform> - Config MCC` / `... Sub-accounts` | the two-tag MCC / per-market split (pattern 10) |
| ` \| <MARKET>` suffix        | market-scoped variant (pattern 2), e.g. ` \| CZ`; combine markets like ` \| CZ/PL` |
| `Lookup Table - <x>` / `RegEx Table - <x>` | native `smm` / `remm` mapping variables         |
| `Lookup Table - <Vendor> Event Names` | `smm` name-mapping table, GA4 → vendor casing (pattern 13) |
| `... .sha256_<field>` (e.g. `... user_data.sha256_email_address`) | hashed-PII variable feeding CAPI (pattern 14) |
| `Parsed - <x>`               | server-side JSON-converted / `JSON.parse` variable (pattern 12) |
| `Google Tag Configuration Settings [- <Product>]` / `Google Tag Event Settings [- <Product>]` | the `gtcs` / `gtes` pair, one per Google destination (pattern 11) |
| `TBD <x>`                    | staged / not-yet-configured entity (placeholder token, e.g. an API key still to be filled in) |

## Folders, zones, built-in variables — quick notes

- **Folders.** `folder[]` entries are `{folderId, name, accountId, containerId, fingerprint}`. Tags/triggers/variables reference them via `parentFolderId`. Optional — entities can be folder-less.
- **Zones** (WEB only). Allow delegating part of a parent container's responsibility to a child container. Each `zone[]` entry has `zoneId`, `childContainer` (array of `{publicId, nickname}`), `boundary` (filter rules controlling where in the page the zone is loaded), and `typeRestriction` (limits which entity types the child container can run).
- **`builtInVariable[]`** is the list of **enabled** built-in variables. Each entry is `{type, name, accountId, containerId}`. The `type` is an enum: WEB has `PAGE_URL`, `PAGE_HOSTNAME`, `PAGE_PATH`, `REFERRER`, `EVENT`, `CLICK_CLASSES`, `CLICK_ID`, `CLICK_URL`, `CLICK_TEXT`, `CLICK_ELEMENT`, `FORM_*`, `HISTORY_*`, `SCROLL_*`, `VIDEO_*`, etc.; SERVER has a much shorter list including `EVENT_NAME`, `CLIENT_NAME`, `QUERY_STRING`, `REQUEST_METHOD`, `REQUEST_PATH`, etc. Enabling a built-in here is what makes its `name` usable in `{{...}}` interpolation. Disabled built-ins still exist conceptually but won't interpolate.

## Pitfalls that cost time

- **Confusing `publicId` (`GTM-XXXXXX`) with `containerId` (numeric).** They're not the same field; both must be set correctly and consistently across every entity.
- **Forgetting that SERVER containers don't have most WEB built-in variables.** Don't reference `{{Page Hostname}}` from a server container — it doesn't exist there. The server equivalents go through `ed` (Event Data) variables or `sgtmk` (server cookie) variables.
- **Putting variable IDs (numbers) inside `{{...}}` instead of variable names.** GTM uses names for interpolation everywhere.
- **Reusing an existing `tagId` / `triggerId` / `variableId`** for a "new" entity. The import will replace, not add.
- **Mis-encoding a `cvt_*` type.** Gallery-installed → `cvt_<galleryTemplateId>`. Own-code or gallery-without-galleryTemplateId → `cvt_<containerId>_<templateId>`. Mixing these up produces an "unknown template" import error.
- **Adding a `cvt_*` tag without first adding the `customTemplate[]` entry.** GTM rejects tags whose type doesn't match a known template (built-in or custom).
- **Hand-editing `templateData` blobs** inside `customTemplate[]`. They're a structured, signed-by-Gallery payload. Treat them as opaque — copy whole templates between containers, don't try to surgically edit the sandboxed JS or alter the `signature`.
- **Assuming consent settings.** Removing `consentSettings` from a tag that had `consentStatus: NEEDED` ships a tag that fires without consent — ask the user, don't drop the field. Server-side tags routinely use `NOT_SET` on purpose; copy the pattern from siblings.
- **Mixing usageContext.** If a user pastes a snippet from a WEB container into a SERVER container, the `type` codes won't be valid. Catch this in validation.
- **Forgetting a built-in trigger ID.** When you see `firingTriggerId: ["2147479553"]` and there's no matching object in `trigger[]`, that's not a bug — it's the All Pages built-in. Don't "fix" it by inventing a trigger.
- **Wrong reference style for `setupTag`/`teardownTag`.** These are by tag **name**, not ID, and live in a `{"tagName":"..."}` object — not a bare string.
- **Adding a tag that fires on no triggers.** A tag with `firingTriggerId: []` or no `firingTriggerId` at all is legal JSON but will never fire — confirm with the user it's intentional (e.g. it's purely a setup/teardown target).
- **Duplicating a tag per market when an ID Lookup already exists.** In a multi-market container, adding "GA4 - Config | PL" alongside "GA4 - Config | CZ" is almost always wrong — the existing config tag already resolves the market ID via `{{ID Lookup - ...}}`. Add a row to the lookup table instead. Duplicate per-market tags are the #1 source of drift.
- **Un-anchored regex event triggers.** `MATCH_REGEX view_item|add_to_cart` (no `^(...)$`) silently over-fires on any event *containing* those substrings. Always anchor: `^(view_item|add_to_cart)$`.
- **Forgetting the source gate on a new custom-event trigger.** If sibling triggers filter on a `dl_source` (or similar) discriminator and your new one doesn't, it will fire on stray same-named events from third-party scripts. Copy the gate from a sibling.
- **Adding an ID Lookup row on WEB but not SERVER (or vice-versa) when onboarding a market.** The two containers each have their own lookup instances; a market added to one but not the other breaks either measurement or first-party serving for that country.
- **Dropping `httpOnly` / `| freshest` from CookieMonster cookies.** Without `httpOnly: true` the cookie isn't ITP-durable (the entire reason the tag exists); without `| freshest` you may re-write a stale duplicate over the current value.
- **Regenerating `event_id` server-side.** The browser/server dedup id must be generated once on the web and passed through unchanged. Minting a new one in the server container silently defeats CAPI deduplication.

## Quick reference: most common type codes

Full catalogue is in `references/`, but these are the ones you'll meet in nearly every real export:

**WEB tag types:** `html` (Custom HTML), `gaawe` (GA4 Event), `googtag` (Google Tag — modern GA4/Ads config), `gclidw` (Conversion Linker), `awct` (Google Ads Conversion Tracking), `flc` (Floodlight Counter), `fls` (Floodlight Sales), `baut` (Microsoft UET), `sp` (Custom Image), `cvt_*` (custom template).

**SERVER tag types:** `sgtmgaaw` (GA4 server-side), `sgtmadsct` (Google Ads conversion), `sgtmadsremarket` (Google Ads remarketing), `sgtmadscl` (Google Ads conv linker), `cvt_*` (custom template — Facebook/Meta CAPI, TikTok Events API, Reddit CAPI, Microsoft Ads CAPI, regional S2S/SEM tags, BigQuery, Amazon CAPI, etc., almost always live here). A single MCC-vs-sub-account setup often runs **two** `sgtmadsremarket` tags (one on the shared MCC ID, one on per-market IDs) — see pattern 10.

**Custom templates you'll meet repeatedly in this architecture** (name → gallery id, so you can recognize the `cvt_*` encoding): Cookie Monster (Simo Ahava, `PH3XM`), sha256 Hasher (Simo Ahava, `NFBZ7`), Unique Event ID (Stape, `M63B8`), JSON converter (Stape, `MQRVK`), Facebook Conversion API / Meta Pixel (Stape / Facebook), TikTok Pixel + TikTok Events API (Stape), GTM Consent State (Ayudante, `M6BW3`), plus own-code `ID Lookup` and a `Durable ID Resolver` (browser↔server cookie). Regional ad platforms (e.g. Seznam Sklik/SEM, Heureka, on-site search, CRO/popup tools) usually ship as community templates and commonly come as a **web pixel template + a separate server S2S variant**; the server variant is frequently own-code (`cvt_<containerId>_<templateId>`).

**WEB variable types:** `v` (Data Layer), `c` (Constant), `jsm` (Custom JS function), `j` (JS Variable on window), `u` (URL component), `k` (1st-Party Cookie), `smm` (Lookup Table), `remm` (RegEx Table), `aev` (Auto-Event Variable — for click/form data), `gtes` (GA4 Event Settings), `gtcs` (Google Tag Config Settings), `f` (HTTP Referrer), `awec` (User-provided Data), `cvt_*` (custom template).

**SERVER variable types:** `ed` (Event Data — read a key path from the incoming event), `c` (Constant), `smm` (Lookup), `remm` (RegEx Table — **valid server-side too**, not WEB-only; commonly keyed on `{{Event Data - page_hostname}}` to resolve a per-market ID), `sgtmk` (server-side cookie — the SERVER analog of `k`), `rh` (Request Header — e.g. `X-Gclb-Country` / `X-Gclb-Region` from a Cloud load balancer), `vr` (Visitor Region — `{"key":"resolutionOptions","value":"requestHeaders"}`; requires the client's geo resolution to be on), `cn` (Client Name, built-in), `cvt_*` (custom template). Note: for prolonging non-Google click cookies, production containers typically use a CookieMonster/Durable-ID-Resolver custom template pair (`cvt_*`) rather than plain `sgtmk` — see patterns 6–7.

**Trigger types:** `CUSTOM_EVENT` (most common — fires on dataLayer events matching name via `{{_event}}`), `PAGEVIEW`, `DOM_READY`, `WINDOW_LOADED`, `HISTORY_CHANGE`, `INIT` (Initialization), `CONSENT_INIT` (Consent Initialization), `LINK_CLICK`, `CLICK`, `FORM_SUBMISSION`, `TIMER`, `SCROLL_DEPTH`, `ELEMENT_VISIBILITY`, `JS_ERROR`, `TRIGGER_GROUP`, `YOU_TUBE_VIDEO`, `ALWAYS` (SERVER default), `SERVER_PAGEVIEW` (SERVER only — fires on Page View events from a client).

**Filter operators:** `EQUALS`, `NOT_EQUALS`, `CONTAINS`, `MATCH_REGEX`, `STARTS_WITH`, `ENDS_WITH`, `GREATER`, `LESS`, `CSS_SELECTOR`. Add `{"type":"BOOLEAN","key":"ignore_case","value":"true"}` to make string matching case-insensitive. Add `{"type":"BOOLEAN","key":"negate","value":"true"}` to invert the match.

**Tag firing options:** `ONCE_PER_EVENT` (default), `ONCE_PER_LOAD`, `UNLIMITED`.

**Consent statuses:** `NOT_SET` (no enforcement — common on SERVER), `NEEDED` (with `consentType.list` of `ad_storage` / `analytics_storage` / `ad_user_data` / `ad_personalization` / `personalization_storage` / `functionality_storage` / `security_storage`), `NOT_NEEDED`.

**Custom template `INFO.type`:** `TAG`, `MACRO` (= variable), `CLIENT` (SERVER only), `TRANSFORMATION` (SERVER only).
