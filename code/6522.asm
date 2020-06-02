;============================================================================================
;
;Program to test 6522
;Date: 16th April 2020
;Author: Robin Harris

;RAM: 32k $0000 to $7FFF
;ROM  8k  $E000 to $FFFF
;LCD $8000 - $800F
;6522 $8010 - $801F
;
;============================================================================================

!initmem $EA
!cpu w65c02

;==============================================================================
;Address values
RESET_VECTOR = $E000
IRQ_VECTOR = $E300
LCDD = $8001      ; address for LCD data
LCDC = $8000      ; address for LCD commands
RB = $8010        ; ORA / IRA
RA = $8011        ; ORB / IRB
DDRB = $8012      ; DDRB
DDRA = $8013      ; DDRA
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
;ZERO PAGE
LGTH = $45
DIN = $46         ; inner delay counter
DOUT = $47        ; outer delay counter
ICOUNT = $48      ; counts number of interrupts


         *=RESET_VECTOR

; *** SETUP
         SEI               ; interrupts off
         LDX      #$FF     ; initialise stack
         TXS
         JSR      LCDINIT  ; initialise LCD
         LDA      #3       ; length of string to display if an interrupt occurs
         STA      LGTH
         LDX      #0
-        LDA      MSG1,X
         BEQ      DONE     ; if the value just read was 0 we have reached end of string
         STA      LCDD
         JSR      BUSY
         INX
         JMP      -
DONE     LDA      #0
         STA      ICOUNT   ; initialise interrupt counter
         CLD
         CLI

;==============================================================================
; MAIN PROGRAM
         LDA      #%11000000        ; interrupts - enable timer 1
         STA      VIAE
         LDA      #%00000000        ; interrupt mode - one shot
         STA      VIAB
         LDA      #$FF              ; load T1CL with max value
         STA      DDRA              ; set all pins to output on port A
         STA      DDRB              ; set all pins to output on port B
         STA      T1LL              ; load T1LL with the max value
         STA      T1LH              ; load T1LH with max value
         STA      T1CH              ; start the timer by loading the high byte
LOOP     LDA      #$55
         STA      RA
         JSR      DELAY
         LDX      #0
         JSR      LINE2
-        LDA      MSG2,X
         BEQ      D1       ; if the value just read was 0 we have reached end of string
         STA      LCDD
         JSR      BUSY
         INX
         JMP      -
D1       LDA      #$AA
         STA      RA
         JSR      DELAY
         LDX      #0
         JSR      LINE1
-        LDA      MSG1,X
         BEQ      D2       ; if the value just read was 0 we have reached end of string
         STA      LCDD
         JSR      BUSY
         INX
         JMP      -
D2       JMP      LOOP
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
         LDA     #$01            ; clear display
         STA     LCDC
         JSR     BUSY  
         PLA
         RTS

;------------------------------------------------------------------------------
; moves the cursor to beginning of line 2

LINE2:   PHA
         LDA     #$01            ; clear display
         STA     LCDC
         JSR     BUSY  
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
         JSR     DELAY
         PLA
         PLY
         RTS

;------------------------------------------------------------------------------
DELAY    PHA
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
;------------------------------------------------------------------------------


MSG1     !text "Ready", 0      ; string to display with null terminator
MSG2     !text "Running", 0      ; string to display with null terminator
; *** Lookup table for HEX to ASCII
HEXASCII	!text"0123456789ABCDEF",0

         *=IRQ_VECTOR
         PHA
         PHY
         BIT      T1CL     ; turn off interrupt
         LDA      #1       ; clear display
         STA      LCDC
         JSR      BUSY
         LDY      #0
-        LDA      MSG3,Y
         STA      LCDD
         JSR      BUSY
         INY
         CPY      LGTH
         BMI      -
         JSR      DELAY
         PLY
         PLA
         RTI
MSG3     !text"IRQ"
!fill $E330-*, $EA

