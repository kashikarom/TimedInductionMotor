
; You may customize this and other start-up templates; 
; The location of this template is c:\emu8086\inc\0_com_template.txt

#start=stepper_motor.exe#

PUTC    MACRO   char
        PUSH    AX
        MOV     AL, char
        MOV     AH, 0Eh
        INT     10h     
        POP     AX
ENDM

org 100h

jmp start


; define variables:

msg0 db "TIMER FROM CURRENT TIME.",0Dh,0Ah
     db "works in 24 hr format ",0Dh,0Ah,'$'
msg1 db 0Dh,0Ah, 0Dh,0Ah, 'enter minutes : $'
msg2 db 0Dh,0Ah, 0Dh,0Ah, 'enter hours : $'
msg3 db 0Dh,0Ah, 0Dh,0Ah, 'enter Duration : $'
msg4 db 0Dh,0Ah, 0Dh,0Ah, 'current time : $'
; first and second number:
minn db ?
hrr db ?
ti db ?

; bin data for clock-wise
; half-step rotation:
datcw    db 0000_0110b
         db 0000_0100b    
         db 0000_0011b
         db 0000_0010b

stpcw    db 0000_0000b
         db 0000_0000b    
         db 0000_0000b
         db 0000_0000b

start: 

mov dx, offset msg0
mov ah, 9
int 21h


lea dx, msg1
mov ah, 09h    ; output string at ds:dx
int 21h  

call scan_num

mov minn, cl 

putc 0Dh
putc 0Ah




lea dx, msg2
mov ah, 09h    ; output string at ds:dx
int 21h  

call scan_num

mov hrr, cl 

; new line:
putc 0Dh
putc 0Ah




lea dx, msg3
mov ah, 09h    ; output string at ds:dx
int 21h  

call scan_num

mov ti, cl 

; new line:
putc 0Dh
putc 0Ah 



ct:

MOV AH,2CH    	 	; TO GET SYSTEM TIME
INT 21H
cmp hrr, CH     	 	; CH -> HOUR
jne ct

cmp minn, CL         ; CL -> MIN
je on

jmp ct



on:    


lea dx, msg4
mov ah, 09h    ; output string at ds:dx
int 21h  

mov al, hrr
call print_al

mov ah, 2
mov dl, ':'
int 21h
	
mov al, minn 
call print_al

mov al, minn
add al, ti
mov ti, al

mov bx, offset datcw ; on

next_step:

MOV AH,2CH    	 	; TO GET SYSTEM TIME
INT 21H
cmp ti, CL    	 	; CL -> MINS
je off
  

; set data segment to code segment:
mov ax, cs
mov ds, ax
 

; motor sets top bit when it's ready to accept new command
wait:   in al, 7     
        test al, 10000000b
        jz wait

mov al, [bx][si]

out 7, al

inc si

cmp si, 4
jb next_step
mov si, 0

jmp next_step


off: 

; new line:
putc 0Dh
putc 0Ah   

lea dx, msg4
mov ah, 09h    ; output string at ds:dx
int 21h  

mov al, hrr
call print_al

mov ah, 2
mov dl, ':'
int 21h
	
mov al, ti 
call print_al

mov bx, offset stpcw ; stop

next_step1:  

; set data segment to code segment:
mov ax, cs
mov ds, ax


; motor sets top bit when it's ready to accept new command
wait1:   in al, 7     
        test al, 10000000b
        jz wait1

mov al, [bx][si]

out 7, al

inc si

cmp si, 4
jb next_step1
mov si, 0

jmp next_step1       
         
ret




SCAN_NUM        PROC    NEAR
        PUSH    DX
        PUSH    AX
        PUSH    SI
        
        MOV     CX, 0

        ; reset flag:
        MOV     CS:make_minus, 0

next_digit:

        ; get char from keyboard
        ; into AL:
        MOV     AH, 00h
        INT     16h
        ; and print it:
        MOV     AH, 0Eh
        INT     10h

        ; check for MINUS:
        CMP     AL, '-'
        JE      set_minus

        ; check for ENTER key:
        CMP     AL, 0Dh  ; carriage return?
        JNE     not_cr
        JMP     stop_input
not_cr:


        CMP     AL, 8                   ; 'BACKSPACE' pressed?
        JNE     backspace_checked
        MOV     DX, 0                   ; remove last digit by
        MOV     AX, CX                  ; division:
        DIV     CS:ten                  ; AX = DX:AX / 10 (DX-rem).
        MOV     CX, AX
        PUTC    ' '                     ; clear position.
        PUTC    8                       ; backspace again.
        JMP     next_digit
backspace_checked:


        ; allow only digits:
        CMP     AL, '0'
        JAE     ok_AE_0
        JMP     remove_not_digit
ok_AE_0:        
        CMP     AL, '9'
        JBE     ok_digit
remove_not_digit:       
        PUTC    8       ; backspace.
        PUTC    ' '     ; clear last entered not digit.
        PUTC    8       ; backspace again.        
        JMP     next_digit ; wait for next input.       
ok_digit:


        ; multiply CX by 10 (first time the result is zero)
        PUSH    AX
        MOV     AX, CX
        MUL     CS:ten                  ; DX:AX = AX*10
        MOV     CX, AX
        POP     AX

        ; check if the number is too big
        ; (result should be 16 bits)
        CMP     DX, 0
        JNE     too_big

        ; convert from ASCII code:
        SUB     AL, 30h

        ; add AL to CX:
        MOV     AH, 0
        MOV     DX, CX      ; backup, in case the result will be too big.
        ADD     CX, AX
        JC      too_big2    ; jump if the number is too big.

        JMP     next_digit

set_minus:
        MOV     CS:make_minus, 1
        JMP     next_digit

too_big2:
        MOV     CX, DX      ; restore the backuped value before add.
        MOV     DX, 0       ; DX was zero before backup!
too_big:
        MOV     AX, CX
        DIV     CS:ten  ; reverse last DX:AX = AX*10, make AX = DX:AX / 10
        MOV     CX, AX
        PUTC    8       ; backspace.
        PUTC    ' '     ; clear last entered digit.
        PUTC    8       ; backspace again.        
        JMP     next_digit ; wait for Enter/Backspace.
        
        
stop_input:
        ; check flag:
        CMP     CS:make_minus, 0
        JE      not_minus
        NEG     CX
not_minus:

        POP     SI
        POP     AX
        POP     DX
        RET
make_minus      DB      ?       ; used as a flag.
SCAN_NUM        ENDP

ten             DW      10      ; used as multiplier/divider by SCAN_NUM & PRINT_NUM_UNS.

print_al proc
cmp al, 0
jne print_al_r
    push ax
    mov al, '0'
    mov ah, 0eh
    int 10h
    pop ax
    ret 
print_al_r:    
    pusha
    mov ah, 0
    cmp ax, 0
    je pn_done
    mov dl, 10
    div dl    
    call print_al_r
    mov al, ah
    add al, 30h
    mov ah, 0eh
    int 10h    
    jmp pn_done
pn_done:
    popa  
    ret  
endp