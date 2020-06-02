;============================================================================================
;
;Program to develop LCD routines on a 2 x 16 line display
;Date: 1st June 2020
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
VAL      = $49             ; key pad value read
COUNTER  = $50             ; delay length counter
SADDR    = $51             ; low byte address of string to display 
                           ; high byte in $52         

;==============================================================================
; MACROS
; sends a string to the LCD
; need to position cursor before entry
; parameter is the label for the string
!MACRO   PRINT .STADD{
         LDA      #<.STADD
         STA      SADDR
         LDA      #>.STADD
         STA      SADDR+1
         JSR      CLR
         JSR      SDISP
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
         CLD
         CLI

;==============================================================================
; MAIN PROGRAM GOES HERE
;
         +PRINT   S2
S2       !text"Cracked it!",0 
LOOP     NOP
         JMP      LOOP
;==============================================================================

;SUBROUTINES
;------------------------------------------------------------------------------
; *** Initialises the LCD in 2 line 8 bit mode with display on, cursor off and counter incrementing right
LCDINIT  
; first some long delays to ensure the LCD is ready to receive commands whenever the reset sequence is started
         LDX      #4
-        LDA      #$FA             ; gives a delay of 25mS
         STA      COUNTER
         JSR      DELAY
         DEX
         BMI      -                ;
; send the command three times to tell the LCD we want to manually reset
; the delay lengths are important
         LDA      #%00110000
         STA      LCDC
         LDA      #29               ; need 4.1mS delay
         STA      COUNTER
         JSR      DELAY             ; default 100uS delay
         LDA      #%00110000
         STA      LCDC
         JSR      DELAY             ; default 100uS delay
         LDA      #%00110000
         STA      LCDC
         JSR      DELAY             ; default 100uS delay
; next command is still in 8 bit mode
         LDA      #%00111000        ; 8 bit mode, N = 1 (2 lines) and F = 0 (5 x 8 dots)
         JSR      BUSY       
         STA      LCDC
; datasheet is unclear if next step is strictly necessary here.  Mostly works ok to set required display now
; but for comfort I set the display off here and turn it back on at the end of initialisation
         LDA      #%00001000        ; display off
         JSR      BUSY       
         STA      LCDC
         LDA      #%00000001        ; clear display
         JSR      BUSY       
         STA      LCDC
         LDA      #%00000110        ; entry mode - shift cursor right no display shift
         JSR      BUSY       
         STA      LCDC
         LDA      #%00001100        ; display on, cursor off
         JSR      BUSY       
         STA      LCDC
; send the welcome message
         LDY      #0                ; prepare Y to index into message
-        LDA      WLCM,Y            ; next character of message WLCM
         BEQ      +                 ; exit this loop when a null is read
         JSR      BUSY
         STA      LCDD
         INY
         BRA      -                 ; next character
+        RTS

;------------------------------------------------------------------------------
; check the BUSY FLAG
; preserves A
BUSY     PHA
-        LDA      LCDC              ; get BF
         AND      #%10000000        ; mask to leave only bit 7    
         BNE      -                 ; if busy flag is set go back and check again
         PLA
         RTS

;------------------------------------------------------------------------------
; provides about 100uS delay for each OUTER loop
; Set COUNTER with required OUTER iterations before calling
DELAY    PHY
OUTER    LDY      #$14              ; this gives an inner loop of 5 cycles x 20 =  100uS        
INNER    DEY
         BNE      INNER
         DEC      COUNTER
         BMI      OUTER             ; exit when COUNTER is less than 0
         STZ      COUNTER           ; reset counter ready for next call.  Default is 1 outer loop
         PLY
         RTS

;------------------------------------------------------------------------------
; clears a line on the LCD
; sends 16 spaces immediately after positioning cursor at left side of line
CLR      LDA      #$C0              ; move beginning of line 2
         JSR      BUSY
         STA      LCDC
         LDA      #$20              ; load 'space'
         LDX      #$10              ; need to write space to 16 character positions
-        JSR      BUSY
         STA      LCDD
         DEX
         BNE      -
         LDA      #$C0              ; move beginning of line 2
         JSR      BUSY
         STA      LCDC
         RTS

;------------------------------------------------------------------------------
; sends a string to the display
; put string address in SADDR (low byte) then call this routine
SDISP    LDY      #0
-        LDA      (SADDR),Y
         BEQ      +                 ; exit when a 0 is read
         JSR      DELAY              
         STA      LCDD              ; A contains the ASCII character to send
         INY
         BRA      -
+        RTS


;------------------------------------------------------------------------------
; *** Via setup
VIAINIT  LDA      #%00000000        ; set all PA to input
         STA      DDRA
         LDA      #%11111111        ; set all PB to output
         STA      DDRB

         LDA      #%00000000        ; ACR - bit 0 sets PA for latching
         STA      VIAB

         LDA      #%00000001        ; PCR - Bit 0 sets CA for positive edge
         STA      VIAC

         LDA      #%10000010        ; interrupts - enable CA1 by setting bit 1
         STA      VIAE
         RTS

;------------------------------------------------------------------------------
; *** Display character
; A contains the value to display and is the raw value from the keypad 0 - F in the lower nibble
; displays the ASCII character mapped from the keypad at the current cursor position
D_CH     TAX
         LDA      KEY,X     
         STA      LCDD
         ; +BUSY
         LDA LCDC          ;get current DDRAM address
         AND #$7F          ; clear bit 7
         CMP #$0F          ;wrap from line 1 char 16
         BNE +
         LDA #$C0          ;...to $40 (line 2 char 1)
         STA LCDC
         ; +BUSY
+        RTS

;==============================================================================
;DATA
KEY      !text"123A456B789C*0#D"
WLCM     !text"65C02 Ready",0
S1       !text"Hello Rob",0

;==============================================================================
;ISR
         *=IRQ_VECTOR
         PHA
         PLA
         RTI
!fill $E240-*, $EA

