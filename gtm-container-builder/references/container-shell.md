# Reference: container shell (top-level structure)

The whole export is one JSON object. Top level:

```
{
  "exportFormatVersion": 2,
  "exportTime": "2025-01-01 12:00:00",
  "containerVersion": { ... }        // everything lives here
}
```

`containerVersion` holds the metadata object plus the entity arrays:

```
containerVersion
├── path                       accounts/<accountId>/containers/<containerId>/versions/<n>
├── accountId, containerId     numeric strings, repeated for convenience
├── containerVersionId         "0" for a workspace export, numeric for a published version
├── container { ... }          the metadata block (see below)
├── builtInVariable[]          enabled built-ins  {type, name, accountId, containerId}
├── tag[]
├── trigger[]
├── variable[]
├── folder[]
├── client[]                   SERVER only
├── transformation[]           SERVER only
├── zone[]                     WEB only, optional
└── fingerprint                millisecond timestamp, regenerated on import
```

## The `container` metadata block

```json
{
  "path": "accounts/<accountId>/containers/<containerId>",
  "accountId": "0000000000",
  "containerId": "1111111",
  "name": "My container",
  "publicId": "GTM-XXXXXX",
  "usageContext": ["WEB"],
  "tagIds": ["GTM-XXXXXX"],
  "taggingServerUrls": ["https://hub.example.tld"],
  "features": { ... },
  "fingerprint": "..."
}
```

- **`usageContext`** — `["WEB"]` or `["SERVER"]`. Decides which tag/variable/trigger/client types are legal. Check it before anything else.
- **`publicId`** (`GTM-XXXXXX`) vs **`containerId`** (numeric) — two different fields. Both must be consistent across every entity. Never substitute one for the other.
- **`taggingServerUrls`** — SERVER only. The first-party subdomains browsers talk to, plus the underlying Cloud Run origin. See `examples/shell-server.json`.
- **`features`** — booleans GTM sets from the container type. The two that differ by context:
  - WEB: `supportClients: false`, `supportTransformations: false`.
  - SERVER: `supportClients: true`, `supportTransformations: true`.

## WEB vs SERVER at a glance

| | WEB | SERVER |
| --- | --- | --- |
| `usageContext` | `["WEB"]` | `["SERVER"]` |
| `client[]` / `transformation[]` | absent | present |
| `taggingServerUrls` | absent | present |
| built-ins (typical) | `PAGE_URL`, `PAGE_HOSTNAME`, `PAGE_PATH`, `REFERRER`, `EVENT`, … | `EVENT_NAME`, `CLIENT_NAME` |
| tag types | `gaawe`, `googtag`, `html`, `gclidw`, `awct`, `flc`/`fls`, `cvt_*` | `sgtmgaaw`, `sgtmadsct`, `sgtmadscl`, `sgtmadsremarket`, `cvt_*` |
| identity source | `k` (1st-party cookie), `u` (URL), `aev` | `ed` (event data), `rh` (request header), `vr`, `sgtmk` |

## Fields you can leave alone

`exportTime`, every `fingerprint`, `tagManagerUrl`, and `path` are informational or regenerated on import. Keep `accountId` / `containerId` / `publicId` / `usageContext` correct; the rest GTM rewrites.

Scaffolds: `examples/shell-web.json`, `examples/shell-server.json` (produced by `scripts/scaffold.py`).
