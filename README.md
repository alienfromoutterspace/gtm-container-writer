# GTM Container Builder — a Claude Skill

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Skill](https://img.shields.io/badge/Claude-Skill-8A63D2.svg)](https://docs.claude.com/en/docs/claude-code/skills)
[![Python](https://img.shields.io/badge/Python-3%20(stdlib%20only)-3776AB.svg)](#helper-scripts)

A [Claude Skill](https://docs.claude.com/en/docs/claude-code/skills) for reading, writing,
validating, and editing **Google Tag Manager (GTM) container JSON exports** — both **Web** and
**Server-side (sGTM)**. It teaches Claude the full container grammar (tags, triggers, variables,
clients, transformations, custom templates) plus the real-world architectural patterns that make
production containers maintainable, and ships a set of dependency-free Python helpers for
scaffolding, inspecting, validating, and diffing containers.

> The format this skill works with is what **Admin → Export Container** produces in the GTM UI,
> and what **Admin → Import Container** consumes.

---

## Why this exists

A GTM export is a single JSON file that's really a **graph**: tags reference triggers, triggers
reference variables, variables reference other variables, tags reference other tags for
sequencing, and custom-template types have a fiddly `cvt_*` encoding. One broken reference and the
import fails — or worse, imports fine and breaks silently at runtime.

This skill gives Claude:

- **The rules of referential integrity** so edits don't break the graph.
- **A catalogue of every entity/type code** you'll meet in real Web and Server exports.
- **17 battle-tested architectural patterns** distilled from production multi-market e-commerce +
  sGTM + first-party-serving setups (ID-Lookup variables, regex-consolidated triggers,
  source-gating, browser/server `event_id` dedup, CookieMonster ITP mitigation, centralized
  `gtcs`/`gtes` settings, server-side PII hashing, the GA4→sGTM transport bus, and more).
- **Sanitized, copy-paste-ready examples** of every entity type.
- **Helper scripts** that run on plain Python 3 (no `pip install`).

## What it can do

- **Edit an existing export** — open a `.json`, add/change/remove entities, hand back a valid,
  importable file with references intact.
- **Build a new container from scratch** — scaffold a fresh Web or Server shell and fill it with
  tags, triggers, and variables.
- **Validate** structure, reference integrity, and ID uniqueness before you import.
- **Inspect** any export to get a one-screen summary of what's inside.
- **Diff** two exports (e.g. before/after an edit).

## Repository layout

```
gtm-container-writer/
├── README.md                    ← you are here
├── LICENSE                      ← MIT
└── gtm-container-builder/       ← the skill (copy this folder into your skills dir)
    ├── SKILL.md                 ← the skill definition Claude loads
    ├── references/              ← deep-dive catalogues (type codes, parameter grammar, …)
    │   ├── container-shell.md
    │   ├── parameter-format.md
    │   ├── tag-types.md
    │   ├── trigger-types.md
    │   ├── variable-types.md
    │   ├── server-specific.md
    │   └── custom-templates.md
    ├── examples/                ← one sanitized, real-shaped JSON per entity type
    │   ├── README.md
    │   ├── shell-web.json / shell-server.json   (complete importable empty containers)
    │   ├── web-tags.json / web-triggers.json / web-variables.json
    │   └── server-*.json        (tags, triggers, variables, clients, transformations)
    └── scripts/                 ← Python 3 stdlib-only helpers
        ├── inspect.py
        ├── validate.py
        ├── next_id.py
        ├── scaffold.py
        ├── diff_containers.py
        └── gtmlib.py            (shared helpers)
```

## Installation

The skill lives in the `gtm-container-builder/` folder. Drop that folder into wherever your
Claude client discovers skills.

**Claude Code (project-scoped):**
```bash
git clone https://github.com/alienfromoutterspace/gtm-container-writer.git
mkdir -p .claude/skills
cp -r gtm-container-writer/gtm-container-builder .claude/skills/
```

**Claude Code (personal, all projects):**
```bash
cp -r gtm-container-writer/gtm-container-builder ~/.claude/skills/
```

That's it — no dependencies to install. The scripts use only the Python 3 standard library.
Restart your Claude session (or start a new one) and the skill will be available; Claude loads it
automatically when a request matches its description (a GTM export, a `GTM-XXXXXX` container,
`containerVersion`, sGTM, scaffolding/validating/diffing a container, custom templates, etc.).

> **Other Claude surfaces:** the skill is a standard `SKILL.md` + resources bundle, so it also
> works anywhere skills are supported (Claude Desktop / claude.ai skill upload, Agent SDK). Point
> your uploader at the `gtm-container-builder/` folder.

## Usage

Once installed, just ask Claude in natural language. Examples:

- *"Here's my GTM export — add a GA4 event tag for `add_to_cart` that fires on the ecommerce
  regex trigger."*
- *"Scaffold a new server-side container called `Acme sGTM`."*
- *"Validate this container and tell me what's broken."*
- *"Diff these two exports and summarize what changed."*
- *"Convert this per-market duplicated setup to a single ID-Lookup variable."*

Claude will use the reference docs and examples to produce correct output, and run the helper
scripts to validate before handing anything back.

### Helper scripts

You can also run the scripts directly (they're the same ones Claude uses):

```bash
# One-screen summary of a container — always the first thing to run
python gtm-container-builder/scripts/inspect.py path/to/GTM-XXXXXX.json

# Validate structure, reference integrity, and ID uniqueness
python gtm-container-builder/scripts/validate.py path/to/GTM-XXXXXX.json

# Get the next free numeric ID for each entity type
python gtm-container-builder/scripts/next_id.py path/to/GTM-XXXXXX.json

# Scaffold an empty WEB or SERVER container
python gtm-container-builder/scripts/scaffold.py --context WEB \
    --name "My container" --public-id GTM-AAAA111 \
    --account-id 1234567 --container-id 7654321 > new-container.json

# Compare two exports (before/after an edit)
python gtm-container-builder/scripts/diff_containers.py old.json new.json
```

`validate.py` is the one to run before importing anything. It checks matching
`accountId`/`containerId`, duplicate IDs, dangling trigger/tag/variable/folder references,
correct `cvt_*` custom-template encoding, Web-vs-Server type validity, and required fields.

## Privacy & safety

Every JSON in `examples/` is **sanitized**: account IDs, container IDs, public IDs, hostnames,
pixel/conversion IDs, API tokens, and brand strings are all replaced with placeholders
(`0000000000`, `1111111`/`2222222`, `GTM-WEBXXXX`, `example.cz|.sk|.pl|.hu`, `<AW-CONV-ID-XX>`,
etc.). Structure and field order are otherwise untouched, so they remain accurate templates. See
[`gtm-container-builder/examples/README.md`](./gtm-container-builder/examples/README.md) for the
full placeholder scheme.

Vendor names that appear (GA4, Google Ads, Floodlight, Meta, TikTok, Microsoft UET, Seznam,
Heureka, Stape, Simo Ahava's / Ayudante's community templates, …) are **public advertising and
tooling platforms** used as realistic examples — not clients, and not private data.

**Never commit real container exports.** The included [`.gitignore`](./.gitignore) is configured
to ignore stray `*.json` container files at the repo root while keeping the sanitized fragments
under `examples/`. Real exports can contain measurement IDs, conversion labels, first-party
hostnames, and occasionally API keys — treat them as sensitive.

## Contributing

Issues and PRs welcome. If you contribute an example, **sanitize it first** (replace every real
ID, hostname, and brand string with the placeholder scheme above) and run
`python gtm-container-builder/scripts/validate.py` on any container JSON before submitting.

## License

[MIT](./LICENSE) © 2026 Len Pittner
