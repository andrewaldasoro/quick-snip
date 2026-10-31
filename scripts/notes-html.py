#!/usr/bin/env python3
"""Turns one CHANGELOG.md section (stdin, as printed by release-notes.sh) into the small HTML
fragment Sparkle embeds in the appcast: ### headings, - items (wrapped lines joined),
**bold** and `code`. No <body>, so generate_appcast embeds it rather than linking it."""
import html
import re
import sys


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", text)


def convert(markdown):
    out, items, paragraph = [], [], []

    def flush():
        if items:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
            items.clear()
        if paragraph:
            out.append(f"<p>{inline(' '.join(paragraph))}</p>")
            paragraph.clear()

    for line in markdown.splitlines():
        if line.startswith("### "):
            flush()
            out.append(f"<h3>{inline(line[4:].strip())}</h3>")
        elif line.startswith("- "):
            if paragraph:
                flush()
            items.append(line[2:].strip())
        elif line.startswith("  ") and items:
            items[-1] += " " + line.strip()
        elif line.strip():
            if items:
                flush()
            paragraph.append(line.strip())
        else:
            flush()
    flush()
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    sys.stdout.write(convert(sys.stdin.read()))
