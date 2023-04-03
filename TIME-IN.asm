NAME "PRINTER" 
   
DATA SEGMENT
    
     SCAN_MSG DB 'SCAN YOUR TEMPERATURE'
     TAP_MSG DB 'TAP YOUR CARD'       
     CLEARASCII DB "                                                                "
     NUMBERS	DB 00111111B, 00000110B, 01011011B, 01001111B, 01100110B, 01101101B, 01111101B, 00000111B, 01111111B, 01101111B,
                DB 01110111B, 01111100B, 00111001B, 01011110B, 01111001B, 01110001B       
     ID DB "0000000_IN.txt",0      
     FILEHANDLER DW ?  
     HANDLE DW ?                      ;CREATES VARIABLE TO STORE FILE HANDLE WHICH IDENTIFIES THE FILE              
     TIME_IN DB "TIME IN: "           ;CREATES TEXT TO WRITE ON FILE
     MSG  DB "MAGANDANG ARAW!", 0AH, 0DH
     DB "ANG IYONG ANAK AY LIGTAS NANG NAKARATING SA ", 0AH, 0DH      
     DB "TECHNOLOGICAL UNIVERSITY OF THE PHILIPPINES - MANILA", 0AH, 0DH                                
     DB "MARAMING SALAMAT", 0AH, 0DH
     DB 13, 9                         ;CARRIAGE RETURN AND VERTICAL TAB  
     SDATE  DB "DATE:" 
     DATE DB "00\00\00", 0 
     SPACE DB " ", 0AH, 0DH 
     PROMPT  DB "TIME:" 
     TIME DB "00:00:00", 0
     MSG_END DB 0      
ENDS

STACK SEGMENT
    DW   128  DUP(0)
ENDS

CODE SEGMENT 
    
CHECK_TEMP   PROC    FAR    ;CHECK TEMPERATURE 
 	PUSH    DS              ;STORE RETURN ADDRESS TO OS:
 	MOV     AX, 0
 	PUSH    AX

 	MOV     AX, DATA        ;SET SEGMENT REGISTERS:
 	MOV     DS, AX
 	MOV     ES, AX
    

SCAN_INIT:                   ;INIT ASCII
	MOV DX, 2040h	 
	MOV SI, 0
	MOV CX, 21

DISP_SCAN:                   ;DISPLAY TAP MESSAGE
	MOV AL, SCAN_MSG[SI]
	OUT DX,AL
	INC SI
	INC DX
	LOOP DISP_SCAN
    
	MOV CX, 8	            ;INITIALIZE ALL SEVEN SEGMENT DISPLAYS TO EMPTY
	MOV DX, 2030H
	MOV AL, 00H   
	
INIT:	                    ;INITIALIZE THERMOMETER
    OUT DX, AL
	INC DX
	LOOP INIT
	
THERMOMETER:	
	MOV DX, 2086H	        ;READ TEMPERATURE (8-BIT INPUT)
	IN  AL, DX	
	
	MOV BL, AL	            ;BX NOW HAS THE TEMPERATURE
	MOV BH, 0
	
	MOV DX, 2030H 	        ;DISPLAY TEMPERATURE ON SEVEN SEGMENT (USING HEXADECIMAL) & OUTPUT MOST SIGNIFICANT 4-BITS
	MOV SI, BX
	AND SI, 00F0H
	MOV CL, 4
	ROR SI, CL
	MOV AL, NUMBERS[SI]
	OUT DX, AL

	MOV DX, 2031H 	        ;OUTPUT LEAST SIGNIFICANT 4-BITS
	MOV SI, BX
	AND SI, 000FH
	MOV AL, NUMBERS[SI]
	OUT DX, AL
	
	MOV DX, 2032H	        ;OUTPUT 'H' INDICATING HEXADECIMAL KEY
	MOV AL, 01110100B
	OUT DX, AL  	 
	
	MOV DX, 2070H
    MOV CX, 7 
	
	CMP BX, 04BH            ;HEX FOR 35
	JL THERMOMETER    
	CALL CLEARDISPLAY1
	CALL CLEARDISPLAY2
    CMP BX, 04EH            ;HEX FOR 38
    JL GREEN
    JMP RED
    
RED:                        ;OUTPUT ALL RED COLOR
	MOV AL, 049H 
    OUT DX, AL 
    JMP EXIT
    
GREEN:                      ;OUTPUT ALL GREEN COLOR
    MOV AL, 024H 
    OUT DX, AL     	
	JMP TAP_INIT            ;INFINIT LOOP 
	
CHECK_TEMP  ENDP

TAP_INIT:                   ;INIT ASCII
	MOV DX, 2040h	 
	MOV SI, 0
	MOV CX, 13

DISP_TAP:                   ;DISPLAY TAP MESSAGE
	MOV AL, TAP_MSG[SI]
	OUT DX,AL
	INC SI
	INC DX
	LOOP DISP_TAP

GET_ID:                     ;GET INPUT USING KEYBOARD         
    MOV AX, @DATA           ;STORAGE NG DATA SEGMENT
    MOV DS,AX
    LEA BX, ID              ;LOAD ADDRESS NG ID
    MOV CX, 6   
      
	MOV DX, 2083H           ;RESET BUFFER INDICATOR TO ALLOW MORE KEYS
	MOV AL, 00H
	OUT DX, AL
	   
	CALL KEYBOARD           ;MAIN  
	mov  dx, offset ID 
    call OPEN_FILE
	CALL CLEARDISPLAY1
	CALL CLEARDISPLAY2
	CALL DISPLAY_TIME 
    CALL GET_DATE
    CALL WRITE_FILE
	CALL INIT_DATE   
	CALL DISP_GATE
	CALL START_PRINT
	CALL EXIT  
	
KEYBOARD:                                                                                        
    MOV DX, 2083h 	        ;INPUT DATA FROM KEYBOARD (IF BUFFER HAS KEY)
	IN  AL, DX    
	CMP AL, 00h
	JE  KEYBOARD      	    ;BUFFER HAS NO KEY, CHECK AGAIN 
	                        
	MOV DX, 2082h	        ;READ KEY (8-BIT INPUT)
	IN  AL, DX	

	AAM                     ;ASCII adjust after manipulation- divides AL by 10 and stores quotient to AH, Remainder to AL
    ADD AX, 3030h           ;ADDS 3030H TO AX PARA MAGING ASCIIANG HEXADECIMAL

    MOV [BX], AX 
    INC BX 
    
	MOV DX, 2083h           ;RESET BUFFER INDICATOR TO ALLOW MORE KEYS
	MOV AL, 00h
	OUT DX, AL
	
    LOOP KEYBOARD
    
    MOV DX, 2070H           ;RESET LEDS OUTPUT
    MOV AL, 00H
    OUT DX, AL
    CALL CLEARDISPLAY1
	CALL CLEARDISPLAY2
  
    MOV DX,2040H            ;ASCII LCD
    MOV SI,0
    MOV CX,6

DISPLAY_ID:                 
    MOV AL, ID[SI]           ;print yung nasa string by their index 
    OUT DX, AL
    INC SI
    INC DX 
    LOOP DISPLAY_ID 
    RET 
    
OPEN_FILE:
    PUSH AX
    PUSH BX    
    CMP CL, 21d        
    JE  CHECK_STATUS

CHECK_STATUS:               ;CHECH STATUS OF FILE   
    MOV AL, 0                ;READ ONLY MODE.
    MOV AH, 03dh             ;SERVICE TO OPEN FILE.
    INT 21h
    JB  NOTOK               ;ERROR IF CARRY FLAG.
    JE OK

OK:                         ;DISPLAY GREEN COLOR IN LED
    MOV filehandler, AX     ;IF NO ERROR, NO JUMP. SAVE FILEHANDLER.  
    MOV DX, 2070H           ;GREEN LIGHT 
    MOV AL, 024H 
    OUT DX, AL                       
    JMP endOfFile
    
NOTOK:                      ;DISPLAY RED COLOR IN LED       
    MOV DX, 2070H           ;RED LIGHT
    MOV AL, 049H 
    OUT DX, AL
    
    CALL CLEARDISPLAY1
	CALL CLEARDISPLAY2
    CALL EXIT

endOfFile:                  
    pop bx
    pop ax
    RET
    	
CLEARDISPLAY1:              
	MOV DX, 2039H
	MOV SI, 0
	MOV CX, 55
	RET

CLEARDISPLAY2:
	MOV AL, CLEARASCII[SI]
	OUT DX,AL
	INC SI
	INC DX 
	LOOP CLEARDISPLAY2
	RET

EXIT:   

    MOV AH, 4CH
    INT 21H 
    
DISPLAY_TIME PROC           ;FUNCTION FOR TIME    
     MOV AX, @DATA          ;STORAGE NG DATA SEGMENT
     MOV DS, AX
     LEA BX, TIME           ;PRINT YUNG STRING TIME 
                      
     CALL GET_TIME          ;GET TIME 
     CALL ASCII             ;DISPLAY IN ASCII LCD                           
     RET
     
DISPLAY_TIME ENDP 

GET_TIME PROC               ;GET TIME                         
    PUSH AX                      
    PUSH CX
                           
    MOV AH, 2CH                      
    INT 21H
                         
    MOV AL, CH              ;HOUR                 
    CALL CONVERT                  
    MOV [BX], AX            ;ADD YUNG VALUE NG HOUR SA INDEX 0 AT 1
                      
    MOV AL, CL              ;MINUTE                    
    CALL CONVERT                      
    MOV [BX + 3], AX        ;ADD YUNG VALUE NG MINUTE SA INDEX 3AT 4
                                                             
    MOV AL, DH              ;SECONDS                
    CALL CONVERT                   
    MOV [BX + 6], AX        ;ADD YUNG VALUE NG MINUTE SA INDEX 6 AT 7
                                                                       
    POP CX                        
    POP AX                        
    RET
                               
GET_TIME ENDP 

ASCII PROC                  ;FUNCTION FOR ASCII LCD 
    MOV DX,2040H
    MOV SI,0
    MOV CX,14
    
LOOPHERE:    
    MOV AL, PROMPT[SI]      ;PRINT YUNG NASA STRING BY THEIR INDEX 
    OUT DX, AL
    INC SI
    INC DX
     
    LOOP LOOPHERE
    RET

ASCII ENDP

CONVERT PROC                ;CONVERTION TO STRING
    PUSH DX                      
    MOV AH, 0                     
    MOV DL, 10                   
    DIV DL                        
    OR AX, 3030H                  
    POP DX                        
    RET

CONVERT ENDP  
   
GET_DATE:                   ;FUNCTION FOR DATE 
    TAB EQU 9               ;ASCII CODE  
    MOV AX, @DATA           ;STORAGE NG DATA SEGMENT
    MOV DS, AX
    LEA BX, DATE            ;PRINT YUNG STRING TIME  
    MOV AH, 2AH             ;HEXADECIMAL TO GET THE SYSTEM DATE
    INT 21H                 ;EXECUTES
    PUSH DX                 ;STORE DX TO STACK 
    
    MOV AL, DH              ;MONTH | COPY DH TO AL (SINCE DH CONTAINS THE MONTH AND AL IS THE REGISTER FOR ARITHMETIC) 
    CALL CONVERT_DATE
    MOV [BX], AX 
    
    POP DX                  ;DAY | RETRIEVE DX FROM STACK (DL CONTAINS DAY)
    MOV AL, DL          
    CALL CONVERT_DATE
    MOV [BX+3], AX
                   
    SUB CX, 2000            ;YEAR | SUBTRACT 2000 TO CX SINCE IT CNA ONLY STORE TO DIGIT
    MOV AX, CX         
    CALL CONVERT_DATE
    MOV [BX+6], AX
    MOV DX, 2055H
	MOV SI, 0
	MOV CX, 8 
    RET
    
CONVERT_DATE:               ;FUNCTION TO CONVERT HEXADECIMAL TO ASCII    
    AAM                     ;ASCII ADJUST AFTER MANIPULATION- DIVIDES AL BY 10 AND STORES QUOTIENT TO AH, REMAINDER TO AL
    ADD AX, 3030H           ;ADDS 3030H TO AX PARA MAGING ASCIIANG HEXADECIMAL
    PUSH BX                    
    MOV BX, AX              ;COPY ANG AX SA BX KASI MABABAGO ANG VALUE NG AX DAHIL SA PRINTING                              
    MOV AL, BH              ;INTERCHANGE VALUES
    MOV AH, BL
    POP BX   
    RET  

INIT_DATE:                  ;INITIALIZE ASCII LCD
	MOV DX, 2050H
	MOV SI, 0
	MOV CX, 14              ;SINCE 14 ANG CX, PATI KUNG ANO YUNG NASA BABA NG SDATE NAPI-PRINT NIYA, WHICH IS YUNG MISMONG DATE.

DISPLAY_DATE:           
	MOV AL, SDATE[SI]
	OUT DX,AL
	INC SI
	INC DX 
	LOOP DISPLAY_DATE
	RET  

WRITE_FILE:                 ;FUNCTION FOR FILE OPERATION
    MOV AX, CS
    MOV DX, AX
    MOV ES, AX
     
    MOV AH, 3ch             ;create file
    MOV CX, 0
    MOV DX, OFFSET ID       ;get offset address
    INT 21H
    MOV handle, AX   
    
    MOV AH, 40h             ;write on file
    MOV BX, handle
    MOV DX, OFFSET SDATE    ;PRINT "DATE" STRING
    MOV CX, 5
    INT 21h  
    
    MOV AH, 40h             
    MOV BX, handle
    MOV DX, OFFSET DATE     ;DISPLAY DATE
    MOV CX, 8
    INT 21h
    
    MOV AH, 40h           
    MOV BX, handle
    MOV DX, OFFSET TIME_IN  ;PRINT "TIME IN"
    MOV CX, 9
    INT 21h  
    
    MOV AH, 40h          
    MOV BX, handle
    MOV DX, offset TIME     ;PRINT TIME
    MOV CX, 8
    INT 21h
    
    MOV AH, 3eh             ;CLOSE
    MOV BX, handle
    INT 21h 
    RET         

DISP_GATE PROC    

DISP_GATE  ENDP             ;DISPLAY GATE NUMBER
    
    MOV AX, GREETINGS     
    MOV DS, AX
      
    MOV AL, 00h             ;CLEAR PUSH BUTTON 
	MOV DX, 2080h
	OUT DX, AL	

INPUT:
	MOV DX, 2080h           ;input data from switches
	IN  AX, DX              ;16-bit input  
 
	MOV DX, 2000h
	MOV BX, 00h	 
	
	CMP AX, 02h           
	JE GATE1LOOP
	CMP ax, 04h   
	JE GATE2LOOP
	CMP ax, 08h
	JE GATE3LOOP
	JNE INPUT 
    
GATE1LOOP:                  ;FUNCTION FOR GATE 1    
	MOV SI, 0

GATE01:
	MOV AL, Gate1[BX][SI]
	OUT DX, AL
	INC SI
	INC DX
         
	CMP SI, 5
	LOOPNE GATE01

	ADD BX, 5
	CMP BX, 40
	JL GATE1LOOP
	JE DOTC 
		
GATE2LOOP:                  ;FUNCTION FOR GATE 2
	MOV SI, 0
	
GATE02:
	MOV AL,Gate2[BX][SI]
	OUT DX, AL
	INC SI
	INC DX

	CMP SI, 5
	LOOPNE GATE02

	ADD BX, 5
	CMP BX, 40
	JL GATE2LOOP
	JE DOTC 
	
GATE3LOOP:                  ;FUNCTION FOR GATE 3
	MOV SI, 0
	
GATE03:
	MOV AL,Gate3[BX][SI]
	out dx,al
	INC SI
	INC DX

	CMP SI, 5
	LOOPNE GATE03

	ADD BX, 5
	CMP BX, 40
	JL GATE3LOOP 
	JE DOTC
	
DOTC:                      ;CLEAR FUNCTION FOR DOT MATRIX	
    MOV DX, 2000h
	MOV BX, 00h    
 
CLEARLOOP: 

	MOV SI, 0
	
CLDISPLAY:
    
	MOV AL,00h
	OUT DX, AL
	INC SI
	INC DX

	CMP SI, 5
	LOOPNE CLDISPLAY

	ADD BX, 5
	CMP BX, 40 
	JL CLEARLOOP

DOTW:	                   ;INIT DOT MATRIX
    MOV DX, 2000h
	MOV BX, 00h
    
WELLOOP:                   ;FUNCTION FOR WELCOME DISPLAY
	MOV SI, 0
  	
WELDISPLAY:
	MOV AL,Welcome[BX][SI]
	OUT DX, AL
	INC SI
	INC DX

	CMP SI, 5
	LOOPNE WELDISPLAY

	ADD BX, 5
	CMP BX, 40
	JL WELLOOP
	
    RET
	
START_PRINT:                ;FUNCTION FOR PRINTER  
    
    MOV AX, DATA     
    MOV DS, AX
    MOV DL, 12              ;FORM FEED CODE. NEW PAGE.
    MOV AH, 5
    INT 21H

    MOV SI, OFFSET MSG
    MOV CX, OFFSET MSG_END - OFFSET MSG

PRINT:
    MOV DL, [SI]
    MOV AH, 5               ;MS-DOS PRINT FUNCTION.
    INT 21H
    INC SI	                ;NEXT CHAR.
    LOOP PRINT
     
    MOV DL, 12              ;FORM FEED CODE. PAGE OUT!
    MOV AH, 5
    INT 21H 
    RET	  

GREETINGS SEGMENT
    
Welcome DB 01111111b, 00100000b, 00011000b, 00100000b, 01111111b; w
        DB 01111111b, 01001001b, 01001001b, 01001001b, 01000001b; E
        DB 01111111b, 01000000b, 01000000b, 01000000b, 01000000b; L
        DB 00111110b, 01000001b, 01000001b, 01000001b, 00100010b; C
        DB 00111110b, 01000001b, 01000001b, 01000001b, 00111110b; O
        DB 01111111b, 00000010b, 00001100b, 00000010b, 01111111b; M
        DB 01111111b, 01001001b, 01001001b, 01001001b, 01000001b; E
        DB 00000000B, 01011111B, 00000000B, 01011111B, 00000000B; !!  
        
          ;1          2          3          4          5
Gate1   DB 00000000b, 00000000b, 00000000b, 00000000b, 00000000b
        DB 00111110b, 01000001b, 01001001b, 01001001b, 01111010b; G
        DB 01111110b, 00010001b, 00010001b, 00010001b, 01111110b; A
        DB 00000001b, 00000001b, 01111111b, 00000001b, 00000001b; T
        DB 01111111b, 01001001b, 01001001b, 01001001b, 01000001b; E
        DB 00000000b, 00000000b, 00000000b, 00000000b, 00000000b
        DB 01000100b, 01000010b, 01111111b, 01000000b, 01000000b; 1
        DB 00000000b, 00000000b, 00000000b, 00000000b, 00000000b
                                                                 
Gate2   DB 00000000b, 00000000b, 00000000b, 00000000b, 00000000b
        DB 00111110b, 01000001b, 01001001b, 01001001b, 01111010b; G
        DB 01111110b, 00010001b, 00010001b, 00010001b, 01111110b; A
        DB 00000001b, 00000001b, 01111111b, 00000001b, 00000001b; T
        DB 01111111b, 01001001b, 01001001b, 01001001b, 01000001b; E
        DB 00000000b, 00000000b, 00000000b, 00000000b, 00000000b
        DB 01000010b, 01100001b, 01010001b, 01001001b, 01000110b; 1
        DB 00000000b, 00000000b, 00000000b, 00000000b, 00000000b
        
Gate3   DB 00000000b, 00000000b, 00000000b, 00000000b, 00000000b
        DB 00111110b, 01000001b, 01001001b, 01001001b, 01111010b; G
        DB 01111110b, 00010001b, 00010001b, 00010001b, 01111110b; A
        DB 00000001b, 00000001b, 01111111b, 00000001b, 00000001b; T
        DB 01111111b, 01001001b, 01001001b, 01001001b, 01000001b; E
        DB 00000000b, 00000000b, 00000000b, 00000000b, 00000000b
        DB 00100010b, 01001001b, 01001001b, 01001001b, 00110110b; 1
        DB 00000000b, 00000000b, 00000000b, 00000000b, 00000000b
          ;1234567  
    ENDS    
ENDS