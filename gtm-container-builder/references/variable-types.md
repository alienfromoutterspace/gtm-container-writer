# Reference: variable types

`type` on a `variable[]` entry. Enabled built-ins live separately in `builtInVariable[]`.

## WEB variable types

| type | what it is | notes |
| --- | --- | --- |
| `v` | Data Layer Variable | `name` = dataLayer key path, `dataLayerVersion: 2` |
| `c` | Constant | single literal `value` (may hold an ID or secret — treat as sensitive) |
| `jsm` | Custom JavaScript | a `javascript` function body; used for payload builders and `.stringify` transport vars |
| `j` | JavaScript Variable | reads a `name` off `window` |
| `u` | URL | `component` (host, path, query, …) |
| `k` | 1st-Party Cookie | `name` |
| `smm` | Lookup Table | `input` + `map` of `{key, value}` rows |
| `remm` | RegEx Table | `input` + `map` of `{key (regex), value}`; `fullMatch`, `ignoreCase`, `replaceAfterMatch` |
| `aev` | Auto-Event Variable | click/form element data |
| `gtcs` | Google Tag Configuration Settings | LIST `configSettingsTable` of `{parameter, parameterValue}` |
| `gtes` | Google Tag Event Settings | LIST `eventSettingsTable` + optional `userProperties` |
| `awec` | User-Provided Data | for Enhanced Conversions / Advanced Matching |
| `f` | HTTP Referrer | `component` |
| `cvt_*` | custom template MACRO | e.g. ID Lookup, Unique Event ID, Consent State |

See `examples/web-variables.json`: `v` (DLV), a `cvt_*` ID Lookup (hostname→ID table — pattern 1),
`gtcs` and `gtes` (the centralized settings — pattern 11), an `smm` event-name map (pattern 13),
an `awec` user-data var, the zero-parameter Unique Event ID (`cvt_*`), a consent-state `cvt_*`,
and a `v` reading `eventModel.send_to`.

## SERVER variable types

| type | what it is | notes |
| --- | --- | --- |
| `ed` | Event Data | read a key path from the incoming event (`keyPath`) |
| `c` | Constant | as WEB (sensitive) |
| `smm` | Lookup Table | as WEB |
| `remm` | RegEx Table | **valid server-side too**; commonly `input:{{Event Data - page_hostname}}` → per-market ID |
| `sgtmk` | server-side cookie | the SERVER analog of `k` |
| `rh` | Request Header | e.g. `X-Gclb-Country` / `X-Gclb-Region` from a Cloud load balancer |
| `vr` | Visitor Region | `{"key":"resolutionOptions","value":"requestHeaders"}`; needs client geo resolution on |
| `cn` | Client Name | built-in-style |
| `cvt_*` | custom template MACRO | ID Lookup, sha256 Hasher, JSON converter, Durable ID Resolver |

See `examples/server-variables.json`: `ed`, a sha256-hasher `cvt_*` (hashed PII — pattern 14),
a JSON-converter `cvt_*` (`Parsed - x` — pattern 12), a Durable-ID-Resolver `cvt_*`
(`cookie._fbc | freshest` — pattern 7), a server ID-Lookup `cvt_*`, a `remm` regex table
(hostname→conversion ID — pattern 10), `vr`, `rh`, and an `smm` event-name map.

Note: for prolonging non-Google click cookies, production containers use a
CookieMonster + Durable-ID-Resolver `cvt_*` pair rather than plain `sgtmk`.

## Common optional fields

- `formatValue` — usually `{}`. Can coerce values: `convertUndefinedToValue`,
  `convertNullToValue`, `caseConversionType` (`LOWERCASE`/`UPPERCASE`), etc.
- `parentFolderId`, `notes`.
