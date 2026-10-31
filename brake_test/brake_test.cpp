// ============================================================
//  ATtiny85 bench test: pull the brake for 10 s, release for 10 s, repeat.
//  The real speed signal is always passed through unchanged.
//
//    PB2 (pin 7)  INPUT  <- motor-side white wire (via 1 kohm, 4.7 kohm pull-up to +5 V)
//    PB3 (pin 2)  OUTPUT -> controller-side white wire (via 220 ohm)
//    PB4 (pin 3)  BRAKE  -> brake wire that reads 5 V (via 220 ohm)
//
//  Speed: every edge on PB2 is copied to PB3 by a pin-change interrupt,
//  so the controller and display see the real wheel speed.
//
//  Brake line: output LOW pulls it to ground (brake pulled, motor off),
//  input (high-Z) lets the controller's pull-up raise it to 5 V (brake
//  released, motor allowed to run).
// ============================================================

#include <Arduino.h>
#include <avr/interrupt.h>

#define HALL_IN_PIN  2
#define OUT_PIN      3
#define BRAKE_PIN    4

const uint32_t PHASE_MS = 10000UL;

uint32_t tPhaseMs = 0;
bool     braking  = true;

// Copy the input level straight to the output
ISR(PCINT0_vect)
{
  if (PINB & (1 << HALL_IN_PIN)) PORTB |=  (1 << OUT_PIN);
  else                           PORTB &= ~(1 << OUT_PIN);
}

void setup() {
  pinMode(HALL_IN_PIN, INPUT);
  pinMode(OUT_PIN, OUTPUT);
  digitalWrite(OUT_PIN, digitalRead(HALL_IN_PIN));

  // PORTB bit stays 0, so switching DDRB to output pulls the line LOW
  PORTB &= ~(1 << BRAKE_PIN);
  DDRB  |=  (1 << BRAKE_PIN);   // start with the brake pulled

  PCMSK |= (1 << HALL_IN_PIN);  // pin-change interrupt on PB2 only
  GIMSK |= (1 << PCIE);
  sei();

  tPhaseMs = millis();
}

void loop() {
  // brake: toggle every 10 s
  if ((uint32_t)(millis() - tPhaseMs) >= PHASE_MS) {
    tPhaseMs += PHASE_MS;
    braking = !braking;
    if (braking) DDRB |=  (1 << BRAKE_PIN);   // output LOW: brake pulled
    else         DDRB &= ~(1 << BRAKE_PIN);   // high-Z: brake released
  }
}
