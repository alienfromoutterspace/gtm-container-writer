#!/usr/bin/env python3
"""Validate a GTM container export before importing it.

Usage:  python validate.py path/to/GTM-XXXXX.json

Checks (per SKILL.md):
  - matching accountId / containerId on every entity
  - no duplicate IDs within each entity array
  - firingTriggerId / blockingTriggerId / TRIGGER_REFERENCE resolve (or are reserved built-ins)
  - TAG_REFERENCE and setupTag / teardownTag tagName resolve
  - {{variable}} references resolve to a variable / built-in / {{_event}}
  - cvt_* types resolve to a customTemplate under the correct encoding rule
  - parentFolderId resolves
  - WEB-only vs SERVER-only type codes are used in the right context
  - required fields (name, type) present

Exit code 0 if clean, 1 if any ERROR was found. WARNINGs never fail the build.
"""
import sys
import collections
import gtmlib as g

errors = []
warnings = []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


def main(path):
    data = g.load(path)
    cv = g.container_version(data)
    c = cv["container"]
    ctx = c["usageContext"][0]
    acct = c.get("accountId")
    cid = c.get("containerId")
    server = ctx == "SERVER"

    # ---- IDs & account/container consistency -------------------------------
    trigger_ids = set()
    tag_names = set()
    folder_ids = set()
    for arr in g.ENTITY_ARRAYS:
        idf = g.ID_FIELD.get(arr)
        seen = set()
        for e in g.iter_entities(cv, arr):
            eid = e.get(idf) if idf else None
            if idf and eid is not None:
                if eid in seen:
                    err(f"duplicate {idf}={eid} in {arr}[]")
                seen.add(eid)
            if arr in ("tag", "trigger", "variable", "client", "transformation",
                       "folder", "customTemplate", "zone"):
                if "accountId" in e and e["accountId"] != acct:
                    err(f"{arr} '{e.get('name', eid)}' accountId {e['accountId']} != container {acct}")
                if "containerId" in e and e["containerId"] != cid:
                    err(f"{arr} '{e.get('name', eid)}' containerId {e['containerId']} != container {cid}")
            if arr in ("tag", "trigger", "variable", "client", "transformation") and not e.get("name"):
                err(f"{arr} {idf}={eid} missing required 'name'")
            if arr in ("tag", "trigger", "variable", "client", "transformation") and not e.get("type"):
                err(f"{arr} '{e.get('name', eid)}' missing required 'type'")
        if arr == "trigger":
            trigger_ids = seen
        elif arr == "tag":
            tag_names = {t.get("name") for t in g.iter_entities(cv, arr)}
        elif arr == "folder":
            folder_ids = seen

    # ---- trigger references -------------------------------------------------
    def check_trigger_ref(tid, where):
        if tid in trigger_ids:
            return
        if tid in g.RESERVED_TRIGGER_IDS:
            return
        try:
            if int(tid) >= g.RESERVED_TRIGGER_MIN:
                return  # unlisted built-in in the reserved range
        except (TypeError, ValueError):
            pass
        err(f"{where} references triggerId {tid} which does not exist")

    for t in g.iter_entities(cv, "tag"):
        for tid in t.get("firingTriggerId", []) or []:
            check_trigger_ref(tid, f"tag '{t.get('name')}' firingTriggerId")
        for tid in t.get("blockingTriggerId", []) or []:
            check_trigger_ref(tid, f"tag '{t.get('name')}' blockingTriggerId")
        if not t.get("firingTriggerId") and not t.get("paused"):
            warn(f"tag '{t.get('name')}' has no firingTriggerId — it will never fire "
                 f"(ok only if it's a setup/teardown target)")

    # TRIGGER_REFERENCE inside parameters (e.g. TRIGGER_GROUP, some tags)
    for arr in ("tag", "trigger", "variable"):
        for e in g.iter_entities(cv, arr):
            for p in g.walk_parameters(e.get("parameter", [])):
                if p.get("type") == "TRIGGER_REFERENCE":
                    check_trigger_ref(p.get("value"), f"{arr} '{e.get('name')}' TRIGGER_REFERENCE")

    # ---- tag references (setup/teardown + TAG_REFERENCE) -------------------
    for t in g.iter_entities(cv, "tag"):
        for seq in ("setupTag", "teardownTag"):
            for ref in t.get(seq, []) or []:
                nm = ref.get("tagName") if isinstance(ref, dict) else None
                if nm and nm not in tag_names:
                    err(f"tag '{t.get('name')}' {seq} references tag '{nm}' which does not exist")
    for arr in ("tag", "trigger", "variable", "transformation"):
        for e in g.iter_entities(cv, arr):
            for p in g.walk_parameters(e.get("parameter", [])):
                if p.get("type") == "TAG_REFERENCE" and p.get("value") not in tag_names:
                    err(f"{arr} '{e.get('name')}' TAG_REFERENCE '{p.get('value')}' does not exist")

    # ---- variable references ------------------------------------------------
    known_vars = g.all_variable_names(cv)
    for arr in ("tag", "trigger", "variable", "client", "transformation"):
        for e in g.iter_entities(cv, arr):
            for ref in g.template_var_refs(e):
                # allow dotted/nested lookups on a known base only if exact match fails
                if ref not in known_vars:
                    warn(f"{arr} '{e.get('name')}' uses {{{{{ref}}}}} which is not a defined "
                         f"variable or enabled built-in")

    # ---- parentFolderId -----------------------------------------------------
    for arr in ("tag", "trigger", "variable"):
        for e in g.iter_entities(cv, arr):
            pf = e.get("parentFolderId")
            if pf and pf not in folder_ids:
                err(f"{arr} '{e.get('name')}' parentFolderId {pf} does not exist")

    # ---- cvt_* encoding -----------------------------------------------------
    valid_cvt = g.valid_cvt_types(cv)
    for arr in ("tag", "variable", "client", "transformation"):
        for e in g.iter_entities(cv, arr):
            ty = e.get("type", "")
            if ty.startswith("cvt_") and ty not in valid_cvt:
                err(f"{arr} '{e.get('name')}' type '{ty}' has no matching customTemplate "
                    f"(check gallery vs own-code encoding)")

    # ---- context sanity -----------------------------------------------------
    for t in g.iter_entities(cv, "tag"):
        ty = t.get("type", "")
        if server and ty in g.WEB_ONLY_TYPES:
            err(f"WEB-only tag type '{ty}' ('{t.get('name')}') in a SERVER container")
        if not server and ty in g.SERVER_ONLY_TYPES:
            err(f"SERVER-only tag type '{ty}' ('{t.get('name')}') in a WEB container")
    if not server and (g.iter_entities(cv, "client") or g.iter_entities(cv, "transformation")):
        err("client[] / transformation[] present in a WEB container (SERVER-only)")
    for v in g.iter_entities(cv, "variable"):
        ty = v.get("type", "")
        if server and ty in g.WEB_ONLY_VAR_TYPES:
            warn(f"WEB-oriented variable type '{ty}' ('{v.get('name')}') in a SERVER container")
        if not server and ty in g.SERVER_ONLY_VAR_TYPES:
            warn(f"SERVER-oriented variable type '{ty}' ('{v.get('name')}') in a WEB container")

    # ---- report -------------------------------------------------------------
    print(f"Validated: {c.get('name')} [{ctx}]  ({data.get('exportFormatVersion')})")
    print(f"  tags={len(g.iter_entities(cv,'tag'))} triggers={len(g.iter_entities(cv,'trigger'))} "
          f"variables={len(g.iter_entities(cv,'variable'))} "
          f"clients={len(g.iter_entities(cv,'client'))} "
          f"transformations={len(g.iter_entities(cv,'transformation'))} "
          f"templates={len(g.iter_entities(cv,'customTemplate'))}")
    if warnings:
        print(f"\n  {len(warnings)} WARNING(S):")
        for w in warnings:
            print(f"    ! {w}")
    if errors:
        print(f"\n  {len(errors)} ERROR(S):")
        for e in errors:
            print(f"    x {e}")
        print("\nFAIL")
        return 1
    print("\nOK — no errors." + ("  (warnings above are advisory)" if warnings else ""))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
