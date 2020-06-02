;============================================================================================
;
; LCD Demonstration 4 bit mode using 6522 VIA PORTB
; Generalised to display any message
; Date: 29th May 2020
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

;==============================================================================
; ZERO PAGE
COUNTER  = $23
HNIB     = $24
LNIB     = $25
SADDR    = $26 ; 2 byte address this is the low byte

;==============================================================================
; MACROS
         !MACRO   PRINT .STADD{
         LDA      #<.STADD
         STA      SADDR
         LDA      #>.STADD
         STA      SADDR+1
         JSR      CLR
         JSR      SDISP
}

;==============================================================================
; LABELS
E  = %10000000    ; PB7
RW = %01000000    ; PB6
RS = %00100000    ; PB5

;==============================================================================
; SETUP
         *=RESET_VECTOR
         SEI
         LDX      #$FF              ; initialise stack
         TXS
         JSR      VIAINIT           ; set up VIA
         JSR      LCDINIT           ; set up LCD
         CLI
         
;==============================================================================
; MAIN PROGRAM GOES HERE
         +PRINT   M1
LOOP     JMP      LOOP              ; do nothing


;==============================================================================

;SUBROUTINES
; *** Via setup
VIAINIT  LDA      #%11111111        ; set all PB to output
         STA      DDRB
         LDA      #0
         STA      PB                ; set all PORTB pins low
         RTS
;------------------------------------------------------------------------------
; *** Initialises the LCD in 2 line 4 bit mode with display on, cursor off and counter incrementing right
LCDINIT  
; first some long delays to ensure the LCD is ready to receive commands whenever the reset sequence is started
         LDX      #4
--       LDA      #$FA             ; gives a delay of 25mS
         STA      COUNTER
         JSR      DELAY
         DEX
         BMI      --                ;
; send the command three times to tell the LCD we want to manually reset
; the delay lengths are important
         LDA      #%00000011
         JSR      SCOM
         LDA      #29               ; need 4.1mS delay
         STA      COUNTER
         JSR      DELAY             ; default 100uS delay
         LDA      #%00000011
         JSR      SCOM              ; default 100uS delay
         LDA      #%00000011
         JSR      SCOM              ; default 100uS delay
; next command is still in 8 bit mode (lower 4 bits data lines on LCD are ignored though)
; so now we put the LCD into 4 bit mode
         LDA      #%00000010        ; function set - bits 0 to 3 are the command to change to 4 bit mode
         JSR      SCOM
         LDA      #%00101000        ; 4 bit mode, N = 1 (2 lines) and F = 0 (5 x 8 dots)
         JSR      SCOM        
; datasheet is unclear if next step is strictly necessary here.  Mostly works ok to set required display now
; but for comfort I set the display off here and turn it back on at the end of initialisation
         LDA      #%00001000        ; display off
         JSR      SCOM        
         LDA      #%00000001        ; clear display
         JSR      SCOM        
         LDA      #%00000110        ; entry mode - shift cursor right no display shift
         JSR      SCOM        
         LDA      #%00001100        ; display on, cursor off
         JSR      SCOM        
; send the welcome message
         LDY      #0                ; prepare Y to index into message
-        LDA      WLCM,Y            ; next character of message WLCM
         BEQ      +                 ; exit this loop when a null is read
         JSR      SCHAR
         INY
         BRA      -                 ; next character
+        RTS

;------------------------------------------------------------------------------
; check the BUSY FLAG
; preserves A
BUSY     PHA
         LDA      #%11110000        ; set PORTB pins 0 - 3 as input
         STA      DDRB
-        LDA      #RW               ; set RW high to read and RS low (command)
         ORA      #E                ; set E
         STA      PB        
; now get the high nibble containing the busy flag and top 3 bits of address counter
         LDA      PB                ; get high byte
         STA      HNIB
         LDA      #RW               ; clear E but leave RW high
         STA      PB
         ORA      #E                ; take E high to get lower nibble
         STA      PB  
; next get the low nibble containing the lower bits of the address counter
         LDA      PB
         STA      LNIB
         LDA      #RW               ; clear E but leave RW high.  This completes the 2nd nibble read
         STA      PB
         LDA      HNIB              ; get the high nibble - busy flag will be in bit 3
         AND      #%00001000        ; mask to leave only bit 3    
         BNE      -                 ; if busy flag is set go back and check again
         LDA      #%11111111        ; set PORTB pins back to output
         STA      DDRB
         PLA
         RTS

;------------------------------------------------------------------------------
; *** sends a character to the display
; ENTRY: A contains character in ASCII to send
; saves A
SCHAR    PHA                        ; this copy is restored at end
         PHA
         JSR      BUSY              ; wait for BF to clear
         LSR                        ; shift high nibble to low 4 bits
         LSR
         LSR
         LSR
         ORA      #RS               ; select data register, RW must be low because of the LSR instructions
         ORA      #E                ; set E
         STA      PB
         EOR      #E                ; clear E
         STA      PB
         PLA                        ; restore character
         AND      #%00001111        ; mask off high nibble
         ORA      #RS               ; select data register, RW must be low because of the AND instruction
         ORA      #E                ; set E
         STA      PB
         EOR      #E                ; clear E
         STA      PB
         PLA                        ; restores original A
         RTS

;------------------------------------------------------------------------------
; *** sends a command after waiting the default 100uS delay
; ENTRY: A contains the command to send
; destroys A
SCOM     PHA
         JSR      DELAY
         LSR                        ; shift high nibble to low 4 bits
         LSR
         LSR
         LSR
         ORA      #E                ; set E, RS must be low because of the LSR instructions
         STA      PB
         EOR      #E                ; clear E
         STA      PB
         PLA                        ; restore command
         AND      #%00001111        ; mask off high nibble
         ORA      #E                ; set E, RS must be low because of the AND instruction
         STA      PB
         EOR      #E                ; clear E
         STA      PB
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
         JSR      SCOM
         LDA      #$20              ; load 'space'
         LDX      #$10              ; need to write space to 16 character positions
-        JSR      SCHAR
         DEX
         BNE      -
         LDA      #$C0              ; move beginning of line 2
         JSR      SCOM
         RTS

;------------------------------------------------------------------------------
; sends a string to the display
; put string address in SADDR (low byte) then call this routine
SDISP    LDY      #0
--       LDA      (SADDR),Y
         BEQ      +              ; exit when a 0 is read
         JSR      SCHAR          ; A contains the ASCII character to send
         INY
         BRA      --
+        RTS

;==============================================================================
;TABLES
WLCM     !text"65C02 Ready",0
M1       !text"LCD test ok",0
M2       !text"HD44780 4 Bit",0
M3       !text"Assembly!",0

;==============================================================================
;ISR
         *=IRQ_VECTOR
         PHA
         PLA
         RTI
!fill $E240-*, $EA

