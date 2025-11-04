;HEADER STUFF
;ANGEL NAVA
;RCET 3375
;Semester 5
;LAB10.1 EEPROM
;Github URL

;Device Setup
;-------------------------------------------------------------------------------
    
;Configuration
    ; CONFIG1
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.

;Include Statements
#include <xc.inc>
;Code Section
;-------------------------------------------------------------------------------
 
;Start of Program
PSECT resetVect,class=CODE,delta=2 ;Reset vector address -Wl,-presetVect=00h
    GOTO Setup

;Interrupt is called
PSECT isrVect,class=CODE,delta=2 ;isr or something
    GOTO Interrupt

;Setup Code that runs once at the power up/reset
PSECT code,class=CODE,delta=2 ;-Wl,-pcode=08h
    
Setup:
    ;Bank 3 (for ANSELH)
    BSF STATUS, 5 ; Go to Bank 3
    BSF STATUS, 6 ; Go to Bank 3
    MOVLW 0x00 ;AN1 is analog input (pin 3)
    MOVWF ANSEL
    CLRF ANSELH; 13:8 are digital inputs
    CLRF OPTION_REG
    MOVLW 0x00
    MOVWF BAUDCTL
    CLRF EECON1
    

    ;BANK 2
    BSF STATUS,5
    BSF STATUS,6
    CLRF CM2CON1
    CLRF CM2CON0

    ;Bank 1 (for TRISB, WPUB, IOCB, OPTION_REG, TRISC)
    BSF STATUS, 5
    BCF STATUS, 6 ; Go to Bank 1
    CLRF WPUB
    CLRF TRISB ;The bits moved in make PortB all outputs
    MOVLW 0x03
    MOVWF IOCB ;Enables Interrupts on Bits 0 and 1 for Port B
    CLRF OPTION_REG ; Clears OPTION_REG (enables pull-ups globally, etc.)
    CLRF PSTRCON ;Disable PWM
    CLRF PCON ;Cleared power control register
    MOVLW 0x81
    MOVWF SPBRG
    CLRF SPBRGH
    MOVLW 0x26
    MOVWF TXSTA
    MOVLW 0X00
    MOVWF TRISA 
    MOVLW 0XFF ;Put bits into register
    MOVWF TRISB ;The bits moved in make PortB all inputs
    MOVLW 0x00
    MOVWF TRISC ;Bit 7 Input Bit 6 output
    MOVLW 0X02 ;02
    MOVWF PIE1
    MOVLW 0XFA
    MOVWF PR2 ;Timer 2 stuff
    ;MOVLW 0x80
    ;MOVWF ADCON1
    CLRF ADCON1

    ;Bank 0 (for INTCON, ports, peripherals)
    BCF STATUS, 5 ;Go to Bank 0
    BCF STATUS, 6 ; Go to Bank 0
    MOVLW 0x45 ;AN1 Selected. Go is enabled. A
    MOVWF ADCON0
    MOVLW 0XC8 ;C0
    MOVWF INTCON ;Controls interrupts (GIE=1, RBIE=1)
    CLRF PIR1
    CLRF CCP1CON ; Disables PWM
    MOVLW 0x00
    MOVWF PORTA
    MOVLW 0x00
    MOVWF PORTB
    MOVLW 0x00
    MOVWF PORTC
    
    CLRF CCP2CON ;Disables the second PWM function
    CLRF RCSTA ;Turns off the control register
    CLRF SSPCON ;Turns off the serial control port
    CLRF T1CON ;Turns off the timer register
    CLRF PSTRCON ;Disables PWM pulse steering
    CLRF CM2CON1 ;Disables Comparator 2
    MOVLW 0X00
    MOVWF TMR2
    MOVLW 0X06
    MOVWF T2CON
    
    ;Registers Setup
    STATS_SAVE EQU 0x20
    W_SAVE EQU 0x21
    C_SAVE EQU 0x22
    TIMER_COUNT EQU 0X23 ;Software counter for overflows
    RecordData EQU 0x24 ;Saves Data for EEPROM
    RecordAddress EQU 0x25 ;Saves address for EEPROM
    IsPlaying EQU 0x26 ;Record/Play Mode
    Count1 EQU 0x27

    MOVLW 0XFA
    MOVWF TIMER_COUNT
    CLRF RecordAddress
    CLRF IsPlaying

    GOTO MainLoop
;-------------------------------------------------------------------------------
;Main Program Loop (Loops Forever)
MainLoop:
    GOTO MainLoop

;-------------------------------------------------------------------------------
;Interrupt Service Routine
Interrupt:
    MOVWF W_SAVE
    MOVF STATUS, 0
    MOVWF STATS_SAVE

    ;Check Which Button caused the interrupt
    BTFSC PORTB,0 ;Record Button
    GOTO Record
    BTFSC PORTB,1 ;Play Button
    GOTO StartPlay
    
    ;No button was pressed. Timer Interrupt
    DECFSZ TIMER_COUNT,F
    GOTO INTERRUPT_END ; If counter not zero, exit
    
    ;Checks to see if PIC should Playback or Standby
    BTFSC IsPlaying,0
    GOTO Play
    
    ;Standby (flashes an S)
    MOVF PORTC,0
    XORLW 0x53
    BTFSC STATUS,2
    GOTO Blink
    
    MOVLW 0x53 ;S
    MOVWF PORTC
    
;Sets a One Second Timer for both Playback and Standby
OneSecondTimer:
    MOVLW 0xFA
    MOVWF TIMER_COUNT
    MOVLW 0xFA
    MOVWF PR2
    MOVLW 0X06
    MOVWF T2CON
    GOTO INTERRUPT_END
 
;Flashes a Blank
Blink:
    MOVLW 0x00 ;Blank
    MOVWF PORTC
    GOTO OneSecondTimer
    
;Sets/Starts the Playback mode
StartPlay:
    BSF IsPlaying,0
    GOTO INTERRUPT_END
   
;Does Playback  
Play:
    CLRF INTCON ;Disables Interrupts
    INCF RecordAddress ;Sets a new Address for a new entry to EEPROM
    CALL ReadEEPROM ;Reads data and outputs to PORTC
    
    XORLW 0xFF ;Was Data FF (End Playback Byte)?
    BTFSC STATUS,2
    GOTO STOP ;Result was 0. Matched
    GOTO OneSecondTimer ;Continue Playback

;Continously polls Key pads and Stop Button
Record:
    CLRF INTCON ;Disables Interrupts
    ;Checks Keypad
    MOVLW 0x08 ;Row 4
    MOVWF PORTA

    MOVLW 0x44 ;D
    BTFSC PORTB,4
    GOTO KEYPAD
    
    MOVLW 0x23 ;#
    BTFSC PORTB,5
    GOTO KEYPAD
    
    MOVLW 0x30 ;0
    BTFSC PORTB,6
    GOTO KEYPAD
    
    MOVLW 0x2A ;*
    BTFSC PORTB,7
    GOTO KEYPAD
;------------------------------------------------------------------------------  
    MOVLW 0x04 ;Row 3
    MOVWF PORTA
    
    MOVLW 0x43 ;C
    BTFSC PORTB,4
    GOTO KEYPAD
    
    MOVLW 0x39 ;9
    BTFSC PORTB,5
    GOTO KEYPAD
    
    MOVLW 0x38 ;8
    BTFSC PORTB,6
    GOTO KEYPAD
    
    MOVLW 0x37 ;7
    BTFSC PORTB,7
    GOTO KEYPAD
    ;--------------------------------------------------------------------------
    MOVLW 0x02 ;Row 2
    MOVWF PORTA
    
    MOVLW 0x42 ;B
    BTFSC PORTB,4
    GOTO KEYPAD
    
    MOVLW 0x36 ;6
    BTFSC PORTB,5
    GOTO KEYPAD
    
    MOVLW 0x35 ;5
    BTFSC PORTB,6
    GOTO KEYPAD
    
    MOVLW 0x34 ;4
    BTFSC PORTB,7
    GOTO KEYPAD
    ;--------------------------------------------------------------------------
    MOVLW 0x01 ;Row 1
    MOVWF PORTA
    
    MOVLW 0x41 ;A
    BTFSC PORTB,4
    GOTO KEYPAD
    
    MOVLW 0x33 ;3
    BTFSC PORTB,5
    GOTO KEYPAD
    
    MOVLW 0x32 ;2
    BTFSC PORTB,6
    GOTO KEYPAD
    
    MOVLW 0x31 ;1
    BTFSC PORTB,7
    GOTO KEYPAD
    
    BTFSC PORTB,2 ;Stop Button
    GOTO MaxData ;Write End Playback Byte and stop recording
    GOTO Record ;No buttons were pressed. Repoll the buttons
    
;Writes End Playback Byte
MaxData:
    MOVLW 0xFF ;End Playback Byte
    MOVWF RecordData
    INCF RecordAddress ;Sets a new Address for a new entry to EEPROM
    CALL WriteEEPROM ;Writes the End Playback Byte
    GOTO STOP
  
;Resets Record Address and Playback Mode
STOP:  
    CLRF RecordAddress ;Resets the Address back to 0
    CLRF IsPlaying ;Turns of Playback Mode
    GOTO INTERRUPT_END

;Keypad button was pressed
KEYPAD:
    MOVWF RecordData
    INCF RecordAddress ;Sets a new Address for a new entry to EEPROM
    CALL WriteEEPROM ;Writes the Keypad press to new entry
    
    ;Delay so that the button has some before triggering again
    MOVLW 0xFF
    MOVWF Count1
    Loop1:
    DECFSZ Count1
    GOTO Loop1
    
    ;Waits until keypad is no longer being pressed (debounce of sorts)
    Test:
    BTFSC PORTB,7
    GOTO Test
    BTFSC PORTB,6
    GOTO Test
    BTFSC PORTB,5
    GOTO Test
    BTFSC PORTB,4
    GOTO Test

    MOVF RecordAddress,0
    XORLW 0x0A ;Checks to see if Address amount is 10
    BTFSC STATUS,2
    GOTO MaxData ;Amount is 10. Write Playback End Byte and Stop Recording
    GOTO Record ;Amount is less than 10, Continue Recording
    
WriteEEPROM:
    MOVF RecordAddress,0 ;Choses Address
    BCF STATUS,5 ;Bank 2
    BSF STATUS,6
    MOVWF EEADR ;Address
    BCF STATUS,5
    BCF STATUS,6 ;Bank0
    MOVF RecordData,0 ;Choose what to write
    BCF STATUS,5 ;Bank 2
    BSF STATUS,6
    MOVWF EEDATA ;Data
    
    BSF STATUS,5
    BSF STATUS,6 ;Bank 3
    BCF EECON1,7 ;Points to Data Memory
    BSF EECON1,2 ;Enables Write Cycle
    MOVLW 0x55
    MOVWF EECON2
    MOVLW 0xAA
    MOVWF EECON2
    BSF EECON1, 1 ;Starts the Write Cycle
    
    BCF STATUS,5
    BCF STATUS,6 ;Bank 0
    
    GOTO ReadEEPROM
    
ReadEEPROM:
    BCF STATUS,5
    BCF STATUS,6 ;Bank 0
    MOVF RecordAddress,0 ;Choses Address
    
    BCF STATUS,5 ;Bank 2
    BSF STATUS,6
    MOVWF EEADR ; Address to read
    
    BSF STATUS,5 ;Bank 3
    BSF STATUS,6
    BSF EECON1,0 ; EE Read

    BCF STATUS,5 ;Bank 2
    BSF STATUS,6
    MOVF EEDATA, 0 ; W = EEDATA 
    
    BCF STATUS,5 ;Bank 0
    BCF STATUS,6
    MOVWF PORTC
    
    RETURN
    
INTERRUPT_END:
    BCF STATUS,5
    BCF STATUS,6
    BCF PIR1,1 ;Clears TMR2 to PR2 Interupt Flag
    MOVLW 0xC8
    MOVWF INTCON ;Reeneables Interrupts
    
    ;Load the W stuff
    MOVF STATS_SAVE,0
    MOVWF STATUS
    MOVF W_SAVE,0

    RETFIE
END ;End of code. This is required