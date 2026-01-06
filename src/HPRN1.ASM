; Parallel port gpib driver
;

        .MODEL SMALL
        .CODE

st1:    jmp start

jvec17  LABEL dword
vec17o   dw ?
vec17s   dw ?

ioprt   dw 0378h


printerio:
        cmp dx,00h
        jz  doit
        jmp [jvec17]   ; goto old printer driver

doit:   sti
                  ; proper interupt handler
        push ds
        push si
        push dx
        push cx
        push bx

;        push ax
;        push cx
;        mov al,ah
;        add al,30h
;        mov ah,0Ah
;        mov cx,0002h
;        int 10h
;        pop cx
;        pop ax


        or ah,ah         ; test for AH = 00
        jz printchar     ; print char in AL
        dec ah
        or ah,ah         ; test for AH = 01
        jz init          ; initialize interface and printer
        dec ah
        or ah,ah         ; test for AH = 02
        jz stat          ; get printer status

ret1:   pop bx
        pop cx
        pop dx
        pop si
        pop ds
        iret



init:   ; initialize printer

        mov dx,cs:[ioprt]
        mov al,00h
        out dx,al  ; data to $ff

        inc dx
        inc dx
        mov al,04h
        out dx,al  ; control lines to steady state


stat:
        mov ah,90h  ; just makeup something for now
        jmp ret1


printchar:
        mov dx,cs:[ioprt]    ; fill dx with proper port address
                          ; AL is already set from user call to intr 17


;   Outputs char to gpib device
;   AL = inchar    DX = i/o port address

printit:

                  ; send char out to port
        not al    ; need to invert bits           xor AL,ffh
        out dx,al


                  ; see if nrfd and ndac are both asserted illegal bus state
        inc dx
        inc dx
        in  al,dx
        and al,0Ah
        cmp al,0Ah
        jz error1

                  ; test srq - only active on error conditions
        dec dx
        in  al,dx
        and al,08h
        or  al,al
        jz error1

                  ; repeat till ready to accept data
        inc dx
loop1:  in  al,dx
        and al,0Ah  ; nrfd and ndac
        cmp al,08h  ; ndac set
        jnz loop1

        mov al,5h
        out dx,al   ; Dav low

loop2:  in  al,dx
        and al,0Ah  ; nrfd and ndac
        cmp al,02h  ; nrfd set
        jnz loop2

        mov al,4h
        out dx,al   ; atn high

        jmp stat    ; check buss status


error1: ;same as stat but with additional errors reported

        mov ah,90h  ; just makeup something for now
        jmp ret1


start:

        mov ax,3517h   ; get vector for int 17
        int 21h
        mov cs:[vec17o] ,bx
        mov cs:[vec17s] ,es ; save old vector

        mov dx, offset printerio
        mov ax,2517h   ; take over int 17
        int 21h


        mov dx,cs:[ioprt]     ; init port ***************
        mov al,00h
        out dx,al  ; data to $ff

        inc dx
        inc dx
        mov al,04h
        out dx,al  ; control lines to steady state

        mov dx, offset endd
        int 27h  ; terminate and stay resident

endd:   END st1

