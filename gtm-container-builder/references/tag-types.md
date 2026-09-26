# Reference: tag types

`type` on a `tag[]` entry. WEB and SERVER have disjoint sets (plus shared `cvt_*`).

## WEB tag types

| type | what it is | key parameters |
| --- | --- | --- |
| `googtag` | Google Tag (GA4/Ads config) | `tagId` (e.g. `{{ID Lookup - GA4 Measurement ID}}` or `AW-{{...}}`), `configSettingsVariable`, `eventSettingsVariable` |
| `gaawe` | GA4 Event | `eventName` (`{{Event}}` to pass through), `measurementIdOverride`, `sendEcommerceData`, `getEcommerceDataFrom`, `eventSettingsVariable` |
| `gclidw` | Conversion Linker | `enableCrossDomain`, cookie flags |
| `awct` | Google Ads Conversion Tracking | `conversionId`, `conversionLabel` |
| `flc` / `fls` | Floodlight Counter / Sales | `advertiserId`, `groupTag`, `activityTag` |
| `baut` | Microsoft UET | `tagId` |
| `html` | Custom HTML | `html`, `supportDocumentWrite` |
| `sp` | Custom Image pixel | `url` |
| `cvt_*` | custom template (see `custom-templates.md`) | template-specific |

See `examples/web-tags.json` for: a minimal `gaawe` event tag (5 params, everything else in
the settings variable), a `googtag` GA4 config, the two `googtag` Google Ads configs (MCC vs
sub-accounts — pattern 10), a `gclidw`, and a `cvt_*` Meta Pixel event tag.

## SERVER tag types

| type | what it is |
| --- | --- |
| `sgtmgaaw` | GA4 (server-side) — receives the hit and forwards to GA4 |
| `sgtmadsct` | Google Ads Conversion Tracking (server) |
| `sgtmadscl` | Google Ads Conversion Linker (server) |
| `sgtmadsremarket` | Google Ads Remarketing (server) |
| `cvt_*` | CAPI / S2S custom templates — Meta CAPI, TikTok Events API, regional SEM, BigQuery, etc. |

See `examples/server-tags.json` for: `sgtmgaaw` config, `sgtmadsct`, two `sgtmadsremarket`
(MCC + sub-accounts), a `cvt_*` Meta CAPI tag (hashed PII + freshest cookies + parsed
payload + ID-lookup pixel + event_id dedup), and the CookieMonster `cvt_*` tag.

## Optional tag fields (semantics change when set)

- `firingTriggerId` (LIST of trigger IDs), `blockingTriggerId` — see `trigger-types.md`.
- `tagFiringOption` — `ONCE_PER_EVENT` (default), `ONCE_PER_LOAD` (Floodlight), `UNLIMITED`.
- `priority` — `{"type":"INTEGER","value":"99999"}`; higher fires first. Config tags / linkers high.
- `setupTag` / `teardownTag` — LIST of `{"tagName": "...", "stopOnSetupFailure": true?}`. By **name**.
- `paused`, `liveOnly`, `notes`.
- `monitoringMetadata` — usually the empty `{"type":"MAP"}`; keep it, many tag types expect the key.
- `consentSettings` — `consentStatus` of `NEEDED` (+ `consentType.list`), `NOT_SET` (common on
  SERVER and on Google config tags), or `NOT_NEEDED`. Don't silently drop it.

## The DRY event-tag idea

One `gaawe` tag with `eventName: {{Event}}`, fired by a single `MATCH_REGEX` trigger, serves an
entire ecommerce event family. Market/ID specifics come from an ID-Lookup variable and a shared
`gtes` settings variable, so the tag itself stays tiny. See patterns 1, 3, 11 in SKILL.md.
