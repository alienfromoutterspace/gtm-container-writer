#!/usr/bin/env python3
"""Compare two GTM container exports (e.g. before/after an edit).

Usage:  python diff_containers.py old.json new.json

Matches entities by name within each array and reports added / removed / changed.
Ignores volatile fields (fingerprint) so you see real changes, not timestamps.
"""
import sys
import json
import gtmlib as g

IGNORE = {"fingerprint"}


def strip(e):
    return {k: v for k, v in e.items() if k not in IGNORE}


def index(cv, arr, key="name"):
    out = {}
    for e in g.iter_entities(cv, arr):
        out[e.get(key)] = e
    return out


def main(old_path, new_path):
    old = g.container_version(g.load(old_path))
    new = g.container_version(g.load(new_path))

    oc, nc = old["container"], new["container"]
    if oc.get("usageContext") != nc.get("usageContext"):
        print(f"!! usageContext changed: {oc.get('usageContext')} -> {nc.get('usageContext')}")

    any_change = False
    for arr in g.ENTITY_ARRAYS:
        key = "type" if arr == "builtInVariable" else "name"
        oidx, nidx = index(old, arr, key), index(new, arr, key)
        added = [k for k in nidx if k not in oidx]
        removed = [k for k in oidx if k not in nidx]
        changed = [k for k in nidx if k in oidx and strip(nidx[k]) != strip(oidx[k])]
        if not (added or removed or changed):
            continue
        any_change = True
        print(f"\n{arr}[]")
        for k in sorted(added):
            print(f"  + added   : {k}  [{nidx[k].get('type', '')}]")
        for k in sorted(removed):
            print(f"  - removed : {k}  [{oidx[k].get('type', '')}]")
        for k in sorted(changed):
            print(f"  ~ changed : {k}")
            of, nf = strip(oidx[k]), strip(nidx[k])
            for field in sorted(set(of) | set(nf)):
                if of.get(field) != nf.get(field):
                    ov = json.dumps(of.get(field), ensure_ascii=False)
                    nv = json.dumps(nf.get(field), ensure_ascii=False)
                    if len(ov) > 80:
                        ov = ov[:77] + "..."
                    if len(nv) > 80:
                        nv = nv[:77] + "..."
                    print(f"      {field}: {ov}  ->  {nv}")

    if not any_change:
        print("No differences (ignoring fingerprints).")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
