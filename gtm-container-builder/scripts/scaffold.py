#!/usr/bin/env python3
"""Scaffold an empty, importable GTM container shell.

Usage:
  python scaffold.py --context WEB|SERVER --name "My container" \
      --public-id GTM-XXXXXX --account-id 1234567 --container-id 7654321 \
      [--server-url https://hub.example.tld] > new-container.json

If you don't know the real IDs yet, leave the placeholders — but replace them
before import, or import into a real container that will overwrite them.
"""
import argparse
import json
import sys
import time

WEB_FEATURES = {
    "supportUserPermissions": True, "supportEnvironments": True,
    "supportWorkspaces": True, "supportGtagConfigs": False,
    "supportBuiltInVariables": True, "supportClients": False,
    "supportFolders": True, "supportTags": True, "supportTemplates": True,
    "supportTriggers": True, "supportVariables": True, "supportVersions": True,
    "supportZones": True, "supportTransformations": False,
}
SERVER_FEATURES = dict(WEB_FEATURES, supportClients=True, supportTransformations=True)

# A minimal set of commonly-enabled built-ins per context.
WEB_BUILTINS = ["PAGE_URL", "PAGE_HOSTNAME", "PAGE_PATH", "REFERRER", "EVENT"]
SERVER_BUILTINS = ["EVENT_NAME", "CLIENT_NAME"]

BUILTIN_NAME = {
    "PAGE_URL": "Page URL", "PAGE_HOSTNAME": "Page Hostname", "PAGE_PATH": "Page Path",
    "REFERRER": "Referrer", "EVENT": "Event",
    "EVENT_NAME": "Event Name", "CLIENT_NAME": "Client Name",
}


def build(context, name, public_id, account_id, container_id, server_url):
    server = context == "SERVER"
    now = str(int(time.time() * 1000))
    container = {
        "path": f"accounts/{account_id}/containers/{container_id}",
        "accountId": account_id,
        "containerId": container_id,
        "name": name,
        "publicId": public_id,
        "usageContext": [context],
        "fingerprint": now,
        "tagManagerUrl": "",
        "features": SERVER_FEATURES if server else WEB_FEATURES,
        "tagIds": [public_id],
    }
    if server:
        urls = [server_url] if server_url else ["https://hub.example.tld"]
        container["taggingServerUrls"] = urls

    builtins = SERVER_BUILTINS if server else WEB_BUILTINS
    biv = [{"type": t, "name": BUILTIN_NAME.get(t, t),
            "accountId": account_id, "containerId": container_id} for t in builtins]

    cv = {
        "path": f"accounts/{account_id}/containers/{container_id}/versions/0",
        "accountId": account_id,
        "containerId": container_id,
        "containerVersionId": "0",
        "container": container,
        "builtInVariable": biv,
        "tag": [],
        "trigger": [],
        "variable": [],
        "folder": [],
        "fingerprint": now,
    }
    if server:
        cv["client"] = []
        cv["transformation"] = []

    return {
        "exportFormatVersion": 2,
        "exportTime": time.strftime("%Y-%m-%d %H:%M:%S"),
        "containerVersion": cv,
    }


def main():
    ap = argparse.ArgumentParser(description="Scaffold an empty GTM container shell.")
    ap.add_argument("--context", required=True, choices=["WEB", "SERVER"])
    ap.add_argument("--name", required=True)
    ap.add_argument("--public-id", default="GTM-XXXXXX")
    ap.add_argument("--account-id", default="0000000000")
    ap.add_argument("--container-id", default="00000000")
    ap.add_argument("--server-url", default=None, help="SERVER only: first-party tagging URL")
    args = ap.parse_args()

    out = build(args.context, args.name, args.public_id,
                args.account_id, args.container_id, args.server_url)
    json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
