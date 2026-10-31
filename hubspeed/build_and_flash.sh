#!/bin/bash
# Build hubspeed.ino for the ATtiny85 (1 MHz internal) and, with the word "flash", program it with a FabISP.
#
#   ./build_and_flash.sh          build only
#   ./build_and_flash.sh flash    build, then program the chip
#
# Why the .ino is built as a .cpp:
# for an .ino file the Arduino build generates function prototypes with ctags. On this Mac that step drops the
# return types and, in this sketch, inserts "setup();" and "loop();" calls into the middle of the interrupt
# handler, so setup() ran on every wheel pulse and released the brake line. A .cpp file is not processed that way.
# The code in hubspeed.ino is unchanged: this script only prepends #include <Arduino.h> to a temporary copy.
set -euo pipefail
cd "$(dirname "$0")"

TMP="$(mktemp -d)/hubspeed"
mkdir -p "$TMP"
{ echo '#include <Arduino.h>'; cat hubspeed.ino; } > "$TMP/hubspeed.cpp"
echo '// built from hubspeed.ino by build_and_flash.sh' > "$TMP/hubspeed.ino"

arduino-cli compile \
  --fqbn ATTinyCore:avr:attinyx5:chip=85,clock=1internal \
  --build-property compiler.path=/Users/neilhaddley/Library/Arduino15/avr-native/bin/ \
  --build-property tools.ctags.path=/opt/homebrew/bin \
  --build-property tools.ctags.cmd.path=/opt/homebrew/bin/ctags \
  --output-dir build "$TMP"

# Safety check: the interrupt handler must not call setup() or loop()
OBJDUMP=/Users/neilhaddley/Library/Arduino15/avr-native/bin/avr-objdump
if "$OBJDUMP" -d build/hubspeed.ino.elf | python3 -c '
import re, sys
lines = sys.stdin.read().splitlines()
start = next(i for i, l in enumerate(lines) if "<__vector_2>:" in l)
end = next(i for i in range(start + 1, len(lines)) if re.match(r"^[0-9a-f]+ <[A-Za-z_][^.>]*>:$", lines[i]))
calls = [m.group(1) for l in lines[start:end] for m in [re.search(r"\b(?:rcall|call)\b.*<([^>]+)>", l)] if m]
bad = [c for c in calls if c in ("setup", "loop")]
print("interrupt handler calls:", calls)
sys.exit(1 if bad else 0)
'; then
  echo "OK: the interrupt handler does not call setup() or loop()"
else
  echo "ERROR: the interrupt handler calls setup() or loop(). Not flashing." >&2
  exit 1
fi

if [ "${1:-}" = "flash" ]; then
  avrdude -c usbtiny -p t85 -U flash:w:build/hubspeed.ino.hex:i
fi
