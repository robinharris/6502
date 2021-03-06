;
;Program to display 0 to 99 counting in decimal 
;Date: 6th February 2020
;Author: Robin Harris

;RAM: 32k $0000 to $7FFF
;ROM  8k  $E000 to $FFFF
;
!cpu w65c02
!initmem $EA
LCD_Data = $8001   
LCD_Command = $8000
reset_vector = $E100
IRQ_vector  = $E300
DELAYCOUNTER = $0050
INNERDELAY = $0054
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
START       LDA     #0              ; start at 0
            STA     SECONDS         ; set all times to 0
            STA     MINUTES
            STA     HOURS
            CLI                     ; enable interrupts

-           JSR     SHOWNUMBER      ; Show the first number
            LDA     SECONDS
            SED                     ; set decimal mode
            CLC                     ; clear carry
            ADC     #1              ; add 1
            CMP     #$60            ; compare to $60 
            BCS     MINUTE          ; branch on CARRY SET (i.e. when A = > $60)
            STA     SECONDS
            JMP     -               ; otherwise show the new number
MINUTE      LDA     MINUTES         ; seconds have rolled over so add 1 to minutes
            CLC                     ; clear carry
            ADC     #1              ; still in Decimal mode
            CMP     #$60            ; have we reached 60 minutes
            BCS     HOUR            ; If CARRY SET then A = > $60 so increment HOUR
            STA     MINUTES         ; store the latest value
            LDA     #0              ; set seconds back to 0
            STA     SECONDS
            JMP     -
HOUR        LDA     HOURS           ; minutes have rolled over so add 1 to hours
            CLC                     ; clear carry
            ADC     #1              ; 
            CMP     #$24            ; have we reached 24 hours
            BCS     START           ; If CARRY SET then A = > $24 so reset
            STA     HOURS           ; update stored HOURS
            LDA     #0
            STA     MINUTES         ; reset minutes
            STA     SECONDS         ; reset seconds
            JMP     -

; SHOW THE NUMBER
; number to show is in Y
SHOWNUMBER  PHA                     ; this is the value that gets restored
            JSR     LINE1           ; clear display and move cursor to home
            LDA     HOURS
            LSR                     ; shift high nibble to lower 4 bits
            LSR
            LSR
            LSR
            TAY                     ; transfer into Y
            LDA     NUMBERS, Y
            STA     LCD_Data        ; send first digit fo hours
            JSR     SHORTDELAY
            LDA     HOURS           ; restore A
            AND     #$0F            ; select lower nibble
            TAY
            LDA     NUMBERS, Y
            STA     LCD_Data        ; send second digit of hours
            JSR     SHORTDELAY

            LDA     #$3A
            STA     LCD_Data        ; send colon
            JSR     SHORTDELAY

            LDA     MINUTES
            LSR                     ; shift high nibble to lower 4 bits
            LSR
            LSR
            LSR
            TAY                     ; transfer into Y
            LDA     NUMBERS, Y
            STA     LCD_Data        ; send first digit of minutes
            JSR     SHORTDELAY
            LDA     MINUTES         ; restore A
            AND     #$0F            ; select lower nibble
            TAY
            LDA     NUMBERS, Y
            STA     LCD_Data        ; send second digit of minutes
            JSR     SHORTDELAY

            LDA     #$3A
            STA     LCD_Data        ; send colon
            JSR     SHORTDELAY

            LDA     SECONDS         ; Back to seconds in A
            LSR                     ; shift high nibble to lower 4 bits
            LSR
            LSR
            LSR
            TAY                     ; transfer into Y
            LDA     NUMBERS, Y
            STA     LCD_Data        ; send first digit of seconds
            JSR     SHORTDELAY
            LDA     SECONDS         ; restore A
            AND     #$0F            ; select lower nibble
            TAY
            LDA     NUMBERS, Y
            STA     LCD_Data        ; send second digit of seconds
            LDX     #$E1            ; a counter
-           JSR     LONGDELAY       ; do a long delay the number of times set by the counter
            DEX
            BNE     -
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
            lda #$01            ; clear display and move back to home
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
            lda     #$90
            sta     DELAYCOUNTER 
D2          LDA     #2
            STA     INNERDELAY
-           DEC     INNERDELAY
            NOP
            BNE     -
            dec     DELAYCOUNTER
            bne     D2
            PLA
            rts

; ***** table of display values
NUMBERS     !text "0123456789"

; IRQ ISR
            * = IRQ_vector
            SEI                     ; disable interrupts
            LDA     #$0
            STA     SECONDS         ; set seconds to 0
            STA     MINUTES         ; set minutes to 0
            CLI                     ; enable interrupts
            RTI