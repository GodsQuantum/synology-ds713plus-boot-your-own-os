#!/usr/bin/env python3
from pathlib import Path
import re
from urllib.parse import unquote

root=Path(__file__).resolve().parents[1]
errors=[]
pat=re.compile(r'(?<!!)\[[^\]]*\]\(([^)]+)\)')
for md in root.rglob('*.md'):
    if '.git' in md.parts: continue
    data=md.read_text(errors='replace')
    for target in pat.findall(data):
        target=target.strip()
        if not target or target.startswith(('#','http://','https://','mailto:')):
            continue
        target=target.split('#',1)[0]
        target=unquote(target)
        if not (md.parent/target).resolve().exists():
            errors.append(f'{md.relative_to(root)} -> {target}')
if errors:
    raise SystemExit('broken relative Markdown links:\n'+'\n'.join(errors))
print('MARKDOWN_LINK_TESTS=PASS')
