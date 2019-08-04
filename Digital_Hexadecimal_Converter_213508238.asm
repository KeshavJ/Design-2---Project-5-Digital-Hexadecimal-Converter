;*******************************************************************************
;							                       *
;    Student Name	    : Keshav Jeewanlall			               *
;    Student Number	    : 213508238					       *
;    Description	    : Project 5 - 5.1. Digital Hexadecimal Converter   *
;									       *
;*******************************************************************************
    List p=16f690			
#include <p16F690.inc>		
errorlevel  -302		
    __CONFIG   _CP_OFF & _CPD_OFF & _BOR_OFF & _MCLRE_ON & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _FCMEN_OFF & _IESO_OFF 
  
    UDATA
temp1	          RES 1	    ;Temporary register used various purposes
tempW	          RES 1	    ;Used for contents saving when interrupt is triggered
disp_freq	  RES 1	    ;used as a delay variable to delay the display
count		  RES 1	    ;Used to store the count value
alarm_value1	  RES 1	    ;Contains the 1st count value for the alarm to sound
alarm_value2	  RES 1	    ;Contains the 2nd count value for the alarm to sound
alarm_value3	  RES 1	    ;Contains the 3rd count value for the alarm to sound
alarm_value4	  RES 1	    ;Contains the 4th count value for the alarm to sound
current_sec	  RES 1	    ;Stores the seconds that's read from the RTC
current_min	  RES 1	    ;Stores the minutes that's read from the RTC
current_hr	  RES 1	    ;Stores the hours that's read from the RTC
tens		  RES 1	    ;Stores the tens value that's displayed on the SSDs
units		  RES 1	    ;Stores the units value that's displayed on the SSDs
control_count	  RES 1	    ;used for controlling the starting and stopping of the count 
	    	    
RESET ORG 0x00		    ;Reset vector, PIC starts here on power up and reset
GOTO Setup
 ORG 0x04		    ;The PIC will come here on an interrupt
			    ;This is our interrupt routine that we want 
			    ;the PIC to do when it receives an interrupt
			    
;*******************************INTERRUPT ROUTINE*******************************	    
Count_Up_Interrupt
    MOVWF tempW		    ;temporarily stores value in W register when 
			    ;interrupt occurs
    CALL Ctrl_Start_Stop_Btn         
    BCF INTCON,1	    ;enable the interrupt again
    MOVFW tempW		    ;restore W register value from before the interrupt
    RETFIE		    ;This tells the PIC that the interrupt routine 
			    ;has finished and the PC will point back to the 
			    ;main program
			    
;***************************SETUP AND CONFIGURATION*****************************
Setup 
 			;select Bank 0
    BCF STATUS,5
    BCF STATUS,6
    CLRF PORTC		    ;Initialize PORTC
    CLRF PORTB		    ;Initialize PORTB
    CLRF PORTA		    ;Initialize PORTA
    
    BSF PORTA,2		    ;Used as input for start/stop button
    BSF PORTA,3		    ;Used as input for reset button
    BSF PORTA,0		    ;Used as input for switch mode button
    
    MOVLW b'00100000'
    MOVWF SSPCON	    ;Enable serial port pins, idle for clock is low, 
			    ;SPI master mode @ Fosc / 4
   

			;Select Bank 1
    BSF STATUS,5	
    
    CLRF TRISC		;set PORTC as output for ssds 
    BCF TRISA,5		;Set RA5 as output to decoder used for multiplexing
    BCF TRISA,4		;Set RA4 as output to decoder used for multiplexing
    BCF TRISB,7		;Set RB7 as output to decoder used for multiplexing
    
    BCF TRISA,1		;Set RA1 as output for buzzer
    BSF TRISB,4		;set RB4/SDI as input
    BCF TRISB,5		;set RB5 as output to control the RTC enable pin
    BCF TRISB,6		;set RB6/SCL as output
    
   MOVLW b'11000000'
   MOVWF SSPSTAT	;Input data sampled at end of CP,data transmitted on 
			;rising edge of CP

    BSF OSCCON,6
    BSF OSCCON,5
    BSF OSCCON,4	;Set Fosc at 8 MHz
    
    BCF OPTION_REG, 6
    BSF INTCON,7	;enable Global Interrupt
    BSF INTCON,4	;enable External Interrupt
    
			;select Bank 2
    BCF STATUS,5
    BSF STATUS,6
    
    
    
    CLRF ANSEL		;enable digital I/O on ports
    CLRF ANSELH
    
			;select Bank 0
    BCF STATUS,6
    
			;clear GPRs
    CLRF temp1
    CLRF disp_freq
    CLRF count
    CLRF alarm_value1
    CLRF alarm_value2
    CLRF alarm_value3
    CLRF alarm_value4
    CLRF control_count
    CLRF tempW

    GOTO Initialize_Loop

CODE  

;**********************************DISPLAY LOOP*********************************
 Initialize_Loop
    
    BSF PORTB,5
    MOVLW 0x8F
    MOVWF SSPBUF
    CALL RTC_wait
    MOVLW b'00000000'
    MOVWF SSPBUF	   ;New data to xmit
    CALL RTC_wait
    BCF PORTB,5
    
Display_Loop
    
   CALL Read_sec	    ;Reads the seconds register in the RTC
   CALL Read_min	    ;Reads the minutes register in the RTC
   CALL Read_hour	    ;Reads the hours register in the RTC
    
   BTFSS control_count,0    ;Is 24Hr mode enabled? If so, display the time of day
   CALL Display_Time
   BTFSC control_count,0    ;Else display binary to hexadecimal conversion
   CALL Display_Hex_Value
    
			    ;selects count mode
			    
    BTFSC control_count,2   ;If Count down mode enabled, count up
    CALL Count_Down
    BTFSC control_count,1   ;If Count up mode enabled, count up	
    CALL Count_Up
    
    GOTO Display_Loop
    
;*****CODE FOR DISPLAYING THE 4-DIGIT BINARY CODE AND THE HEXADECIMAL VALUE*****
    
Display_Hex_Value
;This subroutine is for displaying the 4-digit binary code and the hexadecimal value
    
    CALL Turn_off_SSDs
    MOVLW 0x40		    ;keeps tens Hex SSD at zero 
    CALL Turn_on_SSD_5
    MOVWF PORTC
    
    CALL Multiplex_Delay    ;delay for multiplexing SSDs
    CALL Update_Hex_Digit   ;update units Hex value SSD
    CALL Multiplex_Delay    ;delay for multiplexing SSDs
    CALL Update_Binary_4    ;Display binary bit 0
    CALL Multiplex_Delay    ;delay for multiplexing SSDs
    CALL Update_Binary_3    ;Display binary bit 1
    CALL Multiplex_Delay    ;delay for multiplexing SSDs
    CALL Update_Binary_2    ;Display binary bit 2
    CALL Multiplex_Delay    ;delay for multiplexing SSDs
    CALL Update_Binary_1    ;Display binary bit 3
    CALL Multiplex_Delay    ;delay for multiplexing SSDs
    
    INCFSZ disp_freq	    ;delay used for displaying count
    GOTO Display_Hex_Value
    
    RETURN

Update_Hex_Digit
;This subroutine updates and displays the required hexadecimal value on the SSD
    
    CALL Turn_off_SSDs	    ;subroutine to turn off SSDs
    MOVLW 0x0F
    ANDWF count,W	    ;Masks last 4 bits
    CALL SSD_HEX_Table	    ;get required value to be displayed from lookup table
    CALL Turn_on_SSD_6	    ;subroutine to turn on SSD 2
    MOVWF PORTC		    ;Moves value to PORTC
    RETURN
    
Update_Binary_1
;This subroutine checks if bit 0 of the count register is a 1 or 0 and displays
;the appropriate digit
    
    CALL Turn_off_SSDs	    ;subroutine to turn off SSDs
    MOVLW 0x0F
    ANDWF count,W	    ;Masks last 4 bits
    BTFSS count,3	    ;Test if bit is 1, if not display 0
    CALL Display_0	    ;subroutine to display 0
    BTFSC count,3	    ;Test if bit is 0, if not display 1
    CALL Display_1	    ;subroutine to display 1
    CALL Turn_on_SSD_1	    ;subroutine to turn on SSD 2
    RETURN
    
Update_Binary_2
;This subroutine checks if bit 1 of the count register is a 1 or 0 and displays
;the appropriate digit
    
    CALL Turn_off_SSDs	    ;subroutine to turn off SSDs
    MOVLW 0x0F
    ANDWF count,W	    ;Masks last 4 bits
    BTFSS count,2	    ;Test if bit is 1, if not display 0
    CALL Display_0	    ;subroutine to display 0
    BTFSC count,2	    ;Test if bit is 0, if not display 1
    CALL Display_1	    ;subroutine to display 1
    CALL Turn_on_SSD_2	    ;subroutine to turn on SSD 2
    RETURN
    
Update_Binary_3
;This subroutine checks if bit 2 of the count register is a 1 or 0 and displays
;the appropriate digit
    
    CALL Turn_off_SSDs	    ;subroutine to turn off SSDs
    MOVLW 0x0F
    ANDWF count,W	    ;Masks last 4 bits
    BTFSS count,1	    ;Test if bit is 1, if not display 0
    CALL Display_0	    ;subroutine to display 0
    BTFSC count,1	    ;Test if bit is 0, if not display 1
    CALL Display_1	    ;subroutine to display 1
    CALL Turn_on_SSD_3	    ;subroutine to turn on SSD 3
    RETURN
    
Update_Binary_4
;This subroutine checks if bit 3 of the count register is a 1 or 0 and displays
;the appropriate digit
    
    CALL Turn_off_SSDs	    ;subroutine to turn off SSDs
    MOVLW 0x0F
    ANDWF count,W	    ;Masks last 4 bits
    BTFSS count,0	    ;Test if bit is 1, if not display 0
    CALL Display_0	    ;subroutine to display 0
    BTFSC count,0	    ;Test if bit is 0, if not display 1
    CALL Display_1	    ;subroutine to display 1
    CALL Turn_on_SSD_4	    ;subroutine to turn on SSD 4
    RETURN
           
Display_0
;This subroutine displays a 0 on the SSD
    
    MOVLW 0x40		   
    MOVWF PORTC
    RETURN
    
 Display_1
 ;This subroutine displays a 1 on the SSD
 
    MOVLW 0x79		   
    MOVWF PORTC
    RETURN
   
Multiplex_Delay
;This subroutine is used as a delay for multiplexing the SSDs
    
    MOVLW 0x01
    MOVF temp1
Multiplex_loop
    DECFSZ temp1,1
    GOTO Multiplex_loop
    RETURN

;*************SSD LOOKUP TABLE TO DISPLAY VALUES ON COMMON ANODE SSDs***********
    
    SSD_HEX_Table
			  ;These HEX values are required because common anode SSDs
			  ;are being used
    ADDWF PCL,F
    RETLW 0x40		  ;displays number 0 on SSD
    RETLW 0x79		  ;displays number 1 on SSD    
    RETLW 0x24		  ;displays number 2 on SSD
    RETLW 0x30		  ;displays number 3 on SSD
    RETLW 0x19		  ;displays number 4 on SSD
    RETLW 0x12		  ;displays number 5 on SSD
    RETLW 0x02		  ;displays number 6 on SSD
    RETLW 0x78		  ;displays number 7 on SSD
    RETLW 0x00		  ;displays number 8 on SSD
    RETLW 0x18		  ;displays number 9 on SSD
    RETLW 0x08		  ;displays number A on SSD
    RETLW 0x03		  ;displays number b on SSD
    RETLW 0x46		  ;displays number C on SSD
    RETLW 0x21		  ;displays number d on SSD
    RETLW 0x06		  ;displays number E on SSD
    RETLW 0x0E		  ;displays number F on SSD
    
    
;*************************CODE FOR COUNTIN UP OR DOWN***************************
    
 Count_Up
 ;This is the subroutine for Counting up 
 
    CALL  Alarm		   ;Subroutine to sound the Alarm
    INCF count		   ;increases count by 1
    BTFSC count,5	   ;if bit 5 is set, count goes beyond 15, therefore 
			   ;reset to 0
    CLRF count 
    RETURN
 
 Count_Down		  
 ;This is the subroutine for Counting down 
 
    CALL  Alarm		    ;Subroutine to sound the Alarm
    DECF count,1	    ;decreases count by 1
    BTFSS count,7	    ;If -1 occurs, bit 7 will be set, reset count to 15
    GOTO No_Reset	    ;else skip
    MOVLW 0x0F
    MOVWF count
  No_Reset
    RETURN

;***********************CODE FOR CONTROLLING THE BUTTONS************************
     
Ctrl_Start_Stop_Btn
;This subroutine controls the starting and stopping of the count
    
    BSF control_count,0
    BTFSS PORTA,0	    ;Check if switch is up
    GOTO Start_Down_Count   ;If switch is down, Start a down count, else Start up count
    BTFSC PORTA,0
    GOTO Start_Up_Count

Start_Down_Count
    BTFSS control_count,2   ;If down already active, stop timer
    GOTO $+3
    BCF control_count,2	    ;Disable Down count
    RETURN    
    BCF control_count,1	    ;Disable Up
    BSF control_count,2	    ;Enable Down
    RETURN

Start_Up_Count    
    BTFSS control_count,1   ;If up already active, stop timer
    GOTO $+3
    BCF control_count,1	    ;Disable Up
    RETURN    
    BSF control_count,1	    ;Enable Up
    BCF control_count,2	    ;Disable Down  
    RETURN
    
;**************************CODE FOR SOUNDING THE ALARM**************************
    
Alarm
;This subroutine tests when to sound the alarm. The alarm is sounded when the 
;count is at the values of 1,2,3 and 15
    
    MOVLW 0x01
    MOVF alarm_value1
    CALL Check_Sound_2sec   ;if count is 1 sound for 2 seconds
    MOVLW 0x02
    MOVF alarm_value2
    CALL Check_Sound_2sec   ;if count is 2 sound for 2 seconds
    MOVLW 0x03
    MOVF alarm_value3
    CALL Check_Sound_5sec   ;if count is 3 sound for 5 seconds
    MOVLW 0x0F
    MOVF alarm_value4
    CALL Check_Sound_10sec  ;if count is 15 sound for 10 seconds
    RETURN
  
 Check_Sound_2sec
 ;This subroutine subracts the value of 1 or 2 from the current count value, 
 ;if a zero occurs then sound the alarm for 2 seconds
 
    BCF STATUS,2    ;clear bit 2 of STATUS register
    SUBWF count,0   ;subtracts value in WREG from current count value		
    BTFSS STATUS,2  ;if a zero occurs then bit 2 of STATUS register will be set
    RETURN
    
Sound_Buzzer_2sec
;This subroutine sounds the alarm for 2 seconds
     
    BSF PORTA,1
    CALL Display_Hex_Value  ;display count whilst sounding alarm
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    RETURN
    
Check_Sound_5sec			
;This subroutine subracts the value of 3 from the current count value, 
;if a zero occurs then sound the alarm for 5 seconds
 
    BCF STATUS,2    ;clear bit 2 of STATUS register
    SUBWF count,0   ;subtracts value in WREG from current count value	
    BTFSS STATUS,2  ;if a zero occurs then bit 2 of STATUS register will be set
    RETURN
    
Sound_Buzzer_5sec
;This subroutine sounds the alarm for 5 seconds
   
    BSF PORTA,1
    CALL Display_Hex_Value  ;display count whilst sounding alarm
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    RETURN
    
Check_Sound_10sec			
;This subroutine subracts the value of 15 from the current count value, 
;if a zero occurs then sound the alarm for 10 seconds
    
    BCF STATUS,2    ;clear bit 2 of STATUS register
    SUBWF count,0   ;subtracts value in WREG from current count value	
    BTFSS STATUS,2  ;if a zero occurs then bit 2 of STATUS register will be set
    RETURN
    
Sound_Buzzer_10sec
;This subroutine sounds the alarm for 10 seconds
    
    BSF PORTA,1
    CALL Display_Hex_Value  ;display count whilst sounding alarm
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    CALL Display_Hex_Value
    BSF PORTA,1
    CALL Display_Hex_Value
    BCF PORTA,1
    RETURN

;***********************CODE FOR READING THE TIME FROM THE RTC******************
Read_sec
    BCF SSPCON,7		;Clear the WCOL bit
    BSF PORTB,5			;Enable the RTC
    MOVLW 0x00
    MOVWF SSPBUF		;Tells the RTC that the seconds register is to be read
    CALL RTC_wait		;Wait for communication to end
    MOVLW 0x00			;'dummy' data sent. While sending, the required data will be received
    MOVWF SSPBUF
    CALL RTC_wait		;Wait for communication to end
    MOVFW SSPBUF		;Get data that was received
    BCF PORTB,5			;Disable the RTC
    MOVWF current_sec		;Store as current_sec
    RETURN

Read_min
    BCF SSPCON,7		;Clear the WCOL bit
    BSF PORTB,5			;Enable the RTC
    MOVLW 0x01
    MOVWF SSPBUF		;Tells the RTC that the minutes register is to be read
    CALL RTC_wait		;Wait for communication to end
    MOVLW 0x57		;'dummy' data sent. While sending, the required data will be received
    MOVWF SSPBUF
    CALL RTC_wait 		;Wait for communication to end   
    MOVFW SSPBUF		;Get data that was received
    BCF PORTB,5			;Disable the RTC
    MOVWF current_min		;Store as current_min
    RETURN
    
Read_hour
    BCF SSPCON,7		;Clear the WCOL bit
    BSF PORTB,5			;Enable the RTC
    MOVLW 0x02
    MOVWF SSPBUF		;Tells the RTC that the hours register is to be read
    CALL RTC_wait		;Wait for communication to end
    MOVLW 0x08			
    MOVWF SSPBUF		;'dummy' data sent. While sending, the required data will be received
    CALL RTC_wait    		;Wait for communication to end
    MOVFW SSPBUF		;Get data that was received
    BCF PORTB,5			;Disable the RTC
    ANDLW b'00111111'		;Remove the unwanted data from the register
    MOVWF current_hr		;Store as current_hr
    RETURN
    
;**********************CODE FOR DISPLAYING THE CURRENT TIME*********************

Display_sec
    CALL Convert_to_Tens_and_Units  ;Stores it to Tens
    CALL SSD_HEX_Table		    ;Gets code for displaying the tens value
    CALL Turn_on_SSD_5		    ;Turns on Seconds Tens SSD
    MOVWF PORTC			    ;Display Seconds Tens value
    CALL Multiplex_Delay	    ;Delay for multiplexing
    CALL Turn_off_SSDs		    ;Disable Seconds Tens SSD
    
    MOVFW units		    
    CALL SSD_HEX_Table		    ;Gets code for displaying the Units value
    CALL Turn_on_SSD_6		    ;Enable Seconds units SSD
    MOVWF PORTC			    ;Displays Seconds units value
    CALL Multiplex_Delay	    ;Delay for multiplexing
    CALL Turn_off_SSDs		    ;Disable Seconds units SSD
    RETURN

Display_min
    CALL Convert_to_Tens_and_Units  ;Stores it to Tens
    CALL SSD_HEX_Table		    ;Gets code for displaying the tens value
    CALL Turn_on_SSD_3		    ;Turns on Minutes Tens SSD
    MOVWF PORTC			    ;Display Minutes Tens value
    CALL Multiplex_Delay	    ;Delay for multiplexing
    CALL Turn_off_SSDs		    ;Disable Minutes Tens SSD
    
    MOVFW units		    
    CALL SSD_HEX_Table		    ;Gets code for displaying the Units value
    CALL Turn_on_SSD_4		    ;Enable Minutes units SSD
    MOVWF PORTC			    ;Displays Minutes units value
    CALL Multiplex_Delay	    ;Delay for multiplexing
    CALL Turn_off_SSDs		    ;Disable Minutes units SSD
    RETURN
    
 Display_hour
    CALL Convert_to_Tens_and_Units  ;Stores it to Tens
    CALL SSD_HEX_Table		    ;Gets code for displaying the tens value
    CALL Turn_on_SSD_1		    ;Turns on Hours Tens SSD
    MOVWF PORTC			    ;Display Hours Tens value
    CALL Multiplex_Delay	    ;Delay for multiplexing
    CALL Turn_off_SSDs		    ;Disable Hours Tens SSD
    
    MOVFW units		    
    CALL SSD_HEX_Table		    ;Gets code for displaying the Units value
    CALL Turn_on_SSD_2		    ;Enable Hours units SSD
    MOVWF PORTC			    ;Displays Hours units value
    CALL Multiplex_Delay	    ;Delay for multiplexing
    CALL Turn_off_SSDs		    ;Disable Hours units SSD
    RETURN
    
Display_Time
    MOVFW current_sec
    CALL Display_sec		    ;Displays current second
    MOVFW current_min
    CALL Display_min		    ;Displays current minute
    MOVFW current_hr
    CALL Display_hour		    ;Displays current hour
    RETURN
    
    
Convert_to_Tens_and_Units
;This subroutine splits the value into tens and units
    
    MOVWF tens
    ANDLW 0x0F		  ;b'00001111 , clears upper nibble of BCD number
    MOVWF units		  ;stores the value as the units
    SWAPF tens,1	  ;swaps the nibbles of the BCD number
    MOVFW tens		  
    ANDLW 0x0F		  ;b'00001111, clears the high nibble to get tens value
    MOVWF tens		  ;stores value in tens register
    RETURN
    
RTC_wait
    BANKSEL SSPSTAT;WRITE Address
    BTFSS SSPSTAT, BF ;Has data been received(transmit complete)?
    GOTO RTC_wait ;No
    BANKSEL 0x00
    RETURN

;*********************CODE FOR ENABLING AND DISABLING SSDs**********************
    
Turn_off_SSDs
;This subroutine turns off all SSDs
    
    BSF PORTA,5 ;A0
    BSF PORTB,7 ;A1
    BSF PORTA,4 ;A2
    RETURN

Turn_on_SSD_1
;This subroutine turns on SSD 1
    
    BCF PORTA,5	;A0
    BCF PORTB,7 ;A1
    BCF PORTA,4 ;A2
    RETURN
    
Turn_on_SSD_2
;This subroutine turns on SSD 2
    
    BSF PORTA,5	;A0
    BCF PORTB,7 ;A1
    BCF PORTA,4 ;A2
    RETURN
    
Turn_on_SSD_3
;This subroutine turns on SSD 3
    
    BCF PORTA,5	;A0
    BSF PORTB,7 ;A1
    BCF PORTA,4 ;A2
    RETURN
    
Turn_on_SSD_4
;This subroutine turns on SSD 4
    
    BSF PORTA,5	;A0
    BSF PORTB,7 ;A1
    BCF PORTA,4 ;A2
    RETURN
    
Turn_on_SSD_5
;This subroutine turns on SSD 5
    
    BCF PORTA,5	;A0
    BCF PORTB,7 ;A1
    BSF PORTA,4 ;A2
    RETURN

Turn_on_SSD_6
;This subroutine turns on SSD 6
    
    BSF PORTA,5 ;A0
    BCF PORTB,7 ;A1
    BSF PORTA,4 ;A2
    RETURN
    
END
    
    


