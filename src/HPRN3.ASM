;  Parallel port gpib driver
;
;   12-20-90  HPRN.COM By      John L. Sokol
;             Captures int 17 and replaces it with HPIB signaling
;
;   1-30-91   Hprn.com   hprn3.asm  John L. Sokol
;             Adding autoport detection and
;             feedthrough for regular printers
;
;
;

masm

bios_seg        EQU  0040h
printer_base    EQU  0008h
portdelay       EQU  0020h

code    segment para public 'CODE'
        assume es:code, ds:code, ss:nothing, cs:code

        org     100h

st1:    jmp  start


Vec17      label   dword   ; the old tick vector
Vec17O     dw      ?
Vec17S     dw      ?


PortNum    DW 0000h   ; 0 = lpt1 , 1 = lpt2 ....
PortAddr   DW 0378h

pspseg     dw 0000h          ; save the old PSP segment address

timeout db 5

printerio:

        STI

        cmp DX,cs:[portnum]  ; if not on detected port then pass through
        jz  doit             ; to original driver

        cmp DX,0FFFFh        ; if port address = FFFF Detect installed
        jz  detme

        jmp cs:[vec17]       ; goto BIOS printer driver

detme:
        mov bx,cs:[Portnum]
        mov cx,cs:[PortAddr]
        Mov Dx, 0BACEh       ; This is to detect if already installed
        IRET

doit:                        ; proper interupt handler
        push ds
        push si
        push dx
        push cx
        push bx
                             ; select subfunction
        or ah,ah             ; test for AH = 00
        jz printchar         ; print char in AL

        dec ah
        jz init              ; initialize interface and printer

        dec ah
        jz stat              ; get printer status

ret1:   pop bx
        pop cx
        pop dx
        pop si
        pop ds
        IRET


init:   ; ************************** initialize printer

        mov dx,cs:[PortAddr]
        mov al,00h
        out dx,al            ; data to $ff

        inc dx
        inc dx
        mov al,04h
        out dx,al            ; control lines to steady state

                             ; Drop into status routine

stat:   ; ************************* get status
        mov ah,90h  ; just makeup something for now
        jmp ret1




printchar:  ;************************* Print character
        mov dx,cs:[PortAddr]    ; fill dx with proper port address
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

        mov al,5
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




TSR_end:


; *********************** interface messages **********************


autodet  db     0Dh,0Ah,'PORT Address Autodetected $'

pdet     db     0Dh,0Ah,'HPIB emulation on LPT '
Aportnum db     '1' , 0dh,0ah,'$'

inst     db     0Dh,0Ah,'Error HPIB Driver already installed', 0dh,0ah,'$'



;*****************************************
;*
;*   P o r t    A u T o D e t e c t
;*   looks for pins 11 and 16 shorted
;*
;*   bx port counter = 0,2,4
;*   di indirect pointer to port addresses
;*   dx port address
;* ________________________________________
;*        Write         |       Read
;* _____________________|__________________
;*   $ X7A bit 2  Low   |  $ X79 bit 7 High
;* _____________________|__________________
;*   $ X7A bit 2  High  |  $ X79 bit 7 Low
;* _____________________|__________________
;*
;*****************************************

port_detect:

         mov     ax,bios_seg
         mov     es,ax                   ; ES points to bios data segment

         xor     bx,bx

ploop1:  mov     di,printer_base

         add     di,bx
         mov     dx,word ptr es:[di]    ; load port address
         jz      pfail2

  ;*******  Save port status
         add     dx,02h    ; X7A
         in      al,dx                  ; save old port status
         push    AX

  ;******* Check first state

         AND     AL,0FBh    ; Bit 2 LOW
         out     dx,al
         dec     DX         ; X79

         mov     cx,portdelay           ; wait for electronics
         loop    $

         in      al,dx
         AND     AL,80h    ;  PASS Bit 7
         JZ      pfail     ; if not high

  ;******* Check Second state

         INC     DX         ; X7A
         in      al,dx
         OR      AL,04h    ; Bit 2 High
         out     dx,al
         dec     DX         ; X79

         mov     cx,portdelay           ; wait for electronics
         loop    $

         in      al,dx
         AND     AL,80h    ;  PASS Bit 7
         JNZ     pfail     ; if not LOW

  ;******** restore port status
         inc     DX        ; X7A

         pop     AX                   ; restore port status if passed
         out     dx,al

         jmp     ppassed

pfail:
         inc     DX        ; X7A
         pop     AX                   ; restore port status if failed
         out     dx,al

pfail2:                             ; No port address found
         add     bx,02h
         cmp     bx,08h             ; is it the end of the address array
         jne     ploop1             ; test all 4 possible addresses
         jmp     pend

ppassed:
         sub     dx,02h                ; return DX to data register
         mov     word ptr cs:[portaddr],dx      ; save address of autodetect

         shr    bl,01h                  ;output auto port detected

         mov    BH,00h
         mov    word ptr portnum,BX    ; save as 0, 1, 2 for port 1,2, or 3
         add    bl,'1'
         mov    byte ptr Aportnum,bl    ; save as 1, 2, 3 for port 1,2, or 3

         MOV    DX, OFFSET autodet    ; report AUTODETECTION
         MOV    AH, 09h
         INT    21h
pend:
         ret



start:   ; ************************************************************

        mov     bx,ds                  ; get PSP address

        push cs  ; set ds to cs
        pop ds

        mov     pspseg,bx              ; save PSP for possible later use

        mov AX,0100h    ; test int 17h see if installed already!!
        mov DX,0ffffh
        int 17h

        CMP Dx, 0BACEh
        JZ  installed


        CALL port_detect


        mov ax,3517h    ; get vector for int 17h
        int 21h
        mov vec17S   ,es ; save old vector
        mov vec17O   ,bx

        mov dx, offset printerio
        mov ax,2517h   ; take over int 17h
        int 21h

        mov dx,cs:[PortAddr]     ; init port ***************
        mov al,00h
        out dx,al  ; data to $ff

        inc dx
        inc dx
        mov al,04h
        out dx,al  ; control lines to steady state

        MOV    DX, OFFSET pdet    ; report where it was installed
        MOV    AH, 09h
        INT    21h


        mov dx, offset TSR_END
        inc dx
        inc dx
        int 27h  ; terminate and stay resident


installed:     ; ************ installed already !!
               
        MOV    DX, OFFSET inst    ; report it was installed already
        MOV    AH, 09h
        INT    21h
        
        MOV    AX, 4C01h  ; Return with error code
        INT    21h

code    ends
        END st1



