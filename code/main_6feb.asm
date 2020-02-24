;
;Program to display 6502 registers using macros
;Date: 4th February 2020
;Author: Robin Harris

;RAM: 32k $0000 to $7FFF
;ROM  8k  $E000 to $FFFF
;
!cpu w65c02
!initmem    $EA ; fill empty memory locations with NOP
LCD_Data = $8001   
LCD_Command = $8000
reset_vector = $E100
DELAYCOUNTER = $0050

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

; code to move a block of bytes into RAM at $0A00  [Moves 256 bytes]
            *=reset_vector
            sei                     ; disable interrupts
            ldx     #$ff            ; set stack pointer
            txs
            ldx     #END - START           ; counter for bytes to move
; move a block of bytes
-           LDA     START, X        ; first byte - load
            STA     $0A00, X        ; first byte - store
            CPX     #0
            BEQ     DONE            ; if we've done x=0 then we are done and can run the main program
            DEX                     ; decrement x
            JMP     -
DONE        JMP     RUN             ; run the code block we have just moved into RAM

START       NOP                     ; block move uses this address in the ROM locations to start moving.  Avoids hard coding adress
;main program which gets moved to RAM at $0A00 before being run
        !pseudopc $0A00 {
RUN         jsr     LCDINIT         ; initialise display

; do some random stuff
            lda     #$04
            TAX
            DEX
            LDY     #$AD
            JSR     REGS
            ldx     #$80            ; a counter
-           JSR     LONGDELAY       ; do a long delay the number of times set by the counter
            DEX
            BNE     -
            LDA     #$64
            LDY     #$AB
            ldx     #$0D
            JSR     LINE2 
            JSR     REGS

FOREVER     nop
            JMP     FOREVER

; DISPLAY THE REGISTERS
REGS        PHA                     ; push A - this version will be restored at the end the subroutine
            PHA                     ; push A again - this version gets used for the display but is overwritten later
            LDA     #$41            ; Character "A"
            STA     LCD_Data
            JSR     SHORTDELAY
            +insertColon
            PLA                     ; pull A ready to display the passed value
            JSR     LCDHEX          ; DISPLAY A

            LDA     #$58            ; Character "X"
            STA     LCD_Data
            JSR     SHORTDELAY
            +insertColon
            TXA                     ; PUT X IN A REGISTER
            JSR     LCDHEX          ; DISPLAY X

            LDA     #$59            ; Character "X"
            STA     LCD_Data
            JSR     SHORTDELAY
            +insertColon
            TYA
            JSR     LCDHEX          ; DISPLAY Y
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

LINE1:      lda     #$01            ; clear display and move back to home
            sta     LCD_Command
            jsr     LONGDELAY
            rts

LINE2:      PHA
            lda     #$c0            ; move to position $c0 which is second row left
            sta     LCD_Command
            jsr     LONGDELAY
            PLA
            rts

SHORTDELAY: lda     #$05           
            sta     DELAYCOUNTER    ; 14 cycles from here.  1 cycle = 1uS so 14uS per loop so 5 loops should be plenty
D1          dec     DELAYCOUNTER
            nop
            bne     D1
            rts

LONGDELAY:  lda     #$a0
            sta     DELAYCOUNTER    ; 14 cycles from here.  Need 1.52mS or 22 loops
D2          dec     DELAYCOUNTER
            nop
            bne     D2
            rts

LCDHEX      PHY                     ; push Y
            PHA                     ; push A
            LSR                     ; shift high nibble into low nibble
            LSR 
            LSR 
            LSR 
            TAY
            LDA     HEXASCII,Y      ; convert to ASCII
            STA     LCD_Data        ; print value on the LCD
            JSR     SHORTDELAY
            PLA                     ; restore original value
            PHA
            AND     #$0F            ; select low nibble
            TAY
            LDA     HEXASCII,Y      ; convert to ASCII
            STA     LCD_Data        ; print value on the LCD
            JSR     SHORTDELAY
            +insertSpace
            PLA
            PLY
            RTS

; *** Lookup table for HEX to ASCII
HEXASCII	!text"0123456789ABCDEF",0
        }
END         NOP