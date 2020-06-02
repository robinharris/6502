;============================================================================================
;
;Program to flash LEDs
;Date: 21st April 2020
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
DIN = $46         ; inner delay counter
DOUT = $47        ; outer delay counter
VAL = $49         ; key pad value read
OLDVAL = $50      ; previous VAL used to check if pattern changed
ICOUNT = $51      ; counts the number of interrupts
PATTERN = $52     ; LED pattern

;==============================================================================
; MACROS
; reads bit 7 of the LCDC which is set when the LCD is busy
!macro BUSY{
-        LDA      LCDC          
         AND      #$80
         BNE      -        
}

;==============================================================================
; SETUP
         *=RESET_VECTOR
; *** SETUP
         SEI               ; interrupts off
         LDX      #$FF     ; initialise stack
         TXS
         JSR      LCDINIT
         JSR      VIAINIT
         LDA      #$FF
         STA      T1LL
         STA      T1LH
         STA      T1CH     ; start timer
         STZ      ICOUNT
         STZ      VAL      ; initialise VAL the keypad raw value
         LDA      #99      ; any value that is not the same as VAL so that the first pattern gets set
         STA      OLDVAL   ; initialise OLDVAL the previous VAL
         CLD
         CLI

;==============================================================================
; MAIN PROGRAM GOES HERE
;
LOOP     LDA      VAL
         CMP      #0
         BEQ      ONE
         CMP      #1
         BEQ      TWO
         CMP      #2
         BEQ      THREE
         JMP      LOOP

ONE      CMP      OLDVAL
         BEQ      ONE1     ; if no change in VAL carry on.  If new VAL initialise the pattern
         STA      OLDVAL   ; make OLDVAL equal new VAL
         LDA      #$AA
         STA      PATTERN  ; initialise first LED pattern
         STA      VIAPB
ONE1     LDA      ICOUNT
         CMP      #$03
         BEQ      ONE2
         JMP      LOOP
ONE2     LDA      PATTERN
         EOR      #$FF     ; invert bits
         STA      PATTERN
         STA      VIAPB
         STZ      ICOUNT
         JMP      LOOP

TWO      CMP      OLDVAL
         BEQ      ONE1     ; if no change in VAL carry on.  If new VAL initialise the pattern
         STA      OLDVAL   ; make OLDVAL equal new VAL
         LDA      #$F0
         STA      PATTERN  ; initialise first LED pattern
         STA      VIAPB
TWO1     LDA      ICOUNT
         CMP      #$03
         BEQ      TWO2
         JMP      LOOP
TWO2     LDA      PATTERN
         EOR      #$FF     ; invert bits
         STA      PATTERN
         STA      VIAPB
         STZ      ICOUNT
         JMP      LOOP

THREE    CMP      OLDVAL
         BEQ      THREE1     ; if no change in VAL carry on.  If new VAL initialise the pattern
         STA      OLDVAL     ; make OLDVAL equal new VAL
         LDA      #%10000000 ; start with BIT 7 set
         STA      PATTERN          
         STA      VIAPB
THREE1   LDA      ICOUNT
         CMP      #$03
         BEQ      THREE2
         JMP      LOOP
THREE2   LDA      PATTERN
         BEQ      +        ; start on right again
         LSR               ; move LED right one bit
         STA      PATTERN
         STA      VIAPB
         STZ      ICOUNT
         JMP      LOOP
+        LDA      #%10000000 ; reset BIT 7 set
         STA      PATTERN          
         STA      VIAPB
         STZ      ICOUNT
         JMP      LOOP
;==============================================================================

;SUBROUTINES
;------------------------------------------------------------------------------
; *** Initialises the LCD in 2 line 8 bit mode with display on, cursor off and counter incrementing right
; data sheet advises to do the mode setup THREE times
LCDINIT  LDA      #%00111000      ; set mode to 2 line 8 bit
         STA      LCDC
         +BUSY
         LDA      #%00111000      ; set mode to 2 line 8 bit
         STA      LCDC
         +BUSY
         LDA      #%00111000      ; set mode to 2 line 8 bit
         STA      LCDC
         +BUSY
         LDA      #%00001100      ; turn on display on, cursor off
         STA      LCDC
         +BUSY
         LDA      #%00000110      ; set entry mode to increment cursor right 
         STA      LCDC
         +BUSY
         LDA      #$01            ; clear display
         STA      LCDC
         +BUSY
         RTS

;------------------------------------------------------------------------------
; *** Via setup
VIAINIT  LDA      #%00000000        ; set all PA to input
         STA      DDRA
         LDA      #%11111111        ; set all PB to output
         STA      DDRB

         LDA      #%01000000        ; ACR - bit 0 sets PA for latching, bit 7 & 6 set T1 continuous
         STA      VIAB

         LDA      #%00000001        ; PCR - Bit 0 sets CA for positive edge
         STA      VIAC

         LDA      #%11000010        ; interrupts - enable CA1 by setting bit 1, T1 with bit 6
         STA      VIAE
         RTS

;------------------------------------------------------------------------------
; *** Display character
; A contains the value to display and is the raw value from the keypad 0 - F in the lower nibble
; displays the ASCII character mapped from the keypad at the current cursor position
D_CH     TAX
         LDA      KEY,X     
         STA      LCDD
         +BUSY
         LDA LCDC          ;get current DDRAM address
         AND #$7F          ; clear bit 7
         CMP #$0F          ;wrap from line 1 char 16
         BNE +
         LDA #$C0          ;...to $40 (line 2 char 1)
         STA LCDC
         +BUSY
+        RTS

;------------------------------------------------------------------------------
; *** Delay about 1 second
DLY      PHA
         LDA      #$AA
         STA      DIN
         STA      DOUT     
-        NOP
         NOP
         NOP
         NOP
         NOP
         DEC      DIN      
         BNE      -
         STA      DIN
         DEC      DOUT
         BNE      -
         PLA
         RTS

;==============================================================================
;DATA
KEY      !text"123A456B789C*0#D"

;==============================================================================
;ISR
         *=IRQ_VECTOR
         PHA
         PHY
         LDA      VIAD     ; load flag register
         LSR
         LSR       ; check if T1 triggered the IRQ
         BCC      T1                ; non-zero means is was T1
; so carry on with keypad read which also clears the interrupt by reading Port A
         LDA      VIAPA
         AND      #%00001111
         STA      VAL      ; VAL holds the last key pressed

         LDA      LCDC     ; get current DDRAM address
         AND      #$7F     ; clear bit 7
         CMP      #$10     ; wrap from line 1 char 16
         BEQ      +
         CMP      #$50     ; wrap from line 2 char 16
         BEQ      ++
         JMP      SHOW
; move to start of line 2
+        LDA      #$C0     ; to $40 (line 2 char 1)
         STA      LCDC
         +BUSY
         JMP      SHOW
; move to start of line 1 and clear screen
++       LDA      #1       ; clear display and return home
         STA      LCDC
         +BUSY

SHOW     LDA      VAL
         TAX
         LDA      KEY,X     
         STA      LCDD
         +BUSY
         JMP      END

T1       LDA      T1CL     ; read to reset IRQ
         INC      ICOUNT
END      PLY
         PLA
         RTI
!fill $E260-*, $EA

