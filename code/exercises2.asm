;============================================================================================
;
;Program to run 6502 assembler exercises
;Date: 10th April 2020
;Author: Robin Harris

;RAM: 32k $0000 to $7FFF
;ROM  8k  $E000 to $FFFF
;
;============================================================================================

!initmem $EA
!cpu w65c02

RESET_VECTOR = $E000
IRQ_VECTOR = $E300
LCDD = $8001   
LCDC = $8000
SR1 = $70
SR2 = $71
BASE = $40
LGTH = $72

         *=RESET_VECTOR

; *** SETUP
         SEI               ; interrupts off
         LDX      #$FF     ; initialise stack
         TXS
         JSR      LCDINIT  ; initialise LCD
         LDA      #3       ; length of string to display if an interrupt occurs
         STA      LGTH
         CLD
         CLI

;==============================================================================
; MAIN PROGRAM
         PHP               ; save SR for display
         PLA               ;
         STA      SR1      ;
; set up the data
         LDA      #$3E
         STA      BASE
         
; run the exercise code
         LDA      #0
         SEC
         SBC      BASE
         STA      BASE+1

         PHP               ; save SR for display
         PLA
         STA      SR2
         JSR      LINE1
         JSR      SR       ; display before and after SR in binary

         LDA      #$89     ; move to position 9 on line 1
         STA      LCDC
         JSR      BUSY
         LDA      #$24     ; display $
         STA      LCDD
         JSR      BUSY
-        LDA      $41
         JSR      PHEX

;  forever
LOOP     NOP
         JMP      LOOP
;==============================================================================

;------------------------------------------------------------------------------
; *** Initialises the LCD in 2 line 8 bit mode with display on, cursor off and counter incrementing right
LCDINIT  LDA     #%00111000      ; set mode to 2 line 8 bit
         STA     LCDC
         JSR     BUSY
         LDA     #%00001100      ; turn on display on, cursor off
         STA     LCDC
         JSR     BUSY
         LDA     #%00000110      ; set entry mode to increment cursor right 
         STA     LCDC
         JSR     BUSY
         LDA     #$01            ; clear display
         STA     LCDC
         JSR     BUSY  
         RTS

;------------------------------------------------------------------------------
; moves the cursor to position 7 of line 7

LINE1:   PHA
         LDA      #$80            ; move back to position 0 on line 1
         STA      LCDC
         JSR      BUSY
         PLA
         RTS

;------------------------------------------------------------------------------
; moves the cursor to beginning of line 2

LINE2:   PHA
         LDA     #$c0            ; move to position 0 on line 2
         STA     LCDC
         JSR     BUSY
         PLA
         RTS

;------------------------------------------------------------------------------
; *** Checks Bit 7 of Command Register until it clears to 0
BUSY     PHA
-        LDA      LCDC          
         AND      #$80
         BNE      -
         PLA
         RTS

;------------------------------------------------------------------------------
; displays a byte as two hex characters

PHEX     PHY               ; push Y
         PHA               ; push A
         LSR               ; shift high nibble into low nibble
         LSR
         LSR 
         LSR 
         TAY
         LDA     HEXASCII,Y; convert to ASCII
         STA     LCDD  ; print value on the LCD
         JSR     BUSY
         PLA               ; restore original value
         PHA
         AND     #$0F      ; select low nibble
         TAY
         LDA     HEXASCII,Y; convert to ASCII
         STA     LCDD  ; send value on the LCD
         JSR     BUSY
         PLA
         PLY
         RTS

;------------------------------------------------------------------------------
; displays the SR before and after
SR       LDX      #8
         LDA      SR1
         JSR      PBIN
         JSR      LINE2
         LDX      #8
         LDA      SR2
         JSR      PBIN
         RTS

;------------------------------------------------------------------------------
; sends a binary version of a byte to LCD
PBIN     ASL               ; shift left 1 - bit 7 goes to carry
         BCS      ONE      ; if the bit shifted into carry was 1
         PHA               ; store the shifted SR value
         LDA      #$30
         STA      LCDD
         JSR      BUSY
         PLA               ; restore shifted SR
         JMP      DONE     ; go and check if we have done 8 bits
ONE      PHA               ; store the shifted SR value
         LDA      #$31
         STA      LCDD
         JSR      BUSY
         PLA               ; restore shifted SR
DONE     DEX
         BNE      PBIN
         RTS
--------------------------------------------------------------

str    !text "Ready: ", 0      ; string to display with null terminator
; *** Lookup table for HEX to ASCII
HEXASCII	!text"0123456789ABCDEF",0

         *=IRQ_VECTOR
         SEI
         PHA
         PHY
         LDA      #1       ; clear display
         STA      LCDC
         JSR      BUSY
         LDY      #0
-        LDA      STR2,Y
         STA      LCDD
         JSR      BUSY
         INY
         CPY      LGTH
         BMI      -
         PLY
         PLA
         CLI
         RTI
STR2     !text"IRQ"
