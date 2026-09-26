#!/usr/bin/env python3
"""One-screen summary of a GTM container export.

Usage:  python inspect.py path/to/GTM-XXXXX.json
Always run this first on any uploaded export before editing.
"""
import sys
import collections
import gtmlib as g


def main(path):
    data = g.load(path)
    cv = g.container_version(data)
    c = cv["container"]

    print("=" * 68)
    print(f"  {c.get('name', '(unnamed)')}")
    print("=" * 68)
    print(f"  usageContext : {c.get('usageContext')}")
    print(f"  publicId     : {c.get('publicId')}")
    print(f"  containerId  : {c.get('containerId')}   (numeric)")
    print(f"  accountId    : {c.get('accountId')}")
    print(f"  exportFormat : {data.get('exportFormatVersion')}")
    tsu = c.get("taggingServerUrls")
    if tsu:
        print(f"  taggingServerUrls ({len(tsu)}):")
        for u in tsu:
            print(f"      - {u}")

    print("\n  Entity counts")
    print("  " + "-" * 30)
    for arr in g.ENTITY_ARRAYS:
        items = g.iter_entities(cv, arr)
        if arr == "builtInVariable" or items:
            print(f"    {arr:16} {len(items)}")

    # type breakdown for tags/variables/triggers
    for arr in ("tag", "trigger", "variable", "client", "transformation"):
        items = g.iter_entities(cv, arr)
        if not items:
            continue
        counter = collections.Counter(e.get("type", "?") for e in items)
        breakdown = ", ".join(f"{t}:{n}" for t, n in counter.most_common())
        print(f"\n  {arr} types: {breakdown}")

    folders = g.iter_entities(cv, "folder")
    if folders:
        print("\n  Folders:")
        for f in folders:
            print(f"    [{f.get('folderId')}] {f.get('name')}")

    cts = g.iter_entities(cv, "customTemplate")
    if cts:
        print("\n  Custom templates:")
        for t in cts:
            gref = t.get("galleryReference") or {}
            gtid = gref.get("galleryTemplateId")
            src = f"gallery:{gref.get('owner', '?')}/{gref.get('repository', '?')}" if gref else "own-code"
            code = f"cvt_{gtid}" if gtid else f"cvt_{t.get('containerId')}_{t.get('templateId')}"
            print(f"    [{t.get('templateId'):>4}] {t.get('name'):<45} {code:<24} ({src})")

    biv = g.iter_entities(cv, "builtInVariable")
    if biv:
        names = ", ".join(sorted(b.get("type", "?") for b in biv))
        print(f"\n  Enabled built-in variables: {names}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
