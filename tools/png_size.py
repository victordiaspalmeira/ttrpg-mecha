import struct
import sys
from pathlib import Path

folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent.parent / "assets/sprites/units/placeholder"
for path in sorted(folder.glob("Gr1_*.png")):
    data = path.read_bytes()
    w, h = struct.unpack(">II", data[16:24])
    print(f"{path.name}\t{w}x{h}")
