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
; low RAM pointer
#define PL r30
; high RAM pointer
#define PH r31

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
  ldi TEMP, 0x00 | _BV(SPE) | _BV(MSTR);
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

  ; setup screen buffer in RAM, initialize to blank
  ldi PL,low(RAMSTART)
  ldi PH,high(RAMSTART)
  ldi TEMP,0x00
  ; this could turn into a loop later...
  std Z+0,TEMP;
  std Z+1,TEMP;
  std Z+2,TEMP;
  std Z+3,TEMP;
  std Z+4,TEMP;
  std Z+5,TEMP;
  std Z+6,TEMP;
  std Z+7,TEMP;

  ; set up max7221
  rcall max_setup

  ; globally enable interrupts
  sei
  ; jump to main application logic
  rjmp loop



.global max_setup
max_setup:
  ; don't use the decode tables
  ldi REG,0x09
  ldi VAL,0x00
  rcall send_packet

  ; set a middle intensity
  ldi REG,0x0A
  ldi VAL,0x07
  rcall send_packet

  ; scan across all the digits
  ldi REG,0x0B
  ldi VAL,0x07
  rcall send_packet

  ; write out the initial screen buffer
  rcall update_screen

  ; take the chip out of shutdown
  ldi REG,0x0C
  ldi VAL,0x01
  rcall send_packet

  ret



.global loop
loop:
  rcall update_screen
  rjmp loop



.global TIMER0_COMPA_vect
TIMER0_COMPA_vect:
  ; push status register onto stack
  in TEMP,_SFR_IO_ADDR(SREG)
  push TEMP
  ; update pattern on LED matrix
  ldd TEMP,Z+0
  inc TEMP
  std Z+0,TEMP
  ; restore status register
  pop TEMP
  out _SFR_IO_ADDR(SREG),TEMP
  reti



.global update_screen
update_screen:
  ldi REG,0x01
  ldd VAL,Z+0
  rcall send_packet
  ldi REG,0x02
  ldd VAL,Z+1
  rcall send_packet
  ldi REG,0x03
  ldd VAL,Z+2
  rcall send_packet
  ldi REG,0x04
  ldd VAL,Z+3
  rcall send_packet
  ldi REG,0x05
  ldd VAL,Z+4
  rcall send_packet
  ldi REG,0x06
  ldd VAL,Z+5
  rcall send_packet
  ldi REG,0x07
  ldd VAL,Z+6
  rcall send_packet
  ldi REG,0x08
  ldd VAL,Z+7
  rcall send_packet



.global send_packet
send_packet:
  ; we don't need to worry about the status reg here
  ; b/c we always know when this is going to execute
  ; set CS low
  ldi TEMP, !_BV(PORTB2)
  out _SFR_IO_ADDR(PORTB), TEMP
  ; write the MAX7221 address
  out _SFR_IO_ADDR(SPDR),REG
  rcall wait_transmit
  ; write the MAX7221 value
  out _SFR_IO_ADDR(SPDR),VAL
  rcall wait_transmit
  ; bring CS high
  ldi TEMP, _BV(PORTB2)
  out _SFR_IO_ADDR(PORTB), TEMP
  ret



.global wait_transmit
wait_transmit:
  ; load in the SPI status register
  in TEMP,_SFR_IO_ADDR(SPSR)
  ; skip the next line if the transmission has completed
  sbrs TEMP,SPIF
  rjmp wait_transmit
  ret
