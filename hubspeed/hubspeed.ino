// ============================================================
//  ATtiny85 — e-bike speed limiter, through the brake sensor line
//
//  VERSION 1.0 — RELEASED, WORKING VERSION
//  This is the released, working version of the hubspeed code. It
//  limits the bike to 25 km/h (release below 24 km/h), 678 bytes
//  built with hubspeed/build_and_flash.sh. Flash it with
//  ./build_and_flash.sh flash. Do not build it as a plain .ino
//  (see build_and_flash.sh for why).
//
//  The motor's white speed wire and the controller's white wire
//  are joined together, so the speed signal reaches the controller
//  and the display exactly as it did before. The ATtiny only LISTENS
//  to that wire on PB2, and when the bike is faster than the limit it
//  pulls the brake sensor line LOW on PB4, as if the brake had been
//  pressed. The controller then cuts power to the motor.
//
//  Behaviour:
//    3 wheel pulses in a row faster than 25 km/h -> brake line pulled LOW
//                                                   (motor cut)
//    a wheel pulse slower than 24 km/h           -> brake line released
//                                                   (motor runs)
//    no wheel pulses for 1 s                     -> brake line released
//
//  The 1 km/h gap between 25 and 24 stops it chattering at the limit.
//
//  Noise: at high motor power the speed wire picks up spikes. A real
//  wheel pulse is LOW for several milliseconds, so anything LOW for
//  less than 1.5 ms is ignored, and the brake is only applied after 3
//  fast pulses in a row, so one stray pulse cannot trigger it.
//
//  If the ATtiny fails or loses power, the brake line is released and
//  the speed wire is still joined: the bike behaves as it did before.
//
// ============================================================
//  WIRING
// ============================================================
//
//  Speed wire (the white wire in the hub motor's hall connector):
//    Join the motor-side half and the controller-side half together.
//    Tap the joined wire to PB2 (pin 7) through a 1 kΩ resistor.
//    Optional: a 100 nF capacitor from PB2 to GND. With the 1 kΩ it
//    filters short noise spikes before they reach the chip.
//    The controller's own pull-up holds the wire HIGH; each magnet
//    passing the hall sensor pulls it LOW (about 6 pulses per wheel
//    turn, idle HIGH, about 18 % LOW).
//
//  Brake sensor line (measured: about 5 V open circuit, 0.4 mA short
//  circuit, so the controller pulls it up through about 12.5 kΩ and
//  the brake lever pulls it to ground):
//    brake wire that reads 5 V ──[220 Ω]── PB4 (pin 3)
//    brake wire that reads 0 V ─────────── GND (pin 4)
//    Leave the brake lever connected: the lever and the ATtiny are
//    two switches on the same line, so either one applies the brake.
//    Cutoff: PB4 = output LOW. Released: PB4 = input, high-Z. The pin
//    never drives HIGH, so it cannot fight the lever.
//
//  Power (the hub connector's thin RED and BLACK wires are the
//  controller's own +5 V and GND):
//    Pin 8 (Vcc) ── RED  (+5 V)
//    Pin 4 (GND) ── BLACK
//    100 nF ceramic and 10 µF capacitors across pin 8 / pin 4, right
//    at the chip. Motor PWM puts ripple on the 5 V rail.
//
//  Do NOT touch the green, yellow and blue commutation hall wires.
//
//  Parts: ATtiny85 (internal 1 MHz, factory fuses), 1 kΩ, 220 Ω,
//  100 nF ceramic and 10 µF capacitors for the supply, and the
//  optional 100 nF ceramic on PB2.
//
// ============================================================
//  BENCH CHECK (wheel off the ground)
// ============================================================
//    Spin the wheel past the limit: the brake line reads about 0 V and
//    the motor cuts. Slow below the release speed: it reads about 5 V and the
//    motor runs again.
//
// ============================================================
//  PIN MAP
// ============================================================
//    Pin 1  PB5 / RESET   unused
//    Pin 2  PB3           unused
//    Pin 3  PB4           OUTPUT  -> brake sensor line (via 220 Ω)
//    Pin 4  GND
//    Pin 5  PB0           unused
//    Pin 6  PB1           unused
//    Pin 7  PB2           INPUT   <- speed wire (via 1 kΩ)
//    Pin 8  Vcc
//
// ============================================================

#include <avr/interrupt.h>

#define HALL_IN_PIN  2       // PB2, physical pin 7
#define BRAKE_PIN    4       // PB4, physical pin 3

// Output register bit stays 0, so switching the pin to an output pulls
// the brake line LOW, and switching it to an input lets it go.
#define BRAKE_ON()   (DDRB |=  (1 << BRAKE_PIN))
#define BRAKE_OFF()  (DDRB &= ~(1 << BRAKE_PIN))

// Time between wheel pulses at a given speed
// (29 inch wheel, 2.314 m round, 6 magnets, so 6 pulses per turn):
//   25 km/h -> a pulse every 55 538 µs
//   24 km/h -> a pulse every 57 852 µs
const uint32_t CUT_PERIOD_US     = 55538UL;   // shorter than this: faster than 25 km/h
const uint32_t RELEASE_PERIOD_US = 57852UL;   // longer than this: slower than 24 km/h
const uint32_t MIN_PERIOD_US     = 10000UL;   // closer together than this is noise, not a wheel
const uint32_t STOPPED_US        = 1000000UL; // no pulse for this long: the wheel has stopped
const uint32_t MIN_LOW_US        = 1500UL;    // a real pulse is LOW for longer than this
const uint8_t  FAST_PULSES       = 3;         // fast pulses in a row before the brake is applied

volatile uint32_t lastFallUs = 0;   // start of the last accepted wheel pulse
uint32_t fallUs    = 0;             // start of the pulse being measured (interrupt only)
uint8_t  fastCount = 0;             // fast pulses in a row (interrupt only)

// ------------------------------------------------------------
//  Pin-change interrupt on the speed wire
//    falling edge: a magnet may be passing the hall sensor
//    rising edge:  the pulse has ended, so decide whether it was real
// ------------------------------------------------------------
ISR(PCINT0_vect)
{
  uint32_t now = micros();

  if ((PINB & (1 << HALL_IN_PIN)) == 0) {      // line went LOW
    fallUs = now;
    return;
  }

  // The line went HIGH: the pulse has ended
  if (now - fallUs < MIN_LOW_US) return;       // LOW for too short a time: noise

  uint32_t period = fallUs - lastFallUs;
  if (period < MIN_PERIOD_US) return;          // too soon after the last pulse: noise
  lastFallUs = fallUs;

  if (period > STOPPED_US) {                   // first pulse after the wheel was stopped
    fastCount = 0;
    return;
  }

  if (period < CUT_PERIOD_US) {
    if (++fastCount >= FAST_PULSES) BRAKE_ON();
  } else {
    fastCount = 0;
    if (period > RELEASE_PERIOD_US) BRAKE_OFF();
  }
}

void setup()
{
  // The controller holds the wire HIGH; the internal pull-up only keeps
  // the pin quiet if the tap wire ever comes loose.
  pinMode(HALL_IN_PIN, INPUT_PULLUP);

  PORTB &= ~(1 << BRAKE_PIN);      // latch LOW; only DDRB changes
  BRAKE_OFF();

  PCMSK |= (1 << HALL_IN_PIN);     // pin-change interrupt on PB2 only
  GIMSK |= (1 << PCIE);
  sei();
}

void loop()
{
  // No wheel pulses for a second: the bike has stopped, let go of the brake line
  noInterrupts();
  uint32_t last = lastFallUs;
  interrupts();
  if ((uint32_t)(micros() - last) > STOPPED_US) BRAKE_OFF();
}
