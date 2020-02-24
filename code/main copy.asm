;
;Program to display 0 to 99 counting in decimal 
;Date: 6th February 2020
;Author: Robin Harris

;RAM: 32k $0000 to $7FFF
;ROM  8k  $E000 to $FFFF
;
!cpu w65c02
LCD_Data = $8001   
LCD_Command = $8000
reset_vector = $E100
DELAYCOUNTER = $0050
SECONDS = $0051
MINUTES = $0052
HOURS = $0053

!macro insertSpace{
    PHA
    LDA     #$20
    STA     LCD_Data
    JSR     SHORTDELAY
    PLA
}
!macro insertColon{
    PHA
    LDA     #$3A
    STA     LCD_Data
    JSR     SHORTDELAY
    PLA
}

;main program
            *=reset_vector
            sei                     ; disable interrupts
            ldx     #$ff            ; set stack pointer
            txs
            jsr     LCDINIT         ; initialise display

; counting routine
START       SED                     ; set decimal mode
            LDA     #0              ; start at 0
            STA     SECONDS         ; set all times to 0
            STA     MINUTES
            STA     HOURS
-           JSR     SHOWNUMBER      ; Show the first number
            ADC     #1              ; add 1
            CMP     #$60            ; compare to $60 
            BCS     MINUTE          ; branch on CARRY SET (i.e. when A = > $60)
            JMP     -               ; otherwise show the new number
MINUTE      LDA     MINUTES         ; seconds have rolled over so add 1 to minutes
            ADC     #1              ; still in Decimal mode
            CMP     #$60            ; have we reached 60 minutes
            BCS     HOUR            ; If CARRY SET then A = > $60 so increment HOUR
            STA     MINUTES         ; store the latest value
            LDA     #0              ; set seconds back to 0
            JMP     -
HOUR        LDA     HOURS           ; minutes have rolled over so add 1 to hours
            ADC     #1              ; Load HOURS for comparison
            CMP     #$24            ; have we reached 24 hours
            BCS     START           ; If CARRY SET then A = > $24 so reset
            STA     HOURS           ; update stored HOURS
            LDA     #0
            STA     MINUTES         ; update stored value of minutes
            JMP     -

; SHOW THE NUMBER
; number to show is in Y
SHOWNUMBER  PHA                     ; this is the value that gets restored
            PHA                     ; this copy is needed to get lower nibble after higher nibble
            PHA                     ; this one gets restored after minutes
            CLD
            JSR     LINE1           ; clear display and move cursor to home
            LDA     HOURS
            LSR                     ; shift high nibble to lower 4 bits
            LSR
            LSR
            LSR
            TAY                     ; transfer into Y
            LDA     NUMBERS, Y
            STA     LCD_Data
            JSR     SHORTDELAY
            LDA     HOURS           ; restore A
            AND     #$0F            ; select lower nibble
            TAY
            LDA     NUMBERS, Y
            STA     LCD_Data
            JSR     SHORTDELAY
            LDA     #$3A
            STA     LCD_Data
            JSR     SHORTDELAY
            LDA     MINUTES
            LSR                     ; shift high nibble to lower 4 bits
            LSR
            LSR
            LSR
            TAY                     ; transfer into Y
            LDA     NUMBERS, Y
            STA     LCD_Data
            JSR     SHORTDELAY
            LDA     MINUTES         ; restore A
            AND     #$0F            ; select lower nibble
            TAY
            LDA     NUMBERS, Y
            STA     LCD_Data
            JSR     SHORTDELAY
            LDA     #$3A
            STA     LCD_Data
            JSR     SHORTDELAY
            PLA                     ; Back to seconds in A
            LSR                     ; shift high nibble to lower 4 bits
            LSR
            LSR
            LSR
            TAY                     ; transfer into Y
            LDA     NUMBERS, Y
            STA     LCD_Data
            JSR     SHORTDELAY
            PLA                     ; restore A
            AND     #$0F            ; select lower nibble
            TAY
            LDA     NUMBERS, Y
            STA     LCD_Data
            LDX     #$E3            ; a counter
-           JSR     LONGDELAY       ; do a long delay the number of times set by the counter
            DEX
            BNE     -
            SED
            PLA                     ; restore original value of A
            RTS

LCDINIT     lda     #%00111000        ; set mode to 2 line 8 bit
            sta     LCD_Command
            jsr     SHORTDELAY
            lda     #%00001100        ; turn on display on, cursor off
            sta     LCD_Command
            jsr     SHORTDELAY
            lda     #%00000110        ; set entry mode to increment cursor right 
            sta     LCD_Command
            jsr     SHORTDELAY
            lda     #$01              ; clear display
            sta     LCD_Command
            jsr     LONGDELAY
            rts

LINE1:      PHA
            lda     #$01            ; clear display and move back to home
            sta     LCD_Command
            jsr     LONGDELAY
            PLA
            rts

LINE2:      PHA
            lda     #$c0            ; move to position $c0 which is second row left
            sta     LCD_Command
            jsr     LONGDELAY
            PLA
            rts

SHORTDELAY: PHA
            lda     #$05           
            sta     DELAYCOUNTER    ; 14 cycles from here.  1 cycle = 1uS so 14uS per loop so 5 loops should be plenty
D1          dec     DELAYCOUNTER
            nop
            bne     D1
            PLA
            rts

LONGDELAY:  PHA
            lda     #$a0
            sta     DELAYCOUNTER    ; 14 cycles from here.  Need 1.52mS or 22 loops
D2          dec     DELAYCOUNTER
            nop
            bne     D2
            PLA
            rts

; ***** table of display values
NUMBERS     !text "0123456789"