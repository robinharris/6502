;============================================================================================
;
;Program to display a 24 hour clock
;Date: 9th February 2020
;Author: Robin Harris

;RAM: 32k $0000 to $7FFF
;ROM  8k  $E000 to $FFFF
;
;============================================================================================

!initmem $EA
!cpu w65c02

reset_vector = $E100
IRQ_vector = $E300
LCD_Data = $8001   
LCD_Command = $8000
DELAYCOUNTER = $0050
INNERDELAY = $0054
SECONDS = $0051
MINUTES = $0052
HOURS = $0053

!macro insertColon{
    LDA     #$3A
    STA     LCD_Data
    JSR     BUSY
}
                *=reset_vector
; *** SETUP
                SEI                             ; interrupts off
                LDX             #$FF            ; initialise stack
                TXS
                JSR             LCDINIT         ; initialise LCD
                LDA             #0              ;
                STA             SECONDS         ; initialise HOURS, MINUTES & SECONDS
                STA             MINUTES         ;
                STA             HOURS           ;
                CLI                             ; interrupts on

; *** counting
; start by sending the current time values to the LCD
START           JSR             LINE1           ; clear the display
                LDY             #$3             ; 3 is the index for hours
                JSR             DISPLAY         ; update LCD
                +insertColon
                LDY             #$2             ; 2 is the index for minutes
                JSR             DISPLAY         ; update LCD
                +insertColon
                LDY             #$1             ; 1 is the index for seconds
                JSR             DISPLAY         ; update LCD
; main timing delay loop
                LDY             #$F1            ; a counter
-               JSR             LONGDELAY       ; do a long delay the number of times set by the counter
                DEY
                BNE             -
; now increment seconds and roll up
                LDA             SECONDS
                SED                             ; Decimal mode on
                CLC                             ; clear carry
                ADC             #1              ; add 1 to seconds
                CLD
                CMP             #$60            ; check if 60
                BCS             MINS            ; if 60 update minutes
                STA             SECONDS         ; otherwise store new value and go back to sart
                JMP             START
MINS            LDA             #$0
                STA             SECONDS         ; reset seconds
                LDA             MINUTES
                SED
                CLC                             ; clear carry
                ADC             #1             ; add 1 to minutes
                CLD
                CMP             #$60            ; check if 60
                BCS             HRS             ; if 60 update hours
                STA             MINUTES         ; otherwise store new value of minutes
                JMP             START
HRS             LDA             #0
                STA             MINUTES         ; reset minutes
                STA             SECONDS         ; reset seconds
                LDA             HOURS
                SED
                CLC
                ADC             #1
                CLD
                CMP             #$24
                BCS             DAY
                STA             HOURS
                JMP             START
DAY             LDA             #$0
                STA             HOURS
                JMP             START

DISPLAY         LDA             $0050, Y       ; base address + Y which should contain 1=SECONDS, 2=MINUTES, 3=HOURS
                PHA
                LSR                            ; shift high nibble to lower 4 bits
                LSR
                LSR
                LSR
                TAY                             ; transfer into Y
                LDA             NUMBERS, Y
                STA             LCD_Data        ; send first digit fo hours
                JSR             BUSY
                PLA
                AND             #$0F            ; select lower nibble
                TAY
                LDA             NUMBERS, Y
                STA             LCD_Data        ; send second digit of hours
                JSR             BUSY
                RTS

; *** Initialises the LCD in 2 line 8 bit mode with display on, cursor off and counter incrementing right
LCDINIT         LDA             #%00111000      ; set mode to 2 line 8 bit
                STA             LCD_Command
                JSR             BUSY
                LDA             #%00001100      ; turn on display on, cursor off
                STA             LCD_Command
                JSR             BUSY
                LDA             #%00000110      ; set entry mode to increment cursor right 
                STA             LCD_Command
                JSR             BUSY
                LDA             #$01            ; clear display
                STA             LCD_Command
                JSR             BUSY    
                RTS

; *** Positions cursor top left and clears display
LINE1:          PHA
                LDA             #%00000010            ; move back to home
                STA             LCD_Command
                JSR             BUSY
                PLA
                RTS

; *** Positions cursor at beginning of second line
LINE2           PHA
                LDA             #$c0            ; move to position $c0 which is second row left
                STA             LCD_Command
                JSR             BUSY
                PLA
                RTS

; *** Checks Bit 7 of Command Register until it clears to 0
BUSY            PHA
-               LDA             LCD_Command          
                AND             #$80
                BNE             -
                PLA
                RTS

LONGDELAY       PHA
                LDA             #$FF
                STA             DELAYCOUNTER 
-               NOP
                NOP
                NOP
                NOP
                NOP
                DEC             DELAYCOUNTER
                BNE             -
                PLA
                RTS

; *** table of display values
NUMBERS     !text "0123456789"

; *** IRQ ISR.  Zeros seconds and minutes
                * = IRQ_vector
                SEI                             ; disable interrupts
                PHA
                LDA             #$0
                STA             SECONDS         ; set seconds to 0
                STA             MINUTES         ; set minutes to 0
                PLA
                CLI                             ; enable interrupts
                RTI