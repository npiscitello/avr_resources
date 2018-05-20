; Nick Piscitello
; May 2018
; Atmel ATMEGA328-PU
; avr-gcc 8.1.0
; fuses: default (l: 0x62, h: 0xD9, e: 0x07)

#include <avr/io.h>
#include <avr/interrupt.h>

;=== REGISTER MAP ===;
; temporary working reg
#define TEMP r16
; reg to write on the MAX7221
#define REG r17
; value to write to the MAX7221
#define VAL r18

;=== UTILITY MACROS ===;
#define low(x) ((x) & 0xFF)
#define high(x) (((x) >> 8) & 0xFF)

.global main
main:
  ; divide 8 MHz internal crystal by 64
  ; the clock is already divided by 8 due to fuse settings
  ; set prescaler to divide that signal by 8 additionally
  ; this gives a system clock speed of 1 MHz / 8 = 125 kHz
  ldi TEMP,0x00 | _BV(CLKPCE)
  sts CLKPR,TEMP
  ldi TEMP, 0x00 | _BV(CLKPS1) | _BV(CLKPS0)
  sts CLKPR,TEMP

  ; power on the timer and SPI peripherals
  ldi TEMP, 0xFF & !_BV(PRTIM0) & !_BV(PRSPI)
  sts PRR,TEMP

  ; set up SPI: master, CLK = system clock / 2
  ; pins: SS = PB2, MOSI = PB3, SCK = PB5
  ldi TEMP, 0x00 | _BV(DDB2) | _BV(DDB3) | _BV(DDB5);
  out _SFR_IO_ADDR(DDRB),TEMP
  ldi TEMP, 0x00 | _BV(SPIE) | _BV(SPE) | _BV(MSTR);
  out _SFR_IO_ADDR(SPCR),TEMP
  ldi TEMP, 0x00 | _BV(SPI2X);
  out _SFR_IO_ADDR(SPSR), TEMP

  ; set stack pointer to the end of RAM (required for returning from interrupts)
  ldi TEMP,low(RAMEND)
  out _SFR_IO_ADDR(SPL),TEMP
  ldi TEMP,high(RAMEND)
  out _SFR_IO_ADDR(SPH),TEMP

  ; set up the timer/counter 0 mode (CTC)
  ldi TEMP,0x00 | _BV(WGM01)
  out _SFR_IO_ADDR(TCCR0A),TEMP
  ; set up the timer/counter 0 clock source (sys / 1024)
  ldi TEMP,0x00 | _BV(CS02) | _BV(CS00)
  out _SFR_IO_ADDR(TCCR0B),TEMP
  ; clear pending interrupts
  ldi TEMP,0x00 | _BV(TOV0)
  out _SFR_IO_ADDR(TIFR0),TEMP
  ; enable timer/counter 0 output compare A interrupt
  ldi TEMP,0x00 | _BV(OCIE0A)
  sts TIMSK0,TEMP
  ; set the output compare
  ldi TEMP,0xFF
  out _SFR_IO_ADDR(OCR0A),TEMP
  ; globally enable interrupts
  sei

.global TIMER0_COMPA_vect
TIMER0_COMPA_vect:

.global transmit
transmit:
  ; set CS low
  ; write the MAX7221 address
  ; write the MAX7221 value
  ; bring CS high