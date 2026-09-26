___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Durable ID Resolver (browser ↔ server cookie)",
  "description": "",
  "categories": [
    "UTILITY",
    "ADVERTISING"
  ],
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "browserCookie",
    "displayName": "Browser cookie name",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "help": "The cookie written by the vendor\u0027s browser script. Examples: _fbc, _fbp, _ga, _gcl_aw, _uetvid, li_fat_id, _ttp"
  },
  {
    "type": "TEXT",
    "name": "serverCookie",
    "displayName": "Server cookie name",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "help": "Your server-set copy, written by Cookie Monster or another Set-Cookie tag. Must NOT be the same name as the browser cookie — same name means one shared slot, not two cookies."
  },
  {
    "type": "SELECT",
    "name": "strategy",
    "displayName": "When both cookies exist, keep",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "oldest",
        "displayValue": "Oldest value — IDENTITY cookies (_fbp, _ga, _gcl_au)"
      },
      {
        "value": "newest",
        "displayValue": "Newest value — CLICK cookies (_fbc, _gcl_aw)"
      },
      {
        "value": "preferServer",
        "displayValue": "Server value — identity cookies with no timestamp (_uetvid, _ttp)"
      },
      {
        "value": "preferBrowser",
        "displayValue": "Browser value — click cookies with no timestamp (li_fat_id, msclkid)"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "oldest",
    "help": "Identity must survive, so the ORIGINAL value wins. A click must be current, so the LATEST value wins. The two \u0027prefer\u0027 options are the same logic for values that carry no timestamp to compare."
  },
  {
    "type": "SELECT",
    "name": "tsMode",
    "displayName": "Where is the timestamp in the value",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "dotIndex",
        "displayValue": "A dot-delimited segment"
      },
      {
        "value": "none",
        "displayValue": "No timestamp in the value"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "dotIndex",
    "help": "Ignored when the strategy above is one of the \u0027prefer\u0027 options."
  },
  {
    "type": "TEXT",
    "name": "tsIndex",
    "displayName": "Segment index holding the timestamp",
    "simpleValueType": true,
    "defaultValue": "2",
    "enablingConditions": [
      {
        "paramName": "tsMode",
        "paramValue": "dotIndex",
        "type": "EQUALS"
      }
    ],
    "help": "Zero-based. Negative counts from the end (-1 \u003d last segment).\n\n_fbc / _fbp  fb.1.\u003cts\u003e.\u003cid\u003e        → 2\n_ga          GA1.1.\u003cid\u003e.\u003cts\u003e       → 3   (or -1)\n_gcl_au      1.1.\u003cid\u003e.\u003cts\u003e         → 3   (or -1)\n_gcl_aw      GCL.\u003cts\u003e.\u003cgclid\u003e      → 1\nFPID         \u003cid\u003e.\u003cts\u003e             → -1"
  },
  {
    "type": "GROUP",
    "name": "seedGroup",
    "displayName": "Seed value (optional)",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "CHECKBOX",
        "name": "useSeed",
        "checkboxText": "Build a value when neither cookie exists",
        "simpleValueType": true,
        "help": "Closes the first-event gap: on a visitor\u0027s very first request the vendor script may not have written its cookie yet. Supply the raw click ID from the URL and this template will construct a correctly formatted value from it."
      },
      {
        "type": "TEXT",
        "name": "seedValue",
        "displayName": "Raw seed value",
        "simpleValueType": true,
        "enablingConditions": [
          {
            "paramName": "useSeed",
            "paramValue": true,
            "type": "EQUALS"
          }
        ],
        "help": "Usually a URL Query Parameter variable, e.g. {{Query - fbclid}}, {{Query - gclid}}, {{Query - li_fat_id}}, {{Query - msclkid}}, {{Query - ttclid}}"
      },
      {
        "type": "TEXT",
        "name": "seedPattern",
        "displayName": "Value pattern",
        "simpleValueType": true,
        "defaultValue": "%VALUE%",
        "enablingConditions": [
          {
            "paramName": "useSeed",
            "paramValue": true,
            "type": "EQUALS"
          }
        ],
        "help": "Placeholders: %VALUE% \u003d the raw seed, %TS% \u003d now in milliseconds, %TS_SEC% \u003d now in seconds.\n\n_fbc   →  fb.1.%TS%.%VALUE%\n_gcl_aw →  GCL.%TS_SEC%.%VALUE%\nOpaque IDs (LinkedIn, Microsoft, TikTok) →  %VALUE%"
      }
    ]
  },
  {
    "type": "GROUP",
    "name": "advancedGroup",
    "displayName": "Advanced",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "CHECKBOX",
        "name": "noDecode",
        "checkboxText": "Do not URL-decode cookie values",
        "simpleValueType": true,
        "help": "Leave unchecked in almost all cases. Checking it returns the raw stored bytes — useful only when you deliberately store an already-encoded value and want it back verbatim."
      },
      {
        "type": "CHECKBOX",
        "name": "debug",
        "checkboxText": "Log resolution to the preview console",
        "simpleValueType": true,
        "help": "Prints both candidate values, both parsed timestamps and the winner. Turn off before publishing."
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

const getCookieValues = require('getCookieValues');
const getTimestampMillis = require('getTimestampMillis');
const makeInteger = require('makeInteger');
const makeString = require('makeString');
const logToConsole = require('logToConsole');

const noDecode = data.noDecode === true;

// Read the first value of a cookie, treating '' as absent.
const firstCookie = function (name) {
  if (!name) return undefined;
  const values = getCookieValues(name, noDecode);
  if (!values || values.length === 0) return undefined;
  const value = values[0];
  if (!value || value === '') return undefined;
  return value;
};

// Pull the timestamp out of a dot-delimited value. -1 = not comparable.
const stampOf = function (value) {
  if (!value) return -1;
  if (data.tsMode !== 'dotIndex') return -1;

  const parts = makeString(value).split('.');
  let index = makeInteger(data.tsIndex);
  if (!index && index !== 0) return -1;
  if (index < 0) index = parts.length + index;
  if (index < 0 || index >= parts.length) return -1;

  const stamp = makeInteger(parts[index]);
  return stamp && stamp > 0 ? stamp : -1;
};

const browserValue = firstCookie(data.browserCookie);
const serverValue = firstCookie(data.serverCookie);
const strategy = data.strategy;

let result;
let browserStamp = -1;
let serverStamp = -1;

if (browserValue && serverValue) {
  if (strategy === 'preferBrowser') {
    result = browserValue;
  } else if (strategy === 'preferServer') {
    result = serverValue;
  } else {
    browserStamp = stampOf(browserValue);
    serverStamp = stampOf(serverValue);

    if (browserStamp < 0 || serverStamp < 0) {
      // Unparseable on at least one side — fall back to the side that
      // matches the intent of the strategy.
      result = strategy === 'oldest' ? serverValue : browserValue;
    } else if (strategy === 'oldest') {
      result = serverStamp <= browserStamp ? serverValue : browserValue;
    } else {
      result = browserStamp >= serverStamp ? browserValue : serverValue;
    }
  }
} else {
  result = browserValue ? browserValue : serverValue;
}

// Neither cookie present — build a value from the raw click ID if configured.
if (!result && data.useSeed && data.seedValue) {
  const nowMs = makeString(getTimestampMillis());
  const nowSec = nowMs.length > 3 ? nowMs.substring(0, nowMs.length - 3) : nowMs;
  const pattern = data.seedPattern ? makeString(data.seedPattern) : '%VALUE%';

  result = pattern
    .split('%TS_SEC%').join(nowSec)
    .split('%TS%').join(nowMs)
    .split('%VALUE%').join(makeString(data.seedValue));
}

if (data.debug) {
  logToConsole(
    '[Durable ID Resolver] ' + makeString(data.browserCookie) +
    '=' + makeString(browserValue) + ' (ts ' + makeString(browserStamp) + ') | ' +
    makeString(data.serverCookie) +
    '=' + makeString(serverValue) + ' (ts ' + makeString(serverStamp) + ') | ' +
    'strategy=' + makeString(strategy) + ' → ' + makeString(result)
  );
}

return result;


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "get_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "cookieAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []


___NOTES___

DURABLE ID RESOLVER
===================

Purpose
-------
Vendor scripts write their identifiers with document.cookie, so browser tracking
protections cap or delete them (Safari ITP: 7 days for script-written cookies,
24 hours when the visit arrived through a link-decorated ad click). A copy of the
same value written by your tagging server with a Set-Cookie header is not subject
to those caps. This variable decides, per request, which of the two copies to use.

The rule that governs everything:

    IDENTITY cookies  → keep the OLDEST value  (survive, do not re-identify)
    CLICK cookies     → keep the NEWEST value  (a newer click supersedes an older)

Getting this backwards silently breaks measurement: an identity that keeps taking
the newest value never survives anything, and a click that keeps the oldest value
attributes conversions to a campaign the visitor has since left.

Setup
-----
1. Import this template (Templates → New → ⋮ → Import).
2. Create one variable per identifier you want to protect.
3. Point BOTH consumers at that same variable:
     - the Cookie Monster (or equivalent) cookie's Value field
     - the CAPI / conversion tag's corresponding field
   This makes the cookie self-perpetuating: every event rewrites the server copy
   with the resolved value and rolls its expiry forward.

Cookie Monster settings that go with it
---------------------------------------
   Always set cookie : ON   (required — this is what rolls the expiry)
   HttpOnly          : ON   (server owns the copy; the vendor script cannot clobber it)
   Encode            : OFF  (these values need no encoding; leaving it on adds a decode step)
   Domain            : auto
   SameSite          : lax
   Expiration        : 31536000

"Always set" is only safe because the Value is this variable. Pointing it at the
raw browser cookie instead would overwrite your preserved value with a freshly
regenerated one the moment the browser cookie is deleted — destroying the exact
thing the setup exists to protect.

Configuration matrix
--------------------
Vendor      Browser cookie   Server copy      Strategy        Timestamp   Seed pattern
--------------------------------------------------------------------------------------
Meta        _fbp             meta_browser     oldest          index 2     (none)
Meta        _fbc             meta_click       newest          index 2     fb.1.%TS%.%VALUE%
Google      _ga              srv_ga           oldest          index 3     (none)
Google      _gcl_au          srv_gcl_au       oldest          index 3     (none)
Google      _gcl_aw          srv_gcl_aw       newest          index 1     GCL.%TS_SEC%.%VALUE%
Microsoft   _uetvid          ms_visitor       preferServer    none        (none)
Microsoft   _uetmsclkid      ms_click         preferBrowser   none        %VALUE%
LinkedIn    li_fat_id        li_click         preferBrowser   none        %VALUE%
TikTok      _ttp             tt_browser       preferServer    none        (none)
TikTok      ttclid           tt_click         preferBrowser   none        %VALUE%

Note on Google cookies: sGTM has native server-set equivalents (FPID, FPAU,
FPGCLAW) that are created earlier in the request lifecycle than any tag can manage,
so prefer those. Use this variable for Google cookies only when the native
mechanism is unavailable.

Consent
-------
This variable only reads. The tag that WRITES the server cookie must be gated on
the vendor's consent signal. With "Always set" enabled, a self-perpetuating cookie
keeps renewing itself from its own previous value — with no browser cookie needed
and no consent platform able to see it. That is a genuine consent-bypass risk and
the gating is not optional.

Testing
-------
Real traffic will not hand you the interesting states on demand. In preview,
construct all four deliberately:
  1. neither cookie                → seed path (or empty)
  2. browser only                  → browser value, server copy created
  3. server only                   → server value returned and rewritten (the payoff)
  4. both, with different stamps   → strategy decides
Also confirm what the cookie-writing tag does when the resolved value is empty:
if it writes an empty cookie rather than skipping, add a trigger exception, or the
empty value will feed itself forever.


