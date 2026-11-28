#!/usr/bin/env python3
"""Download Grafana dashboard 1860 (Node Exporter Full) at a fixed revision,
check it, and write it to the grafana role for provisioning."""
import json
import os
import sys
import urllib.request

DASHBOARD_ID = 1860
REVISION = 45
EXPECTED_UID = "rYdddlPWk"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "ansible", "roles", "grafana", "files", "dashboards",
                   "node-exporter-full.json")

url = f"https://grafana.com/api/dashboards/{DASHBOARD_ID}/revisions/{REVISION}/download"
req = urllib.request.Request(url, headers={"User-Agent": "course-material-devops"})
with urllib.request.urlopen(req, timeout=30) as r:
    d = json.load(r)


def strings(o):
    if isinstance(o, dict):
        for v in o.values():
            yield from strings(v)
    elif isinstance(o, list):
        for v in o:
            yield from strings(v)
    elif isinstance(o, str):
        yield o


errors = []
if d.get("uid") != EXPECTED_UID:
    errors.append(f"uid is {d.get('uid')}, expected {EXPECTED_UID}")
if any("${DS_" in s for s in strings(d)):
    errors.append("dashboard still contains ${DS_...} import placeholders")
ds_vars = [v for v in d.get("templating", {}).get("list", [])
           if v.get("type") == "datasource"]
if not ds_vars or ds_vars[0].get("query") != "prometheus":
    errors.append("no datasource variable of type prometheus found")
if errors:
    sys.exit("Dashboard check failed:\n- " + "\n- ".join(errors))

d["id"] = None
with open(OUT, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"{d['title']} revision {REVISION} (uid {d['uid']}) -> {os.path.relpath(OUT)}")
print("datasource variable:", ds_vars[0].get("name"), "->", ds_vars[0].get("query"))
