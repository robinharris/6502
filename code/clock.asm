;============================================================================================
;
;Program to display a 24 hour clock on line 1
;and day plus date on line 2
;
;  MAJOR REFACTORING
;
;Date: 24th February 2020
;Author: Robin Harris

;RAM: 32k $0000 to $7FFF
;ROM  8k  $E000 to $FFFF
;
;============================================================================================

!initmem $EA
!cpu w65c02

reset_vector = $E100
IRQ_vector = $E400
LCD_Data = $8001   
LCD_Command = $8000

;ZERO PAGE USAGE
DELAYCOUNTER = $0050
INNERDELAY = $0054
SECONDS = $0051
MINUTES = $0052
HOURS = $0053
DAYOFWEEK = $0054
MONTH = $0055
DAYOFMONTH = $0056
; data to initialise
SETMINUTES = $10
SETHOURS = $18
SETDAYOFMONTH = $24 ; 1 to 31
SETDAYOFWEEK = $0 ; 0 to 6
SETMONTH = $1 ; 0 to 11


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
                LDA             #0              ; initialise seconds
                STA             SECONDS         ; 
                LDA             #SETMINUTES     ; initialise minutes
                STA             MINUTES         ;
                LDA             #SETHOURS       ; initialise hours
                STA             HOURS           ;
                LDA             #SETDAYOFMONTH  ; initialise dayOfMonth
                STA             DAYOFMONTH      ;
                LDA             #SETDAYOFWEEK   ; initialise dayOfWeek
                STA             DAYOFWEEK       ;
                LDA             #SETMONTH       ; initialise month
                STA             MONTH           ;
                CLI                             ; interrupts on

; *** counting
; start by sending the current time values to the LCD
START           JSR             CLEAR           ; clear the display
                LDA             #$20            ; load value for space
                STA             LCD_Data        ; send display character 4 times
                JSR             BUSY
                STA             LCD_Data
                JSR             BUSY
                STA             LCD_Data
                JSR             BUSY
                STA             LCD_Data
                JSR             BUSY
                LDA             HOURS
                JSR             DISP2CHAR       ; update LCD
                +insertColon
                LDA             MINUTES         ; 2 is the index for minutes
                JSR             DISP2CHAR       ; update LCD
                +insertColon
                LDA             SECONDS             ; 1 is the index for seconds
                JSR             DISP2CHAR       ; update LCD
; move to line 2
                LDA             #$c0            ; move to position $c0 which is second row left
                STA             LCD_Command
                JSR             BUSY
                LDA             #$20            ; character for space
                STA             LCD_Data        ; send three spaces 
                JSR             BUSY
                STA             LCD_Data
                JSR             BUSY
                STA             LCD_Data
                JSR             BUSY
                LDA             DAYOFWEEK       ; get the day of week number
                ASL                             ; multiply by 2
                ADC             DAYOFWEEK       ; add another DAYOFWEEK effectively multiplying by 3
                TAY                             ; set up an index into DAYNAMES
                LDA             DAYNAMES, Y
                STA             LCD_Data        ; display day of week character 1
                INY                             ; increment Y while LCD is busy
                JSR             BUSY
                LDA             DAYNAMES, Y
                STA             LCD_Data        ; display day of week character 2
                INY                             ; increment Y while LCD is busy
                JSR             BUSY
                LDA             DAYNAMES, Y
                STA             LCD_Data        ; display day of week character 3
                JSR             BUSY
                LDA             #$20            ; load value for space
                STA             LCD_Data        ; send to display
                JSR             BUSY
                LDA             DAYOFMONTH      ; get the day of month number
                JSR             DISP2CHAR       ; display the day of month
                LDA             #$20            ; load value for space
                STA             LCD_Data        ; send to display
                JSR             BUSY
                LDA             MONTH           ; get month number
                ASL                             ; multiply by 2
                ADC             MONTH           ; add another month effectively multiplying by 3
                TAY                             ; set up an index into MONTHNAMES
                LDA             MONTHNAMES, Y
                STA             LCD_Data        ; display month character 1
                INY
                JSR             BUSY
                LDA             MONTHNAMES, Y
                STA             LCD_Data        ; display month character 2
                INY
                JSR             BUSY
                LDA             MONTHNAMES, Y
                STA             LCD_Data        ; display month character 3
                JSR             BUSY
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
                ADC             #1              ; add 1 to minutes
                CLD
                CMP             #$60            ; check if 60
                BCS             HRS             ; if 60 update hours
                STA             MINUTES         ; otherwise store new value of minutes
                JMP             START
HRS             LDA             #0
                STA             MINUTES         ; reset minutes
                LDA             HOURS
                SED
                CLC
                ADC             #1
                CLD
                CMP             #$24
                BCS             NEWDAY
                STA             HOURS
                JMP             START
NEWDAY          LDA             #$0             ; reset hours to 0
                STA             HOURS
                INC             DAYOFWEEK       ; increment day of week
                LDA             DAYOFWEEK       ; load A to compare
                CMP             #$7             ; Check if we are on a new week
                BCC             CHECKMONTH      ; reset day of week to 1
                LDA             #$0             ; reset day of week
                STA             DAYOFWEEK
CHECKMONTH      LDA             DAYOFMONTH
                SED                             ; enter decimal mode
                CLC                             ; clear carry
                ADC             #1              ; add 1
                CLD                             ; exit decimal mode
                STA             DAYOFMONTH      ; store the new value for comparison
                LDY             MONTH           ; index into daysinmonth byte list
                CMP             DAYSINMONTH, Y  ; 
                BCS             NEWMONTH        ; if dayinmonth is now greater than the month value branch to reset
                JMP             START
NEWMONTH        LDA             #$0
                STA             DAYOFMONTH
                INC             MONTH
                JMP             START

; display a number up to 99
; on entering A contains the number to display
DISP2CHAR       PHA
                LSR                            ; shift high nibble to lower 4 bits
                LSR
                LSR
                LSR
                TAY                             ; transfer into Y
                LDA             NUMBERS, Y
                STA             LCD_Data        ; send first digit
                JSR             BUSY
                PLA
                AND             #$0F            ; select lower nibble
                TAY
                LDA             NUMBERS, Y
                STA             LCD_Data        ; send second digit
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
CLEAR           LDA             #%00000010            ; move back to home
                STA             LCD_Command
                JSR             BUSY
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
DAYNAMES    !text "MONTUEWEDTHUFRISATSUN"
MONTHNAMES  !text "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC"
DAYSINMONTH !byte 31,28,31,30,31,30,31,31,30,31,30,31

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