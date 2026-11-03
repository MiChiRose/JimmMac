#!/usr/bin/env python3
"""Check static RU/EN coverage and printf argument compatibility without executing UI."""
import json
import pathlib
import re
root = pathlib.Path(__file__).resolve().parent.parent
literal = r'@"(?:\\.|[^"\\])*"'
table = (root / 'Sources/JMLocalizationTable.inc').read_text()
translations = {}
for match in re.finditer('('+literal+r'):\s*('+literal+')', table):
    ru, en = [json.loads(item[1:]) for item in match.groups()]
    translations[ru] = en
formats = re.compile(r'%(?!%)(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:ll|l|z|t|h)?[@diuoxXfFeEgGcCsSp]')
errors = []
for ru, en in translations.items():
    if formats.findall(ru) != formats.findall(en):
        errors.append('Format mismatch: ' + ru)
for source in (root / 'Sources').glob('*.m'):
    if source.name == 'JMLocalization.m':
        continue
    text = source.read_text()
    for match in re.finditer(literal, text):
        if not re.search('[А-Яа-яЁё]', match.group()):
            continue
        value = json.loads(match.group()[1:])
        if value not in translations or text[max(0, match.start()-4):match.start()] != 'JML(':
            errors.append(source.name + ': missing translation or JML call: ' + value[:100])
if errors:
    raise SystemExit('\n'.join(errors))
print('PASS: %d RU/EN strings, format arguments and source coverage' % len(translations))
