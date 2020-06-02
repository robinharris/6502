;============================================================================================
;
;Sets T2 for one-shot and is intended to allow oscilloscope to measure cycles
;Date: 27th April 2020
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
ACR  = $801B     ; auxiliary control register
PCR  = $801C     ; peripheral control register
IFR  = $801D     ; interrupt flag register
IER  = $801E     ; interrupt enable register
VIAF = $801F     ; ORA/IRA without handshake

;==============================================================================
; ZERO PAGE


;==============================================================================
; MACROS


;==============================================================================
; SETUP
         *=RESET_VECTOR
; *** SETUP
         SEI               ; interrupts off - leave off so T2 does interrupt does not take any action
         LDX      #$FF     ; initialise stack
         TXS
         JSR      VIAINIT
         LDA      #$09      ; set low byte of counter to $20 = 32
         STA      T1CL
         LDA      #0
         STA      T1CH     ; load high byte with zero and start count
;==============================================================================
; MAIN PROGRAM GOES HERE
;
LOOP     LDA      #%01000000        ; load mask for T1 IFR in bit 5    4 cycles
WAIT     BIT      IFR               ; check if T2 IRQ is set           4 cycles
         BEQ      WAIT              ; if not keep waitging             2 cycles + 2 if branch taken
         LDA      T1CL              ; reset counter to clear IRQ
         JMP      LOOP
;==============================================================================

;SUBROUTINES
;------------------------------------------------------------------------------
; *** Via setup
VIAINIT  LDA      #%00000000        ; set all PA to input
         STA      DDRA
         LDA      #%11111111        ; set all PB to output
         STA      DDRB

         LDA      #%11000000        ; ACR - 1 in free running mode with PB7 pulse
         STA      ACR 

         LDA      #%11000000        ; interrupts - enable T1
         STA      IER
         LDA      #%00111111        ; interrupts - disable all except T1
         STA      IER
         RTS


;==============================================================================
;ISR
         *=IRQ_VECTOR
         NOP
         RTI
!fill $E260-*, $EA

