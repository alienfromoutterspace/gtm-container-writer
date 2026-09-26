"""Shared helpers for the GTM container-builder scripts. Python 3, stdlib only."""
import json
import re

# Numeric IDs in this reserved high range are built-in triggers that never appear
# as objects in trigger[] — they are referenced directly by firingTriggerId.
RESERVED_TRIGGER_IDS = {
    "2147479553": "All Pages (Page View) - WEB",
    "2147479572": "Initialization - All Pages - WEB",
    "2147479573": "Consent Initialization - All Pages - WEB",
    "2147479574": "All Events / Any Event - SERVER",
}
RESERVED_TRIGGER_MIN = 2000000000  # anything >= this that isn't in trigger[] is treated as built-in

# The magic runtime variable available on every CUSTOM_EVENT trigger. Not in builtInVariable[].
RUNTIME_VARS = {"_event"}

ENTITY_ARRAYS = [
    "tag", "trigger", "variable", "client", "transformation",
    "folder", "builtInVariable", "customTemplate", "zone",
]

ID_FIELD = {
    "tag": "tagId", "trigger": "triggerId", "variable": "variableId",
    "client": "clientId", "transformation": "transformationId",
    "folder": "folderId", "customTemplate": "templateId", "zone": "zoneId",
}

# Type codes that are only valid in one usage context.
WEB_ONLY_TYPES = {
    "html", "gaawe", "googtag", "gclidw", "awct", "flc", "fls", "baut",
    "sp", "img", "gclidw",
}
SERVER_ONLY_TYPES = {
    "sgtmgaaw", "sgtmadsct", "sgtmadscl", "sgtmadsremarket",
}
# Variable type codes only valid server-side / web-side (partial — used for hints, not hard fails
# beyond the obvious tag ones above).
SERVER_ONLY_VAR_TYPES = {"ed", "sgtmk", "rh", "vr", "cn"}
WEB_ONLY_VAR_TYPES = {"aev", "gtes", "gtcs", "awec", "u", "k", "j", "f"}

VAR_REF_RE = re.compile(r"\{\{([^{}]+)\}\}")


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def container_version(data):
    return data["containerVersion"]


def context(data):
    return container_version(data)["container"]["usageContext"][0]


def is_server(data):
    return context(data) == "SERVER"


def iter_entities(cv, arr):
    return cv.get(arr, []) or []


def valid_cvt_types(cv):
    """Map every customTemplate to the cvt_* type code that entities must use to reference it.

    Gallery template with galleryTemplateId -> cvt_<galleryTemplateId>
    Own code / gallery without galleryTemplateId -> cvt_<containerId>_<templateId>
    Returns {cvt_code: template_name}.
    """
    out = {}
    for t in iter_entities(cv, "customTemplate"):
        tid = t.get("templateId")
        cid = t.get("containerId")
        gref = t.get("galleryReference") or {}
        gtid = gref.get("galleryTemplateId")
        if gtid:
            out[f"cvt_{gtid}"] = t.get("name", "?")
        else:
            out[f"cvt_{cid}_{tid}"] = t.get("name", "?")
    return out


def all_variable_names(cv):
    names = set()
    for v in iter_entities(cv, "variable"):
        if v.get("name"):
            names.add(v["name"])
    for b in iter_entities(cv, "builtInVariable"):
        if b.get("name"):
            names.add(b["name"])
    names |= RUNTIME_VARS
    return names


def walk_parameters(params):
    """Yield every parameter dict recursively (MAP/LIST descend)."""
    for p in params or []:
        yield p
        if p.get("type") == "MAP":
            yield from walk_parameters(p.get("map", []))
        elif p.get("type") == "LIST":
            for item in p.get("list", []):
                # list items are usually MAPs, sometimes bare params
                if item.get("type") == "MAP":
                    yield item
                    yield from walk_parameters(item.get("map", []))
                else:
                    yield item


def template_var_refs(entity):
    """Every {{name}} referenced inside TEMPLATE-type parameter values of an entity."""
    refs = set()
    for p in walk_parameters(entity.get("parameter", [])):
        if p.get("type") == "TEMPLATE" and isinstance(p.get("value"), str):
            for m in VAR_REF_RE.findall(p["value"]):
                refs.add(m.strip())
    # some entity types keep filters outside parameter[]
    for fkey in ("filter", "customEventFilter", "autoEventFilter"):
        for f in entity.get(fkey, []) or []:
            for p in f.get("parameter", []):
                if p.get("type") == "TEMPLATE" and isinstance(p.get("value"), str):
                    for m in VAR_REF_RE.findall(p["value"]):
                        refs.add(m.strip())
    return refs
