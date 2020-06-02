;============================================================================================
;
;Sets T2 for counting pulses on PB6
;Date: 28th April 2020
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
         SEI               ; interrupts off - leave off so T2 interrupt does not take any action
         LDX      #$FF     ; initialise stack
         TXS
         JSR      VIAINIT
         LDA      #$03      ; set low byte of counter
         STA      T2CL
         LDA      #0
         STA      T2CH     ; load high byte with zero and start counting pulses
;==============================================================================
; MAIN PROGRAM GOES HERE
;
LOOP     LDA      #%00100000        ; load mask for T2 IFR in bit 5    
WAIT     BIT      IFR               ; check if T2 IRQ is set           
         BEQ      WAIT              ; if not keep waiting 
         LDA      #0
         STA      T2CH     ; load high byte with zero and start counting pulses
         JMP      LOOP
;==============================================================================

;SUBROUTINES
;------------------------------------------------------------------------------
; *** Via setup
VIAINIT  LDA      #%00000000        ; set all PA to input
         STA      DDRA
         LDA      #%10111111        ; set PB6 to input
         STA      DDRB

         LDA      #%00100000        ; bit 5 set enables T2 to count pulses on PB6
         STA      ACR 

         LDA      #%10100000        ; interrupts - enable T2
         STA      IER
         LDA      #%01011111        ; interrupts - disable all except T2
         STA      IER
         RTS


;==============================================================================
;ISR
        
;==============================================================================
!fill $E100-*, $EA

