;============================================================================================
;
;Program to run 6502 assembler exercises
;Date: 8th April 2020
;Author: Robin Harris

;RAM: 32k $0000 to $7FFF
;ROM  8k  $E000 to $FFFF
;
;============================================================================================

!initmem $EA
!cpu w65c02

reset_vector = $E000
LCD_Data = $8001   
LCD_Command = $8000
DELAYCOUNTER = $0050
INNERDELAY = $0051
NUM1 = $41
NUM2 = $42
SUM = $43
SR1 = $44
SR2 = $45



         *=reset_vector
; *** SETUP
         SEI               ; interrupts off
         LDX      #$FF     ; initialise stack
         TXS
         JSR      LCDINIT  ; initialise LCD

;==============================================
; MAIN PROGRAM
         LDA      #$FF
         STA      NUM1
         LDA      #5
         STA      NUM2

         LDA      NUM1
         CLC
         PHP               ; save SR for display
         PLA
         STA      SR1
         LDA      NUM1
         ADC      NUM2
         PHP               ; push status register after ADC
         STA      SUM
         PLA
         STA      SR2
         LDA      SUM
         JSR      DISPLAY  ; display A in HEX
         JSR      SR       ; display status register in binary

; do nothing forever
LOOP     NOP
         JMP      LOOP

; *** Initialises the LCD in 2 line 8 bit mode with display on, cursor off and counter incrementing right
LCDINIT  LDA     #%00111000      ; set mode to 2 line 8 bit
         STA     LCD_Command
         JSR     BUSY
         LDA     #%00001100      ; turn on display on, cursor off
         STA     LCD_Command
         JSR     BUSY
         LDA     #%00000110      ; set entry mode to increment cursor right 
         STA     LCD_Command
         JSR     BUSY
         LDA     #$01            ; clear display
         STA     LCD_Command
         JSR     BUSY  
         LDX     #$00
         LDA     str,X
-        STA     LCD_Data  
         JSR     BUSY       
         INX
         LDA     str,X
         BNE     -  
         RTS

; *** Positions cursor top left and clears display
LINE1:   PHA
         LDA      #1            ; move back to home
         STA      LCD_Command
         JSR      BUSY
         PLA
         RTS

LINE2:   PHA
         LDA     #$c0            ; move to position $c0 which is second row left
         STA     LCD_Command
         JSR     BUSY
         PLA
         RTS

; *** Checks Bit 7 of Command Register until it clears to 0
BUSY     PHA
-        LDA      LCD_Command          
         AND      #$80
         BNE      -
         PLA
         RTS

DISPLAY  PHY               ; push Y
         PHA               ; push A
         LSR               ; shift high nibble into low nibble
         LSR
         LSR 
         LSR 
         TAY
         LDA     HEXASCII,Y; convert to ASCII
         STA     LCD_Data  ; print value on the LCD
         JSR     BUSY
         PLA               ; restore original value
         PHA
         AND     #$0F      ; select low nibble
         TAY
         LDA     HEXASCII,Y; convert to ASCII
         STA     LCD_Data  ; send value on the LCD
         JSR     BUSY
         PLA
         PLY
         RTS

; displays the SR on the second line of the display
SR       JSR      LINE2
         LDX      #8
         LDA      SR1
         JSR      SHOW
         LDX      #8
         LDA      SR2
         JSR      SHOW
         RTS

SHOW     ASL               ; shift left 1 - bit 7 goes to carry
         BCS      ONE      ; if the bit shifted into carry was 1
         PHA               ; store the shifted SR value
         LDA      #$30
         STA      LCD_Data
         JSR      BUSY
         PLA               ; restore shifted SR
         JMP      DONE     ; go and check if we have done 8 bits
ONE      PHA               ; store the shifted SR value
         LDA      #$31
         STA      LCD_Data
         JSR      BUSY
         PLA               ; restore shifted SR
DONE     DEX
         BNE      SHOW
         RTS

DELAY    PHA
         LDA             #$FF
         STA             DELAYCOUNTER 
-        NOP
         NOP
         NOP
         NOP
         NOP
         DEC             DELAYCOUNTER
         BNE             -
         PLA
         RTS

str    !text "Ready: ", 0      ; string to display with null terminator
; *** Lookup table for HEX to ASCII
HEXASCII	!text"0123456789ABCDEF",0