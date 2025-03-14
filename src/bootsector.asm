; --------------------
; bootloader (sector 1)
; load sector 2
; basic cpuid checks
; enable A20 line
; --------------------
BITS 16
; uses ld instead of org 0x7c00

%define SECTORS 50 ; TODO: Calculate using size

jmp start
times 128-($-$$) db 90h ; TODO: Actual BIOS parameter block

bootloader_print:
    ; bp: Pointer to string
    ; cx: Number of characters to write
    push ds
    push si
    push es
    push di
    mov ah, 0x13                ; Function: Write string
    mov al, 0                   ; write mode: don't update cursor
    mov bh, 0                   ; page number
    mov bl, 0xf                 ; color: white
    mov dh, byte [print_row]    ; Row
    inc byte [print_row]
    mov dl, 0                   ; Column
    int 0x10
    pop di
    pop es
    pop si
    pop ds
    ret
print_row: db 0

start:
    mov ax, 0
    mov ds, ax      ; segment registers
    mov es, ax
    mov ss, ax
    mov sp, ax      ; stack 

    mov ah, 0x02    ; Function: Read Sectors From Drive
    mov al, SECTORS ; sector count
    mov ch, 0       ; cylinder
    mov cl, 2       ; sector
    mov dh, 0       ; head
    mov bx, 0x500   ; dst addr
    xchg bx, bx ; magic breakpoint
    int 0x13
    ; TODO: Check if sectors were read.

    call check_long_mode

    call enable_a20

    ; setup long mode
    jmp 0:0x500

enable_a20:
    cli
    ; TODO: Actually enable A20.
    call check_a20
    jz .err
.ok:
    sti
    mov ax, 1
    ret
.err:
    sti
    jmp err_disabled_a20

check_a20:
    ; ax: 0 if disabled
    ; NOTE: https://wiki.osdev.org/A20_Line
    pushf
	push si
	push di
	push ds
	push es
	cli

	mov ax, 0x0000                  ; 0x0000:0x0500(0x00000500) -> ds:si
	mov ds, ax
	mov si, 0x0500

	not ax						    ; 0xffff:0x0510(0x00100500) -> es:di
	mov es, ax
	mov di, 0x0510

	mov al, [ds:si]					; save old values
	mov byte [.BufferBelowMB], al
	mov al, [es:di]
	mov byte [.BufferOverMB], al

	mov ah, 1
	mov byte [ds:si], 0
	mov byte [es:di], 1
	mov al, [ds:si]
	cmp al, [es:di]					; check byte at address 0x0500 != byte at address 0x100500
	jne .exit
	dec ah
.exit:
	mov al, [.BufferBelowMB]
	mov [ds:si], al
	mov al, [.BufferOverMB]
	mov [es:di], al
	shr ax, 8					    ; move result from ah to al register and clear ah
	sti
	pop es
	pop ds
	pop di
	pop si
	popf
	ret
.BufferBelowMB:	db 0
.BufferOverMB	db 0

check_long_mode:
    call check_cpuid
    test eax, eax
    jz err_no_cpuid
    
    mov eax, 0x0    ; CPU Vender ID
    cpuid
    mov dword [vendor_id], ebx
    mov dword [vendor_id + 4], edx
    mov dword [vendor_id + 8], ecx
    mov bp, vendor_id
    mov cx, 12
    call bootloader_print

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb err_no_cpuid_ext

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29
    jz err_no_long_mode
    ret
vendor_id: times 12 db 0


check_cpuid:
    ; eax: zero if CPUID not supported
    ; NOTE: https://wiki.osdev.org/CPUID#How_to_use_CPUID
    pushfd                      ; Save EFLAGS
    pushfd                      ; Store EFLAGS
    xor dword [esp],0x00200000  ; Invert the ID bit in stored EFLAGS
    popfd                       ; Load stored EFLAGS (with ID bit inverted)
    pushfd                      ; Store EFLAGS again (ID bit may or may not be inverted)
    pop eax                     ; eax = modified EFLAGS (ID bit may or may not be inverted)
    xor eax,[esp]               ; eax = whichever bits were changed
    popfd                       ; Restore original EFLAGS
    and eax,0x00200000          ; eax = zero if ID bit can't be changed, else non-zero
    ret

err_no_cpuid:
    mov byte [msg + msg_len - 3], '0'
    jmp err
err_no_cpuid_ext:
    mov byte [msg + msg_len - 3], '1'
    jmp err
err_no_long_mode:
    mov byte [msg + msg_len - 3], '2'
    jmp err
err_disabled_a20:
    mov byte [msg + msg_len - 3], '3'
    jmp err
err:
    mov bp, msg
    mov cx, msg_len
    call bootloader_print
.loop:
    hlt
    jmp .loop
msg:
  db 'Bootloader error: (_)!'
msg_len equ $ - msg

times 510 -( $ - $$ ) db 0
db 0x55, 0xaa