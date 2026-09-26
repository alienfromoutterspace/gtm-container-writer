# Reference: the `parameter[]` format

Every tag, trigger filter, variable, client, and transformation carries its config
in a recursive `parameter[]` list. Each element has a `type` and usually a `key`.

## Scalar parameters

```json
{"type": "TEMPLATE", "key": "measurementId", "value": "G-XXXX or {{Some Variable}}"}
{"type": "BOOLEAN",  "key": "sendEcommerceData", "value": "true"}
{"type": "INTEGER",  "key": "priority", "value": "99999"}
```

- **TEMPLATE** — a string that may contain `{{variable name}}` interpolation. This is the
  workhorse type. `value` is always a string, even for numbers/booleans passed as text.
- **BOOLEAN** / **INTEGER** — `value` is still a **string** (`"true"`, `"42"`).

## Container parameters

```json
{"type": "LIST", "key": "someTable", "list": [ <MAP>, <MAP>, ... ]}
{"type": "MAP", "map": [ <Parameter>, <Parameter>, ... ]}
```

- **LIST** — an ordered array, almost always of MAPs. This is how every "table" UI
  (lookup tables, settings tables, cookie lists, hostname lookups) is encoded.
- **MAP** — a set of key/value parameters, i.e. one row of a table or one nested object.

A typical table row:

```json
{"type": "MAP", "map": [
  {"type": "TEMPLATE", "key": "parameter", "value": "user_id"},
  {"type": "TEMPLATE", "key": "parameterValue", "value": "{{DLV - user_id}}"}
]}
```

## Reference parameters

```json
{"type": "TAG_REFERENCE",     "key": "...", "value": "<tag NAME>", "isWeakReference": false}
{"type": "TRIGGER_REFERENCE",              "value": "<trigger ID>"}
```

- **TAG_REFERENCE** stores a tag's **name** string (used by tag sequencing / trigger groups).
- **TRIGGER_REFERENCE** stores a trigger's numeric **ID** string.

## The golden rule of interpolation

`{{name}}` inside a TEMPLATE value resolves against the **`name`** of a variable or an
enabled built-in variable — never against a numeric ID. Spaces, dots, hyphens, and pipes
are all legal inside the braces: `{{ID Lookup - Meta Pixel ID}}`, `{{cookie._fbc | freshest}}`,
`{{DLV - ecommerce.items.0.item_id}}`. The one name that needs no definition is the runtime
`{{_event}}` (the current event name on a CUSTOM_EVENT trigger).

Values can concatenate refs and literals: `AW-{{Google Ads MCC Conversion ID}}`,
`{{Event Data - event_id}}_{{Lookup Table - Meta Ads Event Names}}`.

## How references are tracked (don't mix these up)

| Reference | Stores | Where |
| --- | --- | --- |
| `firingTriggerId` / `blockingTriggerId` | numeric trigger **ID**s | on a tag |
| `TRIGGER_REFERENCE` | numeric trigger **ID** | in a parameter LIST |
| `TAG_REFERENCE` | tag **name** | in a parameter LIST |
| `setupTag` / `teardownTag` | tag **name** in `{"tagName": "..."}` | on a tag |
| `parentFolderId` | folder **ID** | on a tag/trigger/variable |
| `{{name}}` | variable **name** | inside any TEMPLATE value |

See any file in `examples/` for real parameter trees; `web-variables.json` (the `gtcs`/`gtes`
entries) shows deeply nested LIST→MAP tables.
