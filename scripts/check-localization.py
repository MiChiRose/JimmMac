#!/usr/bin/env python3
"""Check static RU/EN/UK/BE coverage and printf argument compatibility without executing UI."""
import json
import pathlib
import re
root = pathlib.Path(__file__).resolve().parent.parent
literal = r'@"(?:\\.|[^"\\])*"'
def read_table(name):
    table = (root / 'Sources' / name).read_text()
    entries = [tuple(json.loads(item[1:]) for item in match.groups())
               for match in re.finditer('('+literal+r'):\s*('+literal+')', table)]
    result = dict(entries)
    if len(result) != len(entries):
        raise SystemExit('Duplicate key in ' + name)
    return result

translations = read_table('JMLocalizationTable.inc')
formats = re.compile(r'%(?!%)(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:ll|l|z|t|h)?[@diuoxXfFeEgGcCsSp]')
errors = []
for language, table in [('EN', translations), ('UK', read_table('JMLocalizationUK.inc')),
                        ('BE', read_table('JMLocalizationBE.inc'))]:
    for key in translations.keys() - table.keys():
        errors.append(language + ' missing key: ' + key)
    for key in table.keys() - translations.keys():
        errors.append(language + ' unexpected key: ' + key)
    for ru, localized in table.items():
        if not localized.strip() or formats.findall(ru) != formats.findall(localized):
            errors.append(language + ' empty translation or format mismatch: ' + ru)
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
print('PASS: %d RU/EN/UK/BE keys, format arguments and source coverage' % len(translations))
