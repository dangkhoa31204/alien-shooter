import re
import os

tscn_path = 'k:/game/alien-shooter/scenes/contra_player.tscn'

if not os.path.exists(tscn_path):
    print(f"File not found: {tscn_path}")
    exit(1)

with open(tscn_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Find all defined IDs
defined_ids = {}
header_pattern = re.compile(r'\[ext_resource .*? id="([^"]+)"\]')
for line_num, line in enumerate(content.splitlines(), 1):
    match = header_pattern.search(line)
    if match:
        ext_id = match.group(1)
        if ext_id in defined_ids:
            print(f"DUPLICATE ID: '{ext_id}' defined at lines {defined_ids[ext_id]} and {line_num}")
        else:
            defined_ids[ext_id] = line_num

# 2. Find all used IDs
usage_pattern = re.compile(r'ExtResource\("([^"]+)"\)')
missing_ids = set()
for line_num, line in enumerate(content.splitlines(), 1):
    matches = usage_pattern.findall(line)
    for ext_id in matches:
        if ext_id not in defined_ids:
            print(f"MISSING ID: '{ext_id}' referenced at line {line_num}")
            missing_ids.add(ext_id)

if not missing_ids and not any(defined_ids.values()): # This part is slightly wrong logic but print above will catch it
    pass

print(f"Total defined IDs: {len(defined_ids)}")
