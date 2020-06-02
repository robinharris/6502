;============================================================================================
;
;Uses T1 & T2 to blink 2 LEDs on PB
; keypad allows changing of blink rate up and down of both LEDs in 200mS steps
; T1 - up = 3, down = 1
; T2 - up = 9, down = 7
;Date: 3rd May 2020
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
PB = $8010       ; ORA / IRA
PA = $8011       ; ORB / IRB
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

T_LOAD = $C34E   ; 49998 calculated 50000 - 1.5 = 50mS
T1_DEF = $14     ; T1 default value is 20 i.e. a delay of 1s
T2_DEF = $0A     ; T2 default value is 10 i.e. a dealy of 0.5s

;==============================================================================
; ZERO PAGE
; this is loaded into both timers to generate a IRF after 50mS.
LASTKEY = $20     ; the lower nibble of PA when a key is pressed
FLAG = $21        ; bit 7 is T1, bit 6 is T2 and bit 5 is key
T1_CUR = $22
T2_CUR = $23
T1_VAL = $24      ; T1 default value is 20 i.e. a delay of 1s
T2_VAL = $25   

;==============================================================================
; MACROS


;==============================================================================
; SETUP
         *=RESET_VECTOR
; *** SETUP
         SEI                        ; interrupts off - leave off so T2 does interrupt does not take any action
         LDX      #$FF              ; initialise stack
         TXS
         JSR      VIAINIT
         STZ      FLAG              ; initialise FLAG byte
         STZ      LASTKEY
         JSR      LCDINIT
         LDA      # < T_LOAD        ; load low byte of both counters
         STA      T1CL
         STA      T2CL
         LDA      # > T_LOAD        ; load high byte of both counters
         STA      T1CH     
         STA      T2CH
         LDA      # T1_DEF          ; initialise the delay length for T1
         STA      T1_VAL
         STA      T1_CUR
         LDA      # T2_DEF          ; initialise the delay length for T2
         STA      T2_VAL
         STA      T2_CUR
         CLI
         
;==============================================================================
; MAIN PROGRAM GOES HERE

LOOP     BBS7     FLAG,PR_T1    ; bit 7 is set so process T1 interrupt
         BBS6     FLAG,PR_T2    ; bit 6 is set so process T2 interrupt
         BBS5     FLAG,KPRESS   ; bit 5 is set so process key
         JMP      LOOP

KPRESS   LDY      LASTKEY
         BNE      +        ; key value not 0 ('1') so skip
         DEC      T1_VAL   ; reduce T1 delay by 100mS
         DEC      T1_VAL
+        CPY      #2
         BNE      +        ; key value not 2 ('3') so skip
         INC      T1_VAL   ; increase T1 delay by 100mS
         INC      T1_VAL
+        CPY      #8
         BNE      +        ; key value not 8 ('7') so skip
         DEC      T2_VAL   ; reduce T2 delay by 100mS
         DEC      T2_VAL
+        CPY      #10
         BNE      +        ; key value not 10 ('9') so skip
         INC      T2_VAL   ; increase T2 delay by 100mS
         INC      T2_VAL
+        LDA      #1       ; clear display
         STA      LCDC
         JSR      BUSY
         LDA      T1_VAL   ; show T1 value on Line 1
         JSR      DISPLAY
         JSR      LINE2    ; move to line 2
         LDA      T2_VAL   ; display T2 value
         JSR      DISPLAY
         RMB5     FLAG     ; reset bit 5 to show we've processed the key press
         JMP      LOOP

PR_T1    DEC      T1_CUR   ;
         RMB7     FLAG     ; clear bit 7 of FLAG
         BNE      LOOP     ; not yet down to zero so jump over reset
         LDA      T1_VAL   ; reload T1 delay
         STA      T1_CUR
         LDA      PB       ; toggle bit 0 of PB
         EOR      #%00000001        
         STA      PB
         JMP      LOOP

PR_T2    DEC      T2_CUR
         RMB6     FLAG     ; clear bit 6 of FLAG
         BNE      LOOP     ; not yet down to zero so jump over reset
         LDA      T2_VAL   ; reload T2 delay
         STA      T2_CUR
         LDA      PB       ; toggle bit 1 of PB
         EOR      #%00000010       
         STA      PB
         JMP      LOOP

;==============================================================================

;SUBROUTINES
;------------------------------------------------------------------------------
; *** Via setup
VIAINIT  LDA      #%00000000        ; set all PA to input - bits 0 - 3 used for keypad
         STA      DDRA
         LDA      #%11111111        ; set all PB to output - using PB0 and PB1 for LEDs
         STA      DDRB
         LDA      #%00000000        ; ACR - T1 & T2 one shot countdown with reload.  SR disabled
         STA      ACR 
         LDA      #%00000001        ; PCR - Bit 0 sets CA for positive edge
         STA      PCR
         LDA      #%11100010        ; interrupts - enable T1, T2 and CA1
         STA      IER
         LDA      #%00011101        ; interrupts - disable CB1, CB2, SR and CA2
         STA      IER
         LDA      #0                 ; turn off all LEDs
         STA      PB
         RTS

;------------------------------------------------------------------------------
; *** Initialises the LCD in 2 line 8 bit mode with display on, cursor off and counter incrementing right
LCDINIT  LDA      #%00111000      ; set mode to 2 line 8 bit
         STA      LCDC
         JSR      BUSY
         LDA      #%00001100      ; turn on display on, cursor off
         STA      LCDC
         JSR      BUSY
         LDA      #%00000110      ; set entry mode to increment cursor right 
         STA      LCDC
         JSR      BUSY
         LDA      #$01            ; clear display
         STA      LCDC
         JSR      BUSY  
         LDY      #0
-        LDA      WLCM,Y
         BEQ      +
         STA      LCDD
         JSR      BUSY
         INY
         JMP      -
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
         AND      #$80
         BNE      -
         PLA
         RTS

;------------------------------------------------------------------------------
DISPLAY  PHY               ; push Y
         PHA               ; push A
         LSR               ; shift high nibble into low nibble
         LSR
         LSR 
         LSR 
         TAY
         LDA     HEX,Y     ; convert to ASCII
         STA     LCDD      ; display value on the LCD
         JSR     BUSY
         PLA               ; restore original value
         PHA
         AND     #$0F      ; select low nibble
         TAY
         LDA     HEX,Y     ; convert to ASCII
         STA     LCDD      ; send value on the LCD
         JSR     BUSY
         PLA
         PLY
         RTS
;------------------------------------------------------------------------------

WLCM     !text"65C02 Ready",0

KEYS	!text"123A456B789CE0FD"
HEX      !text"0123456789ABCDEF"


;==============================================================================
;ISR
         *=IRQ_VECTOR
         PHA
         LDA      IFR
         ASL                        ; T1 now in bit 7
         BMI      T1                ; if set it was T1
         ASL                        ; T2 now in bit 7
         BMI      T2                ; if set it was T2
         LDA      PA                ; gets key value and clears IFR
         AND      #%00001111        ; select low nibble
         STA      LASTKEY
         SMB5     FLAG              ; set the flag byte
         JMP      OUT
T1       LDA      # < T_LOAD        ; reload the low byte of T1
         STA      T1CL
         LDA      # > T_LOAD        ; reload the high byte of T1
         STA      T1CH              ; restarts count
         SMB7     FLAG              ; set bit 7 of FLAG
         JMP      OUT
T2       LDA      # < T_LOAD        ; reload the low byte ot T2
         STA      T2CL
         LDA      # > T_LOAD        ; reload the high byte of T2
         STA      T2CH              ; restarts count
         SMB6     FLAG              ; set bit 6 of FLAG
OUT      PLA
         RTI
!fill $E240-*, $EA

