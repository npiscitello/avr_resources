/* Nick Piscitello
 * February 2017
 * Atmel ATMEGA328P-PU
 * avr-gcc 4.3.3 (WinAVR 20100110)
 * fuses: default (l: 0x62, h: 0xD9, e: 0x07)
 * system clock: 8MHz / 8 = 1MHz */

#include <avr/io.h>
#include <util/delay.h>

void transmit(uint8_t reg, uint8_t val) {
  // set CS low
  PORTB &= 0xFF & !_BV(PORTB2);
  // what register to write on the MAX7221
  SPDR = reg;
  // wait for the transmission to finish
  while( !(SPSR & _BV(SPIF)) ) {}
  // what to write into the register on the MAX7221
  SPDR = val;
  // wait for the transmission to finish
  while( !(SPSR & _BV(SPIF)) ) {}
  // bring CS high
  PORTB |= 0x00 | _BV(PORTB2);
}

int main(void) {
  // turn off everything except the SPI interface
  PRR = 0xFF & !_BV(PRSPI);

  // set up SPI: master, CLK = system clock / 2
  // pins: SS = PB2, MOSI = PB3, SCK = PB5
  DDRB = _BV(DDB2) | _BV(DDB3) | _BV(DDB5);
  SPCR = _BV(SPE) | _BV(MSTR);
  SPSR = _BV(SPI2X);

  // set up MAX7219
  // don't use the decode table for any digit
  transmit(0x09, 0x00);
  // set intensity to lowest
  transmit(0x0A, 0x00);
  // scan across all digits
  transmit(0x0B, 0x07);
  // take the chip out of shutdown mode
  transmit(0x0C, 0x01);
 
  // clear display
  for( uint8_t i = 0x01; i <= 0x08; i++ ) {
    transmit(i, 0x00);
  }

  // make a cool pattern and vary intensity
  uint8_t val = 0x0F;
  uint8_t intensity = 0x01;
  uint8_t ascend = 1;
  while( 1 == 1 ) {
    // cycle brightness
    transmit(0x0A, intensity);
    if( intensity == 0x0F ) {
      ascend = 0;
    } else if( intensity == 0x00 ) {
      ascend = 1;
    }
    if( ascend ) {
      intensity++;
    } else {
      intensity--;
    }
    // cycle LEDs
    for( uint8_t i = 0x01; i <= 0x08; i++ ) {
      transmit(i, val);
      val = val >> 1 | val << 7;
    }
    val = val >> 1 | val << 7;
    _delay_ms(50);
  }
}
