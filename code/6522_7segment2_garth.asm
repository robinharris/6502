;============================================================================================
;
; Uses Port B to display hex characters on a 4 x 7 segment display
; with 2 x 74HC595 shift registers.  The first shift register provides segment outputs and 
; the second one provides 4 lines for the digit selection
;Date: 11th May 2020
;Author: Robin Harris
;VERSION 4

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
SR   = $801A     ; shift register
ACR  = $801B     ; auxiliary control register
PCR  = $801C     ; peripheral control register
IFR  = $801D     ; interrupt flag register
IER  = $801E     ; interrupt enable register
VIAF = $801F     ; ORA/IRA without handshake

;==============================================================================
; ZERO PAGE
; this is loaded into both timers to generate a IRF after 50mS.
DATAH = $20        ;(4 bytes)
DATAL = $21        ;(4 bytes)
POS = $22         ; digit of display numbered 1 to 4 left to right
COUNTER = $23


;==============================================================================
; MACROS
!macro W8{
         NOP
         NOP
         NOP
         NOP
}


;==============================================================================
; SETUP
         *=RESET_VECTOR
; *** SETUP
         SEI                        ; interrupts off - leave off so T2 does interrupt does not take any action
         LDX      #$FF              ; initialise stack
         TXS
         JSR      VIAINIT
         JSR      LCDINIT
; initialise variables
         STZ      DATAH
         STZ      DATAL             
         STZ      COUNTER
         LDA      #3
         STA      POS               ; set digit position to position 4 initially
         STZ      T1CL              ; load and start T1 by loading counter low then high bytes
         LDA      #$17
         STA      T1CH
         CLI
         
;==============================================================================
; MAIN PROGRAM GOES HERE

LOOP     LDA      #$77              ; larger gives a longer delay between couting updates
         CMP      COUNTER
         BNE      LOOP              ; keep waiting for an interrupt that increases COUNTER to value in A
         STZ      COUNTER           ; reset counter
         INC      DATAL             ; 16 bit addition.  If DATAL wraps to zero next test will
         BNE      LOOP
         INC      DATAH
         BRA      LOOP



;==============================================================================

;SUBROUTINES
;------------------------------------------------------------------------------
; *** Via setup
VIAINIT  LDA      #%00000000        ; set all PA to input - bits 0 - 3 used for keypad
         STA      DDRA
         LDA      #%11111111        ; set all PB to output - PB0 is the latch
         STA      DDRB
         LDA      #%01011000        ; SR in PHI2 shift out mode
         STA      ACR 
         LDA      #%00000000        ; PCR - Bit 0 sets CA for positive edge
         STA      PCR
         LDA      #%11000000        ; interrupts - T1 enabled
         STA      IER
         LDA      #%00111111        ; interrupts - all disabled except T1
         STA      IER
         STZ      PB                ; set all PB pins to low
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
DGT      !byte $FC,$60,$DA,$F2,$66,$B6,$BE,$E0,$FE,$F6,$EE,$3E,$9C,$7A,$9E,$8E
SRH      !byte 8,4,2,1

;==============================================================================
;ISR
         *=IRQ_VECTOR
         PHA
         PHX
         LDA      T1CL     ; clear T1 IFR
         INC      COUNTER  ; used in main loop to time updates to data (increment by 1)
; based on the next digit to display find the relevant nibble
; 3 = DATAL, low nibble, 2 = DATAL, high nibble, 1 = DATAH, low nibble, 0 = DATAH, high nibble
; after loading A with the appropriate nibble branch to OUT to send it to the 7 segment display
         LDX      POS
         BEQ      DHHN     ; POS is zero so need high nibble of high byte
         DEX
         BEQ      DHLN     ; POS was 1 so need low nibble of high byte
         DEX
         BEQ      DHLN     ; POS was 2 so need high nibble of low byte
         LDA      DATAL    ; POS was 3 so need low nibble of low byte
         AND      #$0F
         BRA      OUT

DHHN     LDA      DATAH    ;
         LSR
         LSR
         LSR
         LSR
         BRA      OUT

DHLN     LDA      DATAH
         AND      #$0F
         BRA      OUT

DLHN     LDA      DATAL
         LSR
         LSR
         LSR
         LSR

; next section sends two bytes to the SR first the high byte which selects the digit
; then the low byte which is the pattern for that digit.
; on arrival here A contains just nibble of data for that digit
OUT      PHA               ; push nibble to be displayed 
         LDY      POS      ; get the next digit to display
         LDA      SRH,Y    ; get bit pattern for high byte
         STA      SR       ; send the high byte
         +W8               ; waiting for shift register to shift out
         PLX               ; original nibble to be displayed pulled from stack
         LDA      DGT,X    ; get the pattern for the nibble value
         STA      SR       ; send the low byte
         DEC      POS      ; move the digit selector bit to the next left
         +W8               ; allow time for shift register to send the second byte
         BPL      LATCH    ; if POS is negative need to reset
         LDA      #$3      ; reset digit to the 4th 
         STA      POS
LATCH    LDA      #1     ; toggle PB0 to latch the data
         STA      PB
         +W8
         STZ      PB
         PLX       
         PLA
         RTI
!fill $E290-*, $EA

