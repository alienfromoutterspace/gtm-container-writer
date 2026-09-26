# GTM Container Builder: a Claude Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Skill](https://img.shields.io/badge/Claude-Skill-8A63D2.svg)](https://docs.claude.com/en/docs/claude-code/skills)
[![Python](https://img.shields.io/badge/Python-3%20(stdlib%20only)-3776AB.svg)](#helper-scripts)

A [Claude Skill](https://docs.claude.com/en/docs/claude-code/skills) for reading, writing,
validating, and editing **Google Tag Manager (GTM) container JSON exports**, both Web and
Server-side (sGTM). It's the format you get from **Admin → Export Container** and import via
**Admin → Import Container**.

A GTM export is a reference graph: tags point at triggers, triggers at variables, variables at
other variables, and custom templates use a `cvt_*` encoding. One dangling reference makes the
import fail or breaks the container silently at runtime. This skill gives Claude the rules to keep that graph
intact, a catalogue of every entity/type code, the common architectural patterns, sanitized
examples, and Python helpers to scaffold/inspect/validate/diff containers.

> **⚠️ Work in progress.** This skill does not cover every existing vendor and tag type. It
> contains everything I've encountered so far, and it covers what most GTM and sGTM setups
> generally use. Expect gaps for less common vendors and tag types. Contributions are welcome.

## What it does

- **Edit an existing export:** add/change/remove entities and hand back a valid, importable file
  with references intact.
- **Build a new container from scratch:** scaffold a Web or Server shell and fill it with tags,
  triggers, and variables.
- **Validate** structure, reference integrity, and ID uniqueness before import.
- **Inspect** an export for a summary of what's inside.
- **Diff** two exports (before/after an edit).

Patterns it knows, from multi-market e-commerce + sGTM + first-party-serving setups: ID-Lookup
variables, regex-consolidated triggers, source-gating, browser/server `event_id` dedup,
CookieMonster ITP mitigation, centralized `gtcs`/`gtes` settings, server-side PII hashing, and the
GA4→sGTM transport bus.

## Custom templates (`.tpl`)

[`gtm-container-builder/templates/`](./gtm-container-builder/templates/) holds ready-made GTM
**custom templates** — frequently-reused own-code templates in the `.tpl` `___SECTION___` export
format. They ship with the skill (so Claude can embed the real source as a `customTemplate[]` entry
when building a container) **and** are separately downloadable — grab any `.tpl` and import it
straight into GTM's Template Editor. Currently included: **ID Lookup** as a Web/Server pair
(hostname→ID variable, pattern 1), a **Durable ID Resolver** (browser↔server freshest-cookie
variable, pattern 7), and a **Write to Firestore** server tag. See
[`templates/README.md`](./gtm-container-builder/templates/README.md) for the
catalogue, import steps, and the `.tpl` → `customTemplate[]` workflow.

## Repository layout

```
gtm-container-writer/
├── README.md
├── LICENSE                      ← MIT
└── gtm-container-builder/       ← the skill (copy this folder into your skills dir)
    ├── SKILL.md                 ← the skill definition Claude loads
    ├── references/              ← type codes, parameter grammar, server specifics, custom templates
    ├── examples/                ← one sanitized JSON per entity type + two importable empty shells
    ├── templates/               ← ready-made GTM custom templates (.tpl) — embeddable & importable
    └── scripts/                 ← inspect / validate / next_id / scaffold / diff_containers (+ gtmlib)
```

## Install

The skill is the `gtm-container-builder/` folder. Copy it wherever your Claude client finds skills.

**Claude Code, this project only:**
```bash
git clone https://github.com/alienfromoutterspace/gtm-container-writer.git
mkdir -p .claude/skills
cp -r gtm-container-writer/gtm-container-builder .claude/skills/
```

**Claude Code, all projects:**
```bash
cp -r gtm-container-writer/gtm-container-builder ~/.claude/skills/
```

No dependencies. The scripts use only the Python 3 standard library. Start a new Claude session
and it loads automatically when a request matches (a GTM export, a `GTM-XXXXXX` container,
`containerVersion`, sGTM, scaffolding/validating/diffing, custom templates).

The skill is a standard `SKILL.md` + resources bundle, so it also works anywhere skills are
supported (Claude Desktop / claude.ai upload, Agent SDK). Point the uploader at
`gtm-container-builder/`.

## Usage

Ask in natural language:

- *"Here's my GTM export. Add a GA4 event tag for `add_to_cart` on the ecommerce regex trigger."*
- *"Scaffold a new server-side container called `Acme sGTM`."*
- *"Validate this container and tell me what's broken."*
- *"Diff these two exports and summarize what changed."*

Claude uses the reference docs and examples to produce correct output, and runs the scripts to
validate before handing anything back.

### Helper scripts

You can also run them directly. They're the same ones Claude uses:

```bash
# Summary of a container (run this first)
python gtm-container-builder/scripts/inspect.py path/to/GTM-XXXXXX.json

# Validate structure, references, and ID uniqueness (run before importing)
python gtm-container-builder/scripts/validate.py path/to/GTM-XXXXXX.json

# Next free numeric ID for each entity type
python gtm-container-builder/scripts/next_id.py path/to/GTM-XXXXXX.json

# Scaffold an empty WEB or SERVER container
python gtm-container-builder/scripts/scaffold.py --context WEB \
    --name "My container" --public-id GTM-AAAA111 \
    --account-id 1234567 --container-id 7654321 > new-container.json

# Compare two exports
python gtm-container-builder/scripts/diff_containers.py old.json new.json
```

`validate.py` checks matching `accountId`/`containerId`, duplicate IDs, dangling
trigger/tag/variable/folder references, `cvt_*` custom-template encoding, Web-vs-Server type
validity, and required fields.

## Privacy & safety

Every JSON in `examples/` is sanitized: account IDs, container IDs, public IDs, hostnames,
pixel/conversion IDs, API tokens, and brand strings are placeholders (`0000000000`,
`1111111`/`2222222`, `GTM-WEBXXXX`, `example.cz|.sk|.pl|.hu`, `<AW-CONV-ID-XX>`). Structure and
field order are unchanged, so they stay accurate templates. See
[`examples/README.md`](./gtm-container-builder/examples/README.md) for the full scheme.

Vendor names that appear (GA4, Google Ads, Floodlight, Meta, TikTok, Microsoft UET, Seznam,
Heureka, Stape, community templates by Simo Ahava / Ayudante) are public platforms used as
examples. They are not clients or private data.

**Never commit real container exports.** The [`.gitignore`](./.gitignore) ignores stray `*.json`
container files at the repo root while keeping the sanitized fragments under `examples/`. Real
exports can hold measurement IDs, conversion labels, first-party hostnames, and sometimes API
keys, so treat them as sensitive.

## Contributing

Issues and PRs are welcome, especially for vendors and tag types not covered yet. Sanitize any example
first (replace every real ID, hostname, and brand string per the scheme above) and run
`python gtm-container-builder/scripts/validate.py` on container JSON before submitting.

## License

[MIT](./LICENSE) © 2026 Len Pittner
