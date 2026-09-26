# Reference: trigger types and filter operators

`type` on a `trigger[]` entry, plus the filter grammar shared by triggers.

## Trigger types

| type | fires on | filter field |
| --- | --- | --- |
| `CUSTOM_EVENT` | a dataLayer event whose name matches | `customEventFilter` |
| `PAGEVIEW` / `DOM_READY` / `WINDOW_LOADED` | page lifecycle (WEB) | `filter` |
| `HISTORY_CHANGE` | SPA route change (WEB) | `filter` |
| `INIT` / `CONSENT_INIT` | Initialization / Consent Initialization (WEB) | `filter` |
| `LINK_CLICK` / `CLICK` / `FORM_SUBMISSION` | interactions (WEB) | `filter` (+ `waitForTags`, `checkValidation`, `uniqueTriggerId`) |
| `TIMER` | interval (WEB) | `autoEventFilter` (+ `eventName`, `interval`, `limit`) |
| `SCROLL_DEPTH` / `ELEMENT_VISIBILITY` / `YOU_TUBE_VIDEO` / `JS_ERROR` | WEB auto-events | `filter` (+ type-specific) |
| `TRIGGER_GROUP` | all child triggers fired | children via `parameter` LIST of TRIGGER_REFERENCE |
| `ALWAYS` | every event the client emits (SERVER default) | `filter` |
| `SERVER_PAGEVIEW` | Page View events from a client (SERVER) | `filter` |

## The CUSTOM_EVENT / `{{_event}}` pattern

Every `CUSTOM_EVENT` trigger matches the event name via the runtime `{{_event}}`:

```json
"customEventFilter": [{
  "type": "EQUALS",
  "parameter": [
    {"type": "TEMPLATE", "key": "arg0", "value": "{{_event}}"},
    {"type": "TEMPLATE", "key": "arg1", "value": "add_to_cart"}
  ]
}]
```

Swap `EQUALS` for `MATCH_REGEX` with `arg1 = ^(view_item|add_to_cart|purchase|...)$` to fire a
whole family from one trigger. **Anchor with `^(...)$`** or `add_to_cart` also matches
`add_to_cart_extra`.

## Filter operators

`EQUALS`, `NOT_EQUALS`, `CONTAINS`, `STARTS_WITH`, `ENDS_WITH`, `MATCH_REGEX`,
`GREATER`, `LESS`, `CSS_SELECTOR`.

Each filter is `{"type": <OP>, "parameter": [ {arg0}, {arg1} ]}`. Add extra BOOLEAN parameters:

- `{"type":"BOOLEAN","key":"negate","value":"true"}` — invert the match.
- `{"type":"BOOLEAN","key":"ignore_case","value":"true"}` — case-insensitive string match.

## Multi-filter triggers (the robust real-world shape)

A production CUSTOM_EVENT trigger usually stacks filters (AND):

1. the event match (`{{_event}}` EQUALS/MATCH_REGEX),
2. a **source gate** — `{{DLV - dl_source}} EQUALS <your-bridge>` — so stray third-party
   events with the same name don't fire your tags (pattern 4),
3. optionally a **market scope** — `{{Page Hostname}} EQUALS www.example.cz` (WEB) or
   `{{Event Data - page_hostname}} CONTAINS example.cz` (SERVER) (pattern 2),
4. optionally a **destination discriminator** — `{{DLV - eventModel.send_to}} CONTAINS AW-`
   (positive on the Ads path, `negate=true` on the GA4/general path).

See `examples/web-triggers.json` (regex family + source gate, market-scoped variant,
single-event, Google-Ads-family regex) and `examples/server-triggers.json` (an `ALWAYS`
client-scoped trigger using `{{Client Name}}` + `{{Event Name}}`, PascalCase regex, single event).

## Reserved built-in trigger IDs

IDs `≥ 2000000000` are built-ins that never appear as objects in `trigger[]`:
`2147479553` (All Pages, WEB), `2147479572` (Init, WEB), `2147479573` (Consent Init, WEB),
`2147479574` (All Events, SERVER). A `firingTriggerId` pointing at one with no matching object
is correct — don't invent a trigger for it.
