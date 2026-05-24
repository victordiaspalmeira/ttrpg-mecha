import sys

with open('scripts/presentation/battle_hud.gd', 'rb') as f:
    data = f.read()

lines = data.split(b'\n')
line = lines[32]  # linha 33 (0-indexed)

print(f'Line 33 raw bytes: {line}')
print(f'Hex: {line.hex()}')
print(f'Length: {len(line)} bytes')
print(f'Has \\r: {b"\\r" in line}')

# Check for any non-ASCII, non-printable characters
for i, b in enumerate(line):
    if b < 32 and b not in (9, 10, 13):  # not tab, LF, CR
        print(f'  Non-printable char at position {i}: byte {b}')
    if b > 127:
        print(f'  Non-ASCII char at position {i}: byte {b} (0x{b:02x})')

# Also check action_name_popup.gd
with open('scripts/presentation/action_name_popup.gd', 'rb') as f:
    data2 = f.read()

print()
print(f'action_name_popup.gd first 30 bytes hex: {data2[:30].hex()}')
print(f'Has BOM UTF-8: {data2[:3] == b"\\xef\\xbb\\xbf"}')

# Check if both files use same line endings
print(f'battle_hud has CRLF: {b"\\r\\n" in data}')
print(f'action_name_popup has CRLF: {b"\\r\\n" in data2}')