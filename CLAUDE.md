# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Release status

**`hubspeed/hubspeed.ino` is the released, working version 1.0.** It limits the bike to 25 km/h (release below 24 km/h), includes the noise filter, builds to 678 bytes, and is the firmware flashed to the bike's ATtiny85 chips. Treat it as the stable baseline: do not change its behaviour, limits or pin use unless asked. Any experiment (such as a lower test limit) must be reverted to these constants afterwards, and a deliberate change should be a new version, not a silent edit to 1.0.

## What this is

An ATtiny85 e-bike speed limiter. The chip listens to the hub motor's white speed wire and, above 25 km/h, pulls the controller's brake sensor line LOW as if the brake had been pressed, so the controller cuts motor power. The speed wire is joined straight through (never routed via the chip); the commutation wires (green, yellow, blue) must never be touched. [design.md](design.md) is the source of truth for the circuit, behaviour and bench checks.

Other folders are separate artefacts for the same bike: `rearlight/` (OpenSCAD fuse block parts), `case/` (OpenSCAD snap-fit case for the board), `board/` (Python scripts that lay out and draw the prototype board), `blink/` and `brake_test/` (test sketches). `breadboard.svg` and `circuit.svg` are the published diagrams, and `log.csv`/`a1log.csv` are raw captures. The blog posts that describe the project live in the sibling repo `../haddley.github.io/content/` (`attiny1.md` to `attiny4.md`, `3dprinting3.md`).

## Build and flash (hubspeed)

```
cd hubspeed
./build_and_flash.sh          # build only
./build_and_flash.sh flash    # build, then program with a FabISP (avrdude -c usbtiny -p t85)
```

There are no tests. The bench checks in design.md are the verification. The chip runs at 1 MHz internal (lfuse 0x62, hfuse 0xdf, efuse 0xff, the factory values). Check the fuses with `avrdude -c usbtiny -p t85 -U lfuse:r:-:h`.

## Things that will bite you

- **Do not compile `hubspeed.ino` as a plain sketch.** On this Mac the Arduino prototype generator (brew universal-ctags) drops return types and inserts `setup();` and `loop();` calls inside the interrupt handler. The result compiles without error and then releases the brake on every pulse. `build_and_flash.sh` builds the code as a temporary `.cpp` and checks the disassembly of `__vector_2`, refusing to flash if it calls anything but `micros`. Any new sketch with an ISR (such as `brake_test/`, which keeps its code in a `.cpp` with a stub `.ino`) needs the same treatment.
- **Native toolchain.** Arduino's bundled x86 avr-gcc and ctags fail on Apple Silicon (no Rosetta). The script points `arduino-cli` at `~/Library/Arduino15/avr-native/bin` (symlinks to brew `avr-gcc@14` and `avr-binutils`) and brew ctags. Board: `ATTinyCore:avr:attinyx5:chip=85,clock=1internal`.
- **The brake pin never drives HIGH.** PB4 is switched between output LOW (brake) and input high-Z (released) by toggling DDRB only, so it cannot fight the real brake lever, which sits in parallel on the same line (through a 220 Ω resistor).
- **Keep the ISR minimal.** It may call only `micros()`. The noise filter (ignore LOW pulses under 1.5 ms, ignore gaps under 10 ms, need 3 fast pulses in a row) exists because high motor power put spikes on the speed wire and caused false braking.
- **Speed limits are pulse gaps, not km/h.** 29 inch wheel, 6 pulses per turn: 25 km/h is 55 538 µs and 24 km/h is 57 852 µs. A lower limit for testing needs new constants (10 km/h is 138 840 µs, 9 km/h is 154 267 µs). Put the real constants back afterwards.
- `hubspeed/build/` is committed build output. `s-l140.jpg` is an unrelated eBay thumbnail and must not be committed.
- Do not modify `rearlight/fuse_block.stl`, `.scad` or `.3mf`. It is the finished part. Variants go in new files (such as `fuse_block_side_exit.*`).

## Keeping things in step

When the firmware behaviour or wiring changes, update together: the header comment in `hubspeed.ino`, [design.md](design.md), `breadboard.svg` and `circuit.svg` here, and the matching post and images (`content/attiny3.md`, `content/assets/images/attiny3/`) in the blog repo. Commit and push only when asked.
