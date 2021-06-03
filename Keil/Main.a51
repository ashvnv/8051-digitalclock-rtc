//MIT License

//Copyright (c) 2021 ashvnv

//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:

//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.

//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

;24HR DIGITAL CLOCK USING 8051 AND RTC DS1307

;GitHub repo: https://github.com/ashvnv/8051-digitalclock-rtc

//------------------------------------------------------------

;REGISTERS USED:
;R1 -> ACCUMULATOR BACKUP
;R2 -> MICRO_DELAY FUNCTION
;R3 -> TEMPORARY STORAGE IN TIMESETMODE SUBROUTINE

;                                    MSB LSB
;R4 -> HOURS REGISTER    -----  0  x  X   X
;R5 -> MINUTES REGISTER  -----  0  x  X   X



;;;;R6 -> TIME SET REGISTER [COMMAND]
;         0x00: Normal Mode
;         0x01: MSB HOUR SET
;         0x02: LSB HOUR SET
;         0x03: MSB MINUTES SET
;         0x04: LSB MINUTES SET


;SUBROUTINE ADDRESSES
;(150H)SETTIMEMODE -> INT1 CALLS THIS ADDRESS FOR MANUALLY SETTING TIME
;(260H)DISPLAY -> 8051 DRIVING 7447 BCD TO 7SEG DISPLAY DECODER IN MULTIPLEX MODE
;(300H)UPDATETIME -> CALL TO UPDATE 8051 INTERNAL TIME REGISTERS R4 AND R5
;(2F0)MICRO_DELAY -> CALL A SMALL DELAY
;(400H)RTCTIMEUPDATE -> CALLED WHILE MANUALY UPDATING TIME IN RTC CHIP
;(510H)RSTART -> I2C RESTART CONDITION
;(520H)STARTC -> I2C START CONDITION
;(530H)STOP -> I2C STOP CONDITION
;(540H)SEND -> I2C SEND DATA
;(600H)ACK -> I2C ACKNOWLEDGEMENT (M TO S)
;(610H)NAK -> I2C N-ACKNOWLEDGEMENT (M TO S)
;(620H)RECV -> I2C RECEIVE DATA


;***************************************
;PORTS USED FOR I2C COMMUNICATION
;***************************************
SDA EQU P1.7
SCL EQU P1.6

;***************************************
;PORT PIN USED FOR SETTING TIME
TOGGLE EQU P3.4 ; SWITCH B
SETTIMELED EQU P3.5 ;LED TO INDICATE IF 8051 IS IN TIMESET MODE
	


ORG 0000H
LJMP START

//-----------------EX0 RTC INTERRUPT------------------------
ORG 0003H
	LCALL TIMEUPDATE
	RETI
//----------------------------------------------------------

//------------EX1 SETTIME INTERRUPT BY SWITCH A-------------
ORG 0013H
	LCALL SETTIMEMODE
	RETI
//----------------------------------------------------------

	
ORG 100H
	START: MOV R4, #00H ;HOURS DEFAULT 00H
	       MOV R5, #00H ;MINUTES DEFAULT 00H
		   MOV R6, #00H ;NORMAL MODE
		   
		   //-----------------1HZ SQ WAVE O/P CONFIGURE----------------------
		   
	       ;SEND START CONDITION
	       LCALL STARTC
		   
	       ;SEND SLAVE ADDRESS
	       MOV A,#11010000B ;I2C ID 1101000X WHERE X = 0 FOR WRITE OPERATION
	       LCALL SEND
	       ;SLAVE ACK SKIPPED STORED IN C
		   
           ;SEND DATA
	       MOV A, #00000111B ; SQUARE O/P REGISTER SELECT
	       LCALL SEND
	       MOV A, #10H ;INIT 1HZ SQUARE WAVE O/P
	       LCALL SEND
		   
	       LCALL STOP
		   
		   //------------8051 INTERRUPT SET----------------
		   MOV IE, #85H ;ENABLE INT0 AND INT1 INTERRUPT PRIORITY ONLY
		   MOV TCON, #05H ;ENABLE ENTERNAL INTERRUPT IN EDGE TRIGERRED MODE
		   //--------------------------------------------
		   
		   LJMP DISPLAY


ORG 150H
	SETTIMEMODE:
		    CJNE R6, #05H, OPTION ;CHECK WHICH MODE 8051 WAS OPERATING IN
		    
	;---------------------Return to normal mode-----------------------------
			MOV R6, #00H
			LCALL RTCTIMEUPDATE
            SETB EX0 ;ENABLE RTC INTERRUPTING 8051
		    SETB SETTIMELED ;DISABLE SET TIME INDICATOR
		    RET
	
	;-----------------------Time set Mode-----------------------------------
	OPTION: JNB TOGGLE, NEXTBIT ;IF SWTICH B IS ON, GO TO NEXT TIME BIT
	
	
	;---------------------------------------------------
	                 CJNE R6, #01H, SETHRLSB ;CHECK WHICH TIME BIT IS BEING SET
					 MOV A, R4 ;COPY CURRENT HOUR DATA IN R4
			         ANL A, #0F0H ;IGNORE LOWER NIBBLE
			         ADD A, #10H ;ADD 1 TO UPPER NIBBLE 
			         CJNE A, #30H, SKIPHRMSBRESET ;HOUR MSB CAN BE ONLY BETWEEN 0 - 2 [24HR CLOCK]
			         MOV A, #00H
 SKIPHRMSBRESET:     MOV R4, A
                     RET
 
 
    ;---------------------------------------------------
  SETHRLSB:          CJNE R6, #02H, SETMINMSB ;CHECK WHICH TIME BIT IS BEING SET
                     MOV A, R4
			         ANL A, #0F0H
			         MOV R3, A ;FOR BACKING UP THE HOUR MSB BIT SET ALREADY
			         MOV A, R4
			         ANL A, #0FH
			         INC A
					 CJNE R3, #20H, CHKFORHRMSB2 ;CHECK IS THE HOUR MSB IS 1 OR 2
			         CJNE A, #04H, SKIPHRLSBRESET ;IF HOUR MSB IS 2, HOUR LSB CAN BE BETWEEN 0 - 3
                     MOV A, #00H
                     JMP SKIPHRLSBRESET                     
					 
CHKFORHRMSB2:        CJNE A, #0AH, SKIPHRLSBRESET ;IF HOUR MSB IS 0 OR 1, HOUR LSB CAN BE BETWEEN 0 - 9
					 MOV A, #00H

SKIPHRLSBRESET:      ORL A, R3 
                     MOV R4, A
					 RET
			 
	;--------------------------------------------------
 SETMINMSB:          CJNE R6, #03H, SETMINLSB
                     MOV A, R5
					 ANL A, #0FH
					 MOV R3, A
					 MOV A, R5
			         ANL A, #0F0H
			         ADD A, #10H
			         CJNE A, #60H, SKIPMINMSBRESET ;IF MIN MSB CAN BE BETWEEN 0 - 5
			         MOV A, #00H
 SKIPMINMSBRESET:	 ORL A, R3
                     MOV R5, A
                     RET
			
		
    ;-------------------------------------------------		
 SETMINLSB:          CJNE R6, #04H, RETURNMINLSB
                     MOV A, R5
			         ANL A, #0F0H
			         MOV R3, A
			         MOV A, R5
			         ANL A, #0FH
			         INC A
			         CJNE A, #0AH, SKIPMINLSBRESET ;MIN LSB CAN BE BETWEEN 0 - 9
                     MOV A, #00H
SKIPMINLSBRESET:     ORL A, R3
                     MOV R5, A
             
			 
RETURNMINLSB:    RET
			
	        ;----------------------------
   NEXTBIT: INC R6 ; INCREMENT MODE [NORMAL MODE 00H, HOUR MSB 01H, HOUR LSB 02H, MIN MSB 03H, MIN LSB 04]
            ;WHEN R6 > 04H NEXT EX1 INTERRUPT MAKES R6 -> 00H AND 8051 COMES OUT OF TIME SET MODE
	        CLR EX0 ;DISABLE RTC INTERRUPTING 8051
			CLR SETTIMELED ;ENABLE SET TIME INDICATOR
			RET
	
	
ORG 260H
	DISPLAY:  
	          //-------HOUR----------
	          //---MSB---
    HOURMSB:  MOV A, R4
			  SWAP A
			  ANL A, #03H ; 0000 00XX
			  ORL A, #10H ; ENABLE ONLY HOUR MSB DISPLAY
			  MOV P2, A
			  LCALL MICRO_DELAY
			  
			  CJNE R6, #01H, HOURLSB ;IF IN TIME SET MODE, ONLY SHOW THE SETTING TIME ON 7SEG DISPLAY
			  SJMP DISPLAY
			 
			  //---LSB---
    HOURLSB:  MOV A, R4
			  ANL A, #0FH
			  ORL A, #20H ; ENABLE ONLY HOUR LSB DISPLAY
			  MOV P2, A
			  LCALL MICRO_DELAY
              
			  CJNE R6, #02H, MINMSB ;IF IN TIME SET MODE, ONLY SHOW THE SETTING TIME ON 7SEG DISPLAY
			  SJMP DISPLAY
			  
			  //-------MIN----------
			  //---MSB---
	 MINMSB:  MOV A, R5
			  SWAP A
			  ANL A, #0FH
			  ORL A, #40H ; ENABLE ONLY MIN MSB DISPLAY
			  MOV P2, A
			  LCALL MICRO_DELAY
			  
			  CJNE R6, #03H, MINLSB ;IF IN TIME SET MODE, ONLY SHOW THE SETTING TIME ON 7SEG DISPLAY
			  SJMP DISPLAY
			  
			  
			  //---LSB---
	 MINLSB:  MOV A, R5
			  ANL A, #0FH
			  ORL A, #80H ; ENABLE ONLY MIN LSB DISPLAY
			  MOV P2, A
			  LCALL MICRO_DELAY
			  
			  SJMP DISPLAY


ORG 2F0H ; 5US DELAY
MICRO_DELAY: MOV R2, #05H
    HERE:  DJNZ R2, HERE
	       RET


;*****************************************
; WRITE TO SLAVE DEVICE WITH SLAVE ADDRESS 1101000XB
;*****************************************
ORG 300H
	
	TIMEUPDATE:
	//---------------UPDATE TIME REGISTERS-----------------------------
		   //--------REGISTER POINTER INITIALIZE----------------
	       ; SEND START CONDITION
	       LCALL STARTC
		   
	       ; SEND SLAVE ADDRESS
	       MOV A,#11010000B ;I2C ID 1101000X WHERE X = 0 FOR WRITE OPERATION
	       LCALL SEND
		   MOV A, #01H ;INIT RTC POINTER TO MINUTES REGISTER
		   LCALL SEND
		   LCALL STOP
		   
		   //--------READ MIN AND HOURS DATA--------------------
	       ; SEND START CONDITION
	       LCALL STARTC
	       ; SEND SLAVE ADDRESS WITH READ BIT SET
	       MOV A,#11010001B ;I2C ID 1101000X WHERE X = 1 FOR READ OPERATION
	       LCALL SEND
	       ; READ ONE BYTE
	       LCALL RECV
		   MOV R5, A ;UPDATE MINUTES REGISTER
	       ; SEND ACK
	       LCALL ACK
	       ; READ LAST BYTE
	       LCALL RECV
		   MOV R4, A ;UPDATE MINUTES REGISTER
	      ; SEND NAK FOR LAST BYTE TO INDICATE
		  
	       ; END OF TRANSMISSION
	       LCALL NAK
	       ; SEND STOP CONDITION
	       LCALL STOP
		   
		   MOV A, R1 ;RESTORE ACCUMULATOR DATA
	RET
 
 
 ORG 400H
	 RTCTIMEUPDATE:
	       ;SEND START CONDITION
	       LCALL STARTC
		   
	       ;SEND SLAVE ADDRESS
	       MOV A,#11010000B ;I2C ID 1101000X WHERE X = 0 FOR WRITE OPERATION
	       LCALL SEND
	       ;SLAVE ACK SKIPPED STORED IN C
		   
           ;SEND DATA
	       MOV A, #00000000B ; SECONDS REGISTER SELECT
	       LCALL SEND
	       MOV A, #00H ; MAKE SECONDS REGISTER 00
	       LCALL SEND
		   MOV A, R5 ;UPDATE RTC MINUTES REGISTER
		   LCALL SEND
		   MOV A, R4 ;UPDATE RTC HOURS REGISTER
		   ORL A, #80H ;SET 24 HR BIT IN RTC FOR 24 HR OPERATION MODE
		   LCALL SEND
		   
	       LCALL STOP
		   
		   RET
 
;****************************************
;RESTART CONDITION FOR I2C COMMUNICATION | [NOT USED]
;****************************************

ORG 510H
RSTART:
	CLR SCL
	SETB SDA
	SETB SCL
	CLR SDA
	RET
 
 
;****************************************
;START CONDITION FOR I2C COMMUNICATION
;****************************************

ORG 520H
STARTC:
	SETB SCL
	CLR SDA
	CLR SCL
	RET
 
 
;*****************************************
;STOP CONDITION FOR I2C BUS
;*****************************************

ORG 530H
STOP:
	CLR SCL
	CLR SDA
	SETB SCL
	SETB SDA
	RET
 
 
;*****************************************
;SENDING DATA TO SLAVE ON I2C BUS
;*****************************************

ORG 540H
SEND:
    MOV R1, A ;BACKUP ACCUMULATOR DATA
	
	MOV R7,#08
BACK:
	CLR SCL
	RLC A
	MOV SDA,C
	SETB SCL
	DJNZ R7,BACK
	CLR SCL
	SETB SDA
	SETB SCL
	MOV C, SDA
	CLR SCL
	
	MOV A, R1 ;RESTORE ACCUMULATOR DATA
	
	RET
 
 
;*****************************************
;ACK AND NAK FOR I2C BUS
;*****************************************

ORG 600H
ACK:
	CLR SDA
	SETB SCL
	CLR SCL
	SETB SDA
	RET
 
ORG 610H
NAK:
	SETB SDA
	SETB SCL
	CLR SCL
	SETB SCL
	RET
 
 
;*****************************************
;RECEIVING DATA FROM SLAVE ON I2C BUS
;*****************************************

ORG 620H
RECV: MOV R1, A ;BACKUP ACCUMULATOR DATA, RESTORED AT THE END OF TIMEUPDATE CALL SUBROUTINE

	MOV R7,#08
BACK2:
	CLR SCL
	SETB SCL
	MOV C,SDA
	RLC A
	DJNZ R7,BACK2
	CLR SCL
	SETB SDA
	
	RET
	
	
END
