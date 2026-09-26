# Reference: SERVER-specific entities — `client[]` and `transformation[]`

These arrays exist only in SERVER containers (`features.supportClients` /
`supportTransformations` = true).

## Clients

A client claims and parses an incoming HTTP request on the tagging server and emits events
that triggers/tags react to.

| type | role |
| --- | --- |
| `gaaw_client` | the official GA4 client — parses GA4/gtag hits, manages the identity cookie |
| `gtm_client` | serves the GTM **web container** loader first-party (pattern 15) |
| `cvt_*` | custom-template clients (e.g. a vendor "data client") |

**`gaaw_client` — first-party identity cookie** (pattern 5). Key parameters seen in practice:
`cookieManagement: "server"`, `cookieName: "FPID"`, `cookieDomain: "auto"`, `cookiePath: "/"`,
`cookieMaxAgeInSec: "63072000"` (~2y), `activateDefaultPaths: true`, `migrateFromJsClientId: true`.
Server-managed HttpOnly first-party cookie sidesteps ITP's 7-day JS-cookie cap.

**`gtm_client` — first-party loader** (pattern 15). Key parameters:
`allowedContainerIds` (LIST of `{containerId: "GTM-XXXXXX", path: "/<loader-path>"}`),
`isPathMandatory: true`, `activateResponseCompression: true`, `activateGeoResolution: true`,
`region: {{Visitor Region}}`. Serves `gtm.js` from the first-party subdomain + custom path
instead of `googletagmanager.com`.

See `examples/server-clients.json` for both.

## Transformations

A transformation modifies event data **after** the client parses the request and **before**
tags fire. It has **no `firingTriggerId`** — scoping is done differently:

- `affectedTags` (LIST) — specific tags by name, or
- `affectedTagTypes` (LIST of `{tagType: "<type-code>"}`) — every tag of a type (e.g. target
  a vendor's own-code `cvt_<containerId>_<templateId>` S2S tag), or
- `matchingConditionsEnabled: true` + `booleanExpressionString`.
- `allTagsExcept: true` inverts the selection.

| type | role |
| --- | --- |
| `tf_exclude_params` | strip a list of parameters before a tag sees the event |
| `cvt_*` | custom-template transformations (enrich / hash / reshape) |

`tf_exclude_params` holds the params to drop in `excludedParamsTable` (LIST of
`{excludedParams: "<name>"}`). Typical use: strip `ecommerce`, `items`, `client_id`,
`ga_session_id`, and the cross-vendor transport params (`meta_contents`, …) before a local S2S
tag so it only receives what it needs (pattern 8).

See `examples/server-transformations.json`.

## Server built-in variables

Only a short list is available: `EVENT_NAME` (`{{Event Name}}`), `CLIENT_NAME`
(`{{Client Name}}`), and a few request-scoped ones. The rich WEB built-ins
(`{{Page Hostname}}`, click/form variables) **do not exist** server-side — read equivalent
values through `ed` (Event Data) or `rh` (Request Header) variables instead.
