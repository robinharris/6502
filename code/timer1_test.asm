;============================================================================================
;
;Program to check IRQ of T1
;Date: 23rd April 2020
;Author: Robin Harris
;VERSION 1

;RAM: 32k $0000 to $7FFF
;ROM  8k  $E000 to $FFFF
;LCD $8000 - $800F
;6522 $8010 - $801F
;
;==============================================================================

!initmem $EA
!cpu w65c02

;==============================================================================
;Address values
RESET_VECTOR = $E000
IRQ_VECTOR = $E200
LCDD = $8001     ; address for LCD data
LCDC = $8000     ; address for LCD commands
VIAPB = $8010    ; ORA / IRA
VIAPA = $8011    ; ORB / IRB
DDRB = $8012     ; DDRB
DDRA = $8013     ; DDRA
T1CL = $8014     ; T1 low order latches / counter
T1CH = $8015     ; T1 high order counter
T1LL = $8016     ; T1 low order latches
T1LH = $8017     ; T1 high order latches
T2CL = $8018     ; T2 low order latches / counter
T2CH = $8019     ; T2 high order counter
VIAA = $801A     ; shift register
VIAB = $801B     ; auxiliary control register
VIAC = $801C     ; peripheral control register
VIAD = $801D     ; interrupt flag register
VIAE = $801E     ; interrupt enable register
VIAF = $801F     ; ORA/IRA without handshake

;==============================================================================
; ZERO PAGE


;==============================================================================
; MACROS
; reads bit 7 of the LCDC which is set when the LCD is busy


;==============================================================================
; SETUP
         *=RESET_VECTOR
; *** SETUP
         SEI               ; interrupts off
         LDX      #$FF     ; initialise stack
         TXS
         JSR      VIAINIT
         STZ      T1LH     ; load high latch zero
         LDA      #$15     ; load low latch with decimal 21
         STA      T1LL
         STZ      T1CH     ; start timer
         CLD
         CLI

;==============================================================================
; MAIN PROGRAM GOES HERE
;
LOOP     NOP
         JMP      LOOP
;==============================================================================

;SUBROUTINES
;------------------------------------------------------------------------------
; *** Via setup
VIAINIT  LDA      #%00000000        ; set all PA to input
         STA      DDRA
         LDA      #%11111111        ; set all PB to output
         STA      DDRB

         LDA      #%11000000        ; ACR -  bit 7 & 6 set T1 continuous, with PB7
         STA      VIAB

         LDA      #%00000001        ; PCR - Bit 0 sets CA for positive edge
         STA      VIAC

         LDA      #%11000000        ; interrupts - enable T1
         STA      VIAE
         LDA      #%00111111        ; interrupts - disable all except T1
         STA      VIAE
         RTS


;==============================================================================
;ISR
         *=IRQ_VECTOR
         LDA      T1CL     ; clear IRQ
         RTI
!fill $E260-*, $EA

