// ============================================================
//  ATtiny85 — Hub-motor speed signal, mirror + 2× over 25 km/h
//
//  Reads the white hall wire (motor side) on PB2.
//  Drives the white wire (controller side) on PB3.
//
//  Behaviour:
//    input speed <= 25 km/h  ->  output mirrors input 1:1
//    input speed >  25 km/h  ->  output runs at 2× input rate
//
//  Hysteresis: 1 km/h, so it doesn't chatter at the threshold.
//
// ============================================================
//  HARDWARE SETUP
// ============================================================
//
//  ── Hub motor hall connector ────────────────────────────
//    Thin RED    = +5V  (from controller)   ──┐
//    Thin BLACK  = GND  (from controller)   ──┤  power source
//    Thin GREEN  = commutation hall U       ──┤  for the ATtiny
//    Thin YELLOW = commutation hall V       ──┤
//    Thin BLUE   = commutation hall W       ──┤
//    Thin WHITE  = speed signal             ──┘  <-- CUT THIS
//
//    NOTE: the RED and BLACK wires on the hall connector are
//    simply the controller's +5V and GND rails carried down
//    the motor cable. Tapping them here is electrically the
//    same as tapping the controller's 5V harness directly —
//    it's still the controller's regulator feeding us.
//
//    The white speed wire carries ~6 pulses per wheel
//    revolution (6-magnet ring), ~18 % duty, idle HIGH,
//    LOW when a magnet passes.
//
//  ── Current budget (why this is OK) ─────────────────────
//    Controller 5V rails are typically rated 100-500 mA and
//    are already powering the three commutation halls
//    (~10 mA total) plus the speed hall (~5 mA).
//    ATtiny85 @ 1 MHz draws ~1-2 mA when running.
//    Adding 10 mA is trivial unless the rail is already
//    loaded near its limit by a throttle, display, etc.
//
//    If in doubt, measure current on the red wire before
//    and after — you should see a bump of <10 mA.
//
//    Do NOT try to power the ATtiny from the WHITE wire.
//    That wire is a signal, not a supply.
//
//  ── Cut the white wire into two halves ──────────────────
//    Motor side  = hall sensor output (idles HIGH via the
//                  controller's original pull-up; pulls LOW
//                  when a magnet passes)
//    Ctrl side   = controller's speed input (has its own
//                  internal pull-up)
//
//  ── Wiring after the cut ────────────────────────────────
//
//     Motor side of white wire
//          │
//         [1 kΩ]        series protection
//          │
//          ├──────────────── PB2 (pin 7)   hall input
//          │
//         [4.7 kΩ]      pull-up to 5V
//          │
//          └── +5V  ── tapped from the hub connector's
//                     thin RED wire (same node that feeds
//                     the hall sensor's own supply)
//
//     Controller side of white wire
//          │
//         [220 Ω]        series protection
//          │
//          └──────────────── PB3 (pin 2)   output (mirror or 2×)
//
//  ── ATtiny85 power ──────────────────────────────────────
//     Pin 8 (Vcc)  ── hub connector thin RED  (+5V)
//     Pin 4 (GND)  ── hub connector thin BLACK (GND)
//     Pin 1 (RESET) ─ leave floating (or 10 kΩ to Vcc)
//
//     Decoupling, soldered right at the chip:
//       100 nF ceramic       across pin 8 / pin 4
//       10 µF electrolytic   across pin 8 / pin 4
//
//     The 10 µF matters more than usual here because motor
//     PWM switching injects ripple onto the 5V rail.
//     Keep the wires short and route them away from the
//     three thick phase wires if possible.
//
//  ── Do NOT touch ─────────────────────────────────────────
//     Green / Yellow / Blue commutation hall wires
//     (used by the controller for motor commutation —
//      interfering with them will damage the controller
//      or cause the motor to stutter)
//
//  ── Bill of materials ────────────────────────────────────
//     1x ATtiny85 (DIP-8, internal 1 MHz, factory fuses)
//     1x 4.7 kΩ resistor   (hall pull-up)
//     1x 1 kΩ   resistor   (hall input series)
//     1x 220 Ω  resistor   (output series)
//     1x 100 nF ceramic cap
//     1x 10 µF electrolytic cap
//     1x small piece of perfboard
//
//  ── Bench check before riding ───────────────────────────
//     1. Bike on stand, wheel off the ground, power on.
//     2. Scope / fast meter on motor-side white wire —
//        clean 0/5 V square wave as the wheel spins.
//     3. Same on controller-side white wire —
//        mirrors below 25 km/h, doubles above.
//     4. Throttle up. Bike should hit its speed cap
//        earlier than usual (~2× earlier), confirming the
//        doubling is working.
//     5. Verify the ATtiny's 5V rail (pin 8) stays steady
//        while the motor is running. If it dips by more
//        than ~100 mV, add another 100 nF locally or use
//        a small LC filter (10 µH + 10 µF) inline on the
//        RED wire feeding the ATtiny.
//
//  ── Bench test with the Arduino Uno simulator ───────────
//     Uno pin 3 (SIM out) ──[1 kΩ]──┬── ATtiny PB2 (pin 7)
//                                   │
//                                  [4.7 kΩ]
//                                   │
//                                  +5V (shared)
//
//     Uno GND ──────────────────────┴── ATtiny GND (pin 4)
//     Uno 5V  ────────────────────────── ATtiny Vcc (pin 8)
//                                        (with 100nF + 10µF)
//
//     Simulator settings: MAGNETS = 6, DUTY_CYCLE = 0.18.
//
//     Set SPEED_KMH to each value and watch PB3 on a scope:
//       5  -> mirror  (278 ms period, 50.0 ms pulse)
//       20 -> mirror  (69 ms period,  12.5 ms pulse)
//       25 -> mirror  (56 ms period,  10.0 ms pulse) [threshold]
//       27 -> double  (26 ms period,  4.6 ms pulse)
//       30 -> double  (23 ms period,  4.15 ms pulse)
//
// ============================================================
//  PIN MAP (ATTinyCore, ATtiny85 @ 1 MHz internal)
// ============================================================
//    Pin 1  PB5 / RESET   unused
//    Pin 2  PB3           OUTPUT  -> controller-side white wire
//    Pin 3  PB4           unused
//    Pin 4  GND           -> hub connector thin BLACK
//    Pin 5  PB0           unused
//    Pin 6  PB1           unused
//    Pin 7  PB2 / A1      INPUT   <- motor-side white wire
//    Pin 8  Vcc           -> hub connector thin RED
//
// ============================================================

#include <avr/interrupt.h>

#define OUT_PIN      3       // PB3, physical pin 2
#define HALL_IN_PIN  2       // PB2, physical pin 7

// ---- Wheel / sensor ----
const float WHEEL_CIRCUMFERENCE_M = 29.0f * 0.0254f * PI;  // ~2.314 m
const int   PULSES_PER_REV        = 6;                     // 6-magnet ring
const float SPEED_WARN_KMH        = 25.0f;
const float SPEED_HYST_KMH        = 1.0f;

// ---- Sanity limits ----
const uint32_t MIN_INPUT_PERIOD_US = 1000;      // reject very fast glitches
const uint32_t MAX_INPUT_PERIOD_US = 1000000;   // >1 s period = stopped
const uint32_t MIN_OUT_PULSE_US    = 500;       // never shorter than this
const uint32_t MIN_OUT_PERIOD_US   = 1000;      // never faster than 1 kHz
const unsigned long STALE_MS       = 1000;      // no measurement = idle

// ---- ISR-shared state ----
volatile uint32_t tFallUs  = 0;     // timestamp of last falling edge
volatile uint32_t periodUs = 0;     // fall-to-fall period
volatile uint32_t lowUs    = 0;     // LOW pulse width (fall-to-rise)
volatile bool     newMeas  = false; // set by ISR, cleared by loop
volatile bool     doubling = false; // read by ISR (affects mirroring)

// ---- Loop-only state ----
uint32_t      outPeriodUs = 0;
uint32_t      outPulseUs  = 0;
uint32_t      tOutLastUs  = 0;
unsigned long lastMeasMs  = 0;

// ------------------------------------------------------------
//  Pin-change ISR
//    - measures input period and pulse width
//    - mirrors input level onto output when NOT in doubling mode
// ------------------------------------------------------------
ISR(PCINT0_vect)
{
  uint32_t now  = micros();
  bool     high = (PINB & (1 << HALL_IN_PIN)) != 0;

  if (high) {
    // Rising edge — capture LOW pulse width
    if (tFallUs != 0) {
      lowUs = now - tFallUs;
    }
  } else {
    // Falling edge — capture period, flag new measurement
    if (tFallUs != 0) {
      periodUs = now - tFallUs;
      newMeas  = true;
    }
    tFallUs = now;
  }

  // Mirror mode: copy input level straight to output
  if (!doubling) {
    if (high) PORTB |=  (1 << OUT_PIN);
    else      PORTB &= ~(1 << OUT_PIN);
  }
}

// ---------------- setup ----------------
void setup()
{
  pinMode(HALL_IN_PIN, INPUT);     // external 4.7k pull-up fitted
  pinMode(OUT_PIN, OUTPUT);
  digitalWrite(OUT_PIN, HIGH);     // idle high, hall-style

  PCMSK |= (1 << HALL_IN_PIN);     // unmask PCINT on PB2
  GIMSK |= (1 << PCIE);            // enable pin-change group
  sei();
}

// ---------------- main loop ----------------
void loop()
{
  // ---- Process any new measurement ----
  if (newMeas) {
    newMeas = false;

    uint32_t p = periodUs;
    uint32_t w = lowUs;

    if (p >= MIN_INPUT_PERIOD_US && p <= MAX_INPUT_PERIOD_US && w < p) {
      lastMeasMs = millis();

      // Speed: one wheel revolution = p * PULSES_PER_REV microseconds
      float revTimeSec = (p / 1e6f) * (float)PULSES_PER_REV;
      float speed_kmh  = (WHEEL_CIRCUMFERENCE_M / revTimeSec) * 3.6f;

      // Doubling decision with hysteresis
      bool wasDbl = doubling;
      if (!doubling && speed_kmh > SPEED_WARN_KMH) {
        doubling = true;
      } else if (doubling && speed_kmh < SPEED_WARN_KMH - SPEED_HYST_KMH) {
        doubling = false;
      }

      // Compute output timing
      if (doubling) {
        outPeriodUs = p / 2;      // 2× frequency -> half the period
        outPulseUs  = w / 2;      // preserve duty cycle
      } else {
        outPeriodUs = p;
        outPulseUs  = w;
      }
      if (outPeriodUs < MIN_OUT_PERIOD_US) outPeriodUs = MIN_OUT_PERIOD_US;
      if (outPulseUs  < MIN_OUT_PULSE_US)  outPulseUs  = MIN_OUT_PULSE_US;
      if (outPulseUs  >= outPeriodUs)      outPulseUs  = outPeriodUs / 2;

      // ---- Transitions ----
      if (doubling && !wasDbl) {
        // Just entered doubling: sync the output scheduler
        tOutLastUs = micros();
      }
      if (!doubling && wasDbl) {
        // Just exited doubling: snap output to input level
        digitalWrite(OUT_PIN, digitalRead(HALL_IN_PIN));
      }
    }
  }

  // ---- Idle: no input activity ----
  if (millis() - lastMeasMs > STALE_MS) {
    doubling = false;
    digitalWrite(OUT_PIN, HIGH);
    return;
  }

  // ---- Doubling: generate synthetic pulse train ----
  if (doubling) {
    uint32_t nowUs = micros();
    if ((uint32_t)(nowUs - tOutLastUs) >= outPeriodUs) {
      tOutLastUs += outPeriodUs;
      digitalWrite(OUT_PIN, LOW);
      delayMicroseconds(outPulseUs);
      digitalWrite(OUT_PIN, HIGH);
    }
  }

  // ---- Mirror mode: ISR already handles output, nothing to do here ----
}
