;============================================================================================
;
;Program to test 6522 with 74LS922 keypad
;Date: 19th April 2020
;Author: Robin Harris
;VERSION 3

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
IRQ_VECTOR = $E200
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
DIN = $46         ; inner delay counter
DOUT = $47        ; outer delay counter
DPOS = $48        ; counts number of interrupts


         *=RESET_VECTOR

; *** SETUP
         SEI               ; interrupts off
         LDX      #$FF     ; initialise stack
         TXS
         JSR      LCDINIT  ; initialise LCD
         LDA      #0
         STA      DPOS     ; start counting display position at zero
         CLD
         CLI

;==============================================================================
; MAIN PROGRAM
         LDA      #%00000000        ; set all PA to input
         STA      DDRA
         LDA      #%11111111        ; set all PB to output
         STA      DDRB

         LDA      #%00000001        ; ACR - Bit 6 set for continuous mode T1 and bit 0 sets PA for latching
         STA      VIAB

         LDA      #%00000001        ; PCR - Bit 0 sets CA for positive edge
         STA      VIAC

         LDA      #%10000010        ; interrupts - enable CA1 by setting bit 1
         STA      VIAE

; loop forever waiting for interrupt
LOOP     NOP
         JMP      LOOP
;==============================================================================

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
; displays a nibble as a hex character - load the nibble into A
     
DKEY     PHA
         LDX      DPOS      ; get display position
         INX                ; increment display position
         STX      DPOS
         CPX      #$10      ; check if end of line 1
         BNE      +
         LDA      #0        ; reset cursor position to zero
         STA      DPOS
         LDA      #1        ; clear display
         STA      LCDC
         JSR      BUSY
+        PLA
         TAY
         LDA      KEY,Y     ; convert to character
         STA      LCDD      ; send value on the LCD
         JSR      BUSY
         RTS

KEY	!text"123A456B789C*0#D0123456789"

         *=IRQ_VECTOR
         PHA
         PHY
         LDA      RA       ; clears IFR
         AND      #%00001111
         STA      RB
         JSR      DKEY
         PLY
         PLA
         RTI
!fill $E220-*, $EA

