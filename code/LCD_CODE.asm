;============================================================================================
;
; LCD Demonstration
; Date: 23rd May 2020
; Author: Robin Harris
; VERSION 1

; RAM: 32k $0000 to $7FFF
; ROM  8k  $E000 to $FFFF
; LCD $8000 - $800F
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

;==============================================================================
; ZERO PAGE

;==============================================================================
; MACROS


;==============================================================================
; SETUP
         *=RESET_VECTOR
         SEI
         LDX      #$FF              ; initialise stack
         TXS
         JSR      LCDINIT           ; set up LCD
         CLI
         
;==============================================================================
; MAIN PROGRAM GOES HERE

         JSR      LINE2
         LDY      #0                ; prepare Y to index into message
-        LDA      MSG,Y             ; next character of message MSG
         BEQ      +                 ; exit this loop when a null is read
         STA      LCDD              ; send character
         JSR      BUSY
         INY
         BRA      -                 ; keep going
LOOP     JMP      LOOP


;==============================================================================

;SUBROUTINES
;------------------------------------------------------------------------------
; *** Initialises the LCD in 2 line 8 bit mode with display on, cursor off and counter incrementing right
LCDINIT  LDA      #%00111000        ; set mode to 2 line 8 bit
         STA      LCDC
         JSR      BUSY              ; wait till not busy
         STA      LCDC
         JSR      BUSY              ; wait till not busy
         STA      LCDC
         JSR      BUSY              ; wait till not busy
         LDA      #%00001100        ; turn on display on, cursor off
         STA      LCDC
         JSR      BUSY
         LDA      #%00000110        ; set entry mode to increment cursor right 
         STA      LCDC
         JSR      BUSY
         LDA      #$01              ; clear display
         STA      LCDC
         JSR      BUSY  
         LDY      #0                ; prepare Y to index into message
-        LDA      WLCM,Y            ; next character of message WLCM
         BEQ      +                 ; exit this loop when a null is read
         STA      LCDD              ; send character
         JSR      BUSY
         INY
         BRA      -                 ; keep going
+        RTS

;------------------------------------------------------------------------------
; moves the cursor to position 0 of line 7

LINE1:   PHA
         LDA     #0            ; row 1 left
         STA     LCDC
         JSR     BUSY  
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
         AND      #$80              ; bit 7 is the busy flag and is set when LCD busy
         BNE      -                 ; wait until bit 7 is cleared
         PLA
         RTS

;------------------------------------------------------------------------------

;==============================================================================
;TABLES
WLCM     !text"65C02 Ready",0
MSG      !text"LCD TEST OK", 0

;==============================================================================
;ISR
         *=IRQ_VECTOR
         PHA
         PLA
         RTI
!fill $E240-*, $EA

