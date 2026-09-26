#!/usr/bin/env python3
"""Print the next free numeric ID for each entity type in a container.

Usage:  python next_id.py path/to/GTM-XXXXX.json

Reusing an existing ID overwrites/corrupts on import — always allocate new ones
from here when adding entities.
"""
import sys
import gtmlib as g


def next_free(cv, arr):
    idf = g.ID_FIELD[arr]
    hi = 0
    for e in g.iter_entities(cv, arr):
        val = e.get(idf)
        try:
            n = int(val)
        except (TypeError, ValueError):
            continue
        # ignore reserved built-in trigger IDs in the high range
        if arr == "trigger" and n >= g.RESERVED_TRIGGER_MIN:
            continue
        hi = max(hi, n)
    return hi + 1


def main(path):
    data = g.load(path)
    cv = g.container_version(data)
    print(f"Next free IDs for {cv['container'].get('name')} [{cv['container']['usageContext'][0]}]:")
    for arr in g.ENTITY_ARRAYS:
        if arr == "builtInVariable":
            continue  # built-ins are keyed by type, not numeric id
        items = g.iter_entities(cv, arr)
        # only show arrays that are relevant to this context / in use
        if not items and arr in ("client", "transformation", "zone", "folder", "customTemplate"):
            continue
        print(f"  {g.ID_FIELD[arr]:16} {next_free(cv, arr)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
