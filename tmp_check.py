import re, sys

file = r'k:\game\alien-shooter\scenes\contra_player.tscn'
with open(file, 'r', encoding='utf-8') as f:
    content = f.read()

ext_ids = re.findall(r'\[ext_resource .*? id=\"(.*?)\"\]', content)
sub_ids = re.findall(r'\[sub_resource .*? id=\"(.*?)\"\]', content)
all_ids = set(ext_ids + sub_ids)

print('Duplicate Ext/Sub IDs:')
seen = set()
for x in ext_ids + sub_ids:
    if x in seen:
        print(f' Duplicate: {x}')
    seen.add(x)

used_exts = re.findall(r'ExtResource\(\"(.*?)\"\)', content)
missing = [x for x in used_exts if x not in all_ids]
if missing:
    print('Missing ExtResource definitions:')
    for m in set(missing):
        print(f' Missing: {m}')
else:
    print('No missing ExtReferences.')

print('Total Ext resources:', len(ext_ids))
