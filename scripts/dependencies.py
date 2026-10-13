#!/usr/bin/env python3
"""Third-party dependencies from Package.resolved, for the app's credits and the release SBOM.

    scripts/dependencies.py credits OUT.html        acknowledgements for the About panel (Credits.html)
    scripts/dependencies.py sbom VERSION OUT.json   CycloneDX 1.6 SBOM of the release

Fails if a dependency has no license file, so nothing ships without its notice.
"""
import html
import json
import re
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CHECKOUTS = ROOT / ".build" / "checkouts"
LICENSE_NAMES = ("LICENSE", "license", "LICENSE.md", "license.md", "LICENSE.txt", "COPYING")
MIT_MARKER = "Permission is hereby granted, free of charge"


def dependencies():
    resolved = json.loads((ROOT / "Package.resolved").read_text())
    for pin in sorted(resolved["pins"], key=lambda pin: pin["identity"]):
        url = pin["location"].removesuffix(".git")
        name = url.rstrip("/").split("/")[-1]
        license_file = next((CHECKOUTS / name / candidate for candidate in LICENSE_NAMES if (CHECKOUTS / name / candidate).is_file()), None)
        if license_file is None:
            sys.exit(f"No license file for {name} in {CHECKOUTS / name} (run `swift package resolve`)")
        text = license_file.read_text()
        yield {
            "name": name,
            "url": url,
            "version": pin["state"].get("version") or pin["state"]["revision"],
            "revision": pin["state"]["revision"],
            "license_text": text,
            "spdx": "MIT" if MIT_MARKER in text else None,
        }


def credits(out):
    sections = [
        f'<h3><a href="{html.escape(dep["url"])}">{html.escape(dep["name"])}</a> {html.escape(dep["version"])}</h3>'
        f'<pre>{html.escape(dep["license_text"].strip())}</pre>'
        for dep in dependencies()
    ]
    # The About panel renders this with its own font; keep the styling minimal.
    page = (
        '<!doctype html><meta charset="utf-8">'
        "<style>body{font:11px -apple-system,sans-serif}h3{font-size:12px;margin:14px 0 4px}"
        "pre{font:10px ui-monospace,Menlo,monospace;white-space:pre-wrap}</style>"
        "<p>QuickSnip is built with these open-source projects:</p>" + "".join(sections)
    )
    Path(out).write_text(page)


def purl(dep):
    path = re.sub(r"^https?://", "", dep["url"])
    return f"pkg:swift/{path}@{dep['version']}"


def sbom(version, out):
    components = []
    for dep in dependencies():
        component = {
            "type": "library",
            "bom-ref": purl(dep),
            "name": dep["name"],
            "version": dep["version"],
            "purl": purl(dep),
            "externalReferences": [{"type": "vcs", "url": dep["url"]}],
            "hashes": [{"alg": "SHA-1", "content": dep["revision"]}],
        }
        if dep["spdx"]:
            component["licenses"] = [{"license": {"id": dep["spdx"]}}]
        components.append(component)
    app_ref = f"pkg:github/andrewaldasoro/quick-snip@{version}"
    document = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "serialNumber": f"urn:uuid:{uuid.uuid4()}",
        "version": 1,
        "metadata": {
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "component": {
                "type": "application",
                "bom-ref": app_ref,
                "name": "QuickSnip",
                "version": version,
                "purl": app_ref,
                "licenses": [{"license": {"id": "MIT"}}],
            },
        },
        "components": components,
        "dependencies": [{"ref": app_ref, "dependsOn": [component["bom-ref"] for component in components]}],
    }
    Path(out).write_text(json.dumps(document, indent=2) + "\n")


if __name__ == "__main__":
    # No `match`: the system Python on macOS (Xcode's) is 3.9.
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "credits":
        credits(args[1])
    elif len(args) == 3 and args[0] == "sbom":
        sbom(args[1], args[2])
    else:
        sys.exit(__doc__)
