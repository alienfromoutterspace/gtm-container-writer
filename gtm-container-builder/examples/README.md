# Examples index

Real entity shapes, **sanitized** — every account/container ID, hostname, pixel/conversion ID,
API token, and brand string has been replaced with a placeholder. Structure, field order, and
parameter trees are otherwise untouched, so these are safe copy-paste templates. They are
**fragments** (arrays of entity objects) meant to be pasted into the matching array of a real
container, not imported on their own — except the two `shell-*.json`, which are complete
importable empty containers.

Placeholders you'll see: `0000000000` (accountId), `1111111`/`2222222` (containerId, WEB/SERVER),
`GTM-WEBXXXX`/`GTM-SRVXXXX` (publicId), `example.cz|.sk|.pl|.hu` (market hostnames),
`<META-PIXEL-ID-XX>`, `<AW-CONV-ID-XX>`, `<VALUE>` (a Constant's redacted value).

| file | contents |
| --- | --- |
| `shell-web.json` | empty importable WEB container (from `scripts/scaffold.py`) |
| `shell-server.json` | empty importable SERVER container |
| `web-tags.json` | `gaawe` event (minimal), `googtag` GA4 config, two `googtag` Google Ads configs (MCC + sub-accounts), `gclidw`, `cvt_*` Meta event |
| `web-triggers.json` | CUSTOM_EVENT regex family + source gate, market-scoped variant, single event, Google-Ads-family regex |
| `web-variables.json` | `v`, ID-Lookup `cvt_*`, `gtcs`, `gtes`, `smm` event-name map, `awec`, Unique Event ID `cvt_*`, consent-state `cvt_*` |
| `server-tags.json` | `sgtmgaaw`, `sgtmadsct`, two `sgtmadsremarket`, `cvt_*` Meta CAPI, CookieMonster `cvt_*` |
| `server-triggers.json` | `ALWAYS` client-scoped, PascalCase regex, market-scoped variant, single event |
| `server-variables.json` | `ed`, sha256-hasher `cvt_*`, JSON-converter `cvt_*`, Durable-ID-Resolver `cvt_*`, server ID-Lookup `cvt_*`, `remm`, `vr`, `rh`, `smm` |
| `server-clients.json` | `gaaw_client`, `gtm_client` |
| `server-transformations.json` | `tf_exclude_params` |

When building a specific entity, read the matching example first — it shows the exact field set
in the order GTM expects. Cross-references to the numbered patterns live in `../SKILL.md`.
