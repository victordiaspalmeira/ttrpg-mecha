with open('data/classes/ranger.tres', 'r', encoding='utf-8-sig') as f:
    lines = f.readlines()
print(f"Total lines: {len(lines)}")
for i, line in enumerate(lines):
    print(f"{i+1}: {repr(line)}")