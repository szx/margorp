; --------------------
; Forth!
; --------------------

%define VGA_MEM_ADDR 0xb8000
%define VGA_TEXT_WIDTH 80
%define VGA_TEXT_HEIGHT 25
; TODO: Change VGA mode from 80x25 text to ???

; rsp: call stack (hardware stack)
; rbp: parameter stack
; r15: first argument (caller preserved)
; r14: second argument (caller preserved)
; rax, rbx, rcx, rdx: clobbered

%macro push_param 1
    sub rbp, 8
    mov qword [rbp], %1
%endmacro

%macro pop_param 1
    mov %1, [rbp]
    add rbp, 8
%endmacro

%macro cal 1
    call %1 + 9
%endmacro


%define IMMEDIATE 1


forth:
    mov rbp, MEM_HIGH_ADDR
.loop:
    call read_word
    mov r15, cur_word
    call find_word
    cmp r15, 0
    je .try_parsing_number
.interpret:
    cmp r14, 1
    je .execute ; immediate
    cmp byte [interpreter_mode], 0
    jne .compile
.execute:
    call r15
    jmp .loop
.compile:
    call emit_call
    jmp .loop
.try_parsing_number:
    mov r15, cur_word
    call parse_number
    jnz .number
.word_not_found:
    mov r15, cur_word
    call print_msg
    mov r15, error_msg
    call print_msg
    jmp .loop
.number:
    cmp byte [interpreter_mode], 0
    jne .emit_number
.push_number:
    push_param r15
    jmp .loop
.emit_number:
    push_param r15
    cal _literal
    jmp .loop

error_msg: db 10, ' not found'

print_msg:
    ; r15: string ptr (len byte + ascii)
    mov cl, byte [r15]
    inc r15
.loop:
    test cl, cl
    jnz .continue
    ret
.continue:
    mov al, byte [r15]
    inc r15
    dec cl
    mov r8w, word [print_msg_x]
    lea edi, [VGA_MEM_ADDR + 2*r8] ; vga memory
    mov ah, 0x1F
    mov word [edi], ax
    inc word [print_msg_x]
    call print_scroll
    jmp .loop
print_msg_x: dw 0

print_new_line:
    mov ax, word [print_msg_x]
    mov cl, VGA_TEXT_WIDTH
    div cl
    xor ah, ah
    inc al
    mul cl
    mov word [print_msg_x], ax
    call print_scroll
    ret

print_scroll:
    cmp word [print_msg_x], VGA_TEXT_WIDTH * VGA_TEXT_HEIGHT
    jl .end
    mov r8w, word [print_msg_x]
    sub r8w, VGA_TEXT_WIDTH
    mov word [print_msg_x], r8w
    
    push rsi
    push rdi
    push rcx
    push rax
    cld
    mov rsi, VGA_MEM_ADDR + 2 * VGA_TEXT_WIDTH
    mov rdi, VGA_MEM_ADDR
    xor rcx, 2 * VGA_TEXT_WIDTH * (VGA_TEXT_HEIGHT - 1)
    rep movsb
    mov rdi, VGA_MEM_ADDR + 2 * VGA_TEXT_WIDTH * (VGA_TEXT_HEIGHT - 1)
    mov rcx, VGA_TEXT_WIDTH
    mov ax, 0x1F20 ; Set the value to set the screen to: Blue background, white foreground, blank spaces.
    rep stosw
    pop rax
    pop rcx
    pop rdi
    pop rsi
    call print_scroll
.end:
    ret

%define LEFT_SHIFT_ASCII 1
read_char:
    ; return al: char
    mov rsi, [script_ptr]
    mov al, byte [rsi]
    test al, al
    jz .keyboard
    inc qword [script_ptr]
    ret
.keyboard:
    mov rsi, scancode_to_ascii
.loop:
    ; check if MSB is 1 (released)
    xor rbx, rbx
    mov bl, byte [keyboard_scancode]
    bt bx, 7
    jc .loop
    test bl, bl
    jz .loop
    xor rax, rax
.ascii:
    mov al, byte [rsi + rbx]
    test al, al
    jz .loop

    cmp al, LEFT_SHIFT_ASCII
    jne .end
    mov rsi, scancode_to_ascii_shift
    jmp .loop
.end:
    ; xchg bx, bx ; magic breakpoint
    mov byte [keyboard_scancode], 0xFF
    ret
scancode_to_ascii:
db 0, 0, '1', '2', '3', '4', '5', '6'
db '7', '8', '9', '0', '-', '=', `\b`, `\t`
db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i'
db 'o', 'p', '[', ']', `\n`, 0, 'a', 's'
db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';'
db 39, 96, LEFT_SHIFT_ASCII, 92, 'z', 'x', 'c', 'v'
db 'b', 'n', 'm', ',', '.', '/', 0, '*'
db 0, ' ', 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, '-', 0, 0, 0, '+', 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
; TODO: More scancodes.
scancode_to_ascii_shift:
db 0, 0, '!', '@', '#', '$', '%', '^'
db '&', '*', '(', ')', '_', '+', `\b`, `\t`
db 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I'
db 'O', 'P', '{', '}', `\n`, 0, 'A', 'S'
db 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':'
db 39, 96, LEFT_SHIFT_ASCII, 92, 'Z', 'X', 'C', 'V'
db 'B', 'N', 'M', '<', '>', '?', 0, '*'
db 0, ' ', 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, '-', 0, 0, 0, '+', 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
db 0, 0, 0, 0, 0, 0, 0, 0
; TODO: More scancodes.

read_word:
    ; writes str to cur_word
    mov r15, cur_word_str
    xor rcx, rcx
.skip_whitespace:
	call read_char
	cmp al, 0x20
	jbe .skip_whitespace
.acc_chars:
	mov byte [r15], al
	inc r15
    inc rcx
	call read_char
	cmp al, 0x20
	ja .acc_chars
	mov byte [cur_word], cl
    ret

parse_number:
    ; r15: word str
    ; return r15: number
    ; return ZF: 0 if not a number
    xor r8, r8
    mov r8b, byte [r15] ; len
    lea r9, [r15+r8] ; str end
    mov r15, 0 ; result
    mov r10, 1 ; multiplier
    mov r11, 10 ; multiplier
.loop:
    test r8, r8
    jz .end
    xor rax, rax
    mov al, byte [r9]
    cmp al, '0'
    jb .err
    cmp al, '9'
    ja .err
    sub al, '0'
    
    mul r10
    add r15, rax

    mov rax, r10
    mul r11
    mov r10, rax

    dec r9
    dec r8
    jmp .loop
.err:
    xor rax, rax ; ZF=1
    ret
.end:
    xor rax, rax
    inc rax ; ZF=0
    ret

find_word:
    ; r15: word str
    ; return r15: word address or 0
    ; return r14: 1 if immediate or 0
    xor r14, r14
    xor r8, r8
    mov r8b, byte [r15] ; len
    lea r9, [r15+1] ; str
    mov r15, [dictionary]
.loop:
    cmp r8b, byte [r15 - 1]
    jne .next
    cld
    mov rsi, r9
    lea rdi, [r15 - 1]
    sub rdi, r8
    mov rcx, r8
    repz cmpsb
    jz .end
.next:
    mov r15, [r15]
    test r15, r15
    jnz .loop
    jmp .fail
.end:
    mov r14b, byte [r15 + 8]
    add r15, 9 ; call addr
.fail:
    ret


db 'cls'
db 3
_cls: dq 0x0
    db 0
    ; Clear vga.
    mov edi, VGA_MEM_ADDR
    mov rcx, 4000/8
    mov rax, 0x1F201F201F201F20       ; Set the value to set the screen to: Blue background, white foreground, blank spaces.
    rep stosq
    mov word [print_msg_x], 0
    ret


db 'bye'
db 3
_bye: dq _cls
    db 0
.loop:
    hlt ; doesn't disable interrupts
    jmp .loop
    ret


db 'break'
db 5
_break: dq _bye
    db 0
_magic_breakpoint:
    xchg bx, bx ; magic breakpoint
    ret

db '+'
db 1
_plus: dq _break
    db 0
    pop_param r15
    pop_param r14
    add r15, r14
    push_param r15
    ret


db '-'
db 1
_minus: dq _plus
    db 0
    pop_param r15
    pop_param r14
    sub r14, r15
    push_param r14
    ret


db '*'
db 1
_mul: dq _minus
    db 0
    pop_param rax
    pop_param r14
    mul r14
    push_param rax
    ret


db '/'
db 1
_div: dq _mul
    db 0
    pop_param r14
    pop_param rax
    div r14
    push_param rax
    ret

db 'mod'
db 3
_mod: dq _div
    db 0
    pop_param r14
    pop_param rax
    div r14
    push_param rdx
    ret


db '/mod'
db 4
_div_mod: dq _mod
    db 0
    pop_param r14
    pop_param rax
    div r14
    push_param rdx
    push_param rax
    ret


db 'xor'
db 3
_xor: dq _div_mod
    db 0
    pop_param r15
    pop_param r14
    xor r14, r15
    push_param r14
    ret


db '='
db 1
_eq: dq _xor
    db 0
    pop_param r15
    pop_param r14
    xor rax, rax
    cmp r15, r14
    sete al
    push_param rax
    ret


db '!='
db 2
_ne: dq _eq
    db 0
    pop_param r15
    pop_param r14
    xor rax, rax
    cmp r15, r14
    setne al
    push_param rax
    ret


db '>'
db 1
_gt: dq _ne
    db 0
    pop_param r15
    pop_param r14
    xor rax, rax
    cmp r14, r15
    setg al
    push_param rax
    ret


db '<'
db 1
_lt: dq _gt
    db 0
    pop_param r15
    pop_param r14
    xor rax, rax
    cmp r14, r15
    setl al
    push_param rax
    ret


db '<='
db 2
_le: dq _lt
    db 0
    pop_param r15
    pop_param r14
    xor rax, rax
    cmp r14, r15
    setle al
    push_param rax
    ret


db '>='
db 2
_ge: dq _le
    db 0
    pop_param r15
    pop_param r14
    xor rax, rax
    cmp r14, r15
    setge al
    push_param rax
    ret


db 'emit'
db 4
emit: dq _ge
    db 0
    pop_param r15
    xchg bx, bx ; magic breakpoint
    cmp r15b, 10
    jne .ascii
    call print_new_line
    ret
.ascii:
    mov byte [emit_msg + 1], r15b
    mov r15, emit_msg
    call print_msg
    ret
emit_msg: db 1, ' '

db 'key'
db 3
key: dq emit
    db 0
    call read_char
    xor rbx, rbx
    mov bl, al ; make sure reg is zero-extended
    push_param rbx
    ret


db "'"
db 1
_tick: dq key
    db IMMEDIATE
    call read_word
    mov r15, cur_word
    call find_word
    ; 0 if not found
    push_param r15
    ret


db "execute"
db 7
_execute: dq _tick
    db 0
    pop_param r15
    call r15
    ret


; TODO: Replace . with colon word.
db '.'
db 1
dot: dq _execute
    db 0
    pop_param r15
    xor rdx, rdx
    xor rcx, rcx
    mov rax, r15
    mov r10, 10
.loop_push:
    div r10
    push rdx
    xor rdx, rdx
    inc rcx
    test rax, rax
    jnz .loop_push
.loop_pop:
    pop r15
    add r15, 0x30
    mov byte [char_msg + 1], r15b
    mov r15, char_msg
    push r15
    push rcx
    call print_msg
    pop rcx
    pop r15

    dec rcx
    test rcx, rcx
    jnz .loop_pop
    ret
char_msg: db 1, ' '


db 'dup'
db 3
_dup: dq dot
    db 0
    pop_param r15
    push_param r15
    push_param r15
    ret


db 'swap'
db 4
_swap: dq _dup
    db 0
    pop_param r15
    pop_param r14
    push_param r15
    push_param r14
    ret


db 'drop'
db 4
_drop: dq _swap
    db 0
    pop_param r15
    ret



db 'depth'
db 5
_depth: dq _drop
    db 0
    mov r15, MEM_HIGH_ADDR
    sub r15, rbp
    shr r15, 3
    push_param r15
    ret

db '>r'
db 2
to_r: dq _depth
    db 0
    pop_param r15
    pop r14 ; save return addr
    push r15
    push r14 ; restore return addr
    ret


db 'r>'
db 2
r_from: dq to_r
    db 0
    pop r14 ; save return addr
    pop r15
    push_param r15
    push r14 ; restore return addr
    ret


db '@'
db 1
fetch: dq r_from
    db 0
    pop_param r15
    mov rax, [r15]
    push_param rax
    ret


db 'dp'
db 2
dp: dq fetch
    db 0
    mov rax, rest_of_memory_ptr
    push_param rax
    ret


db 'latest'
db 6
latest: dq dp
    db 0
    mov rax, dictionary
    push_param rax
    ret


db ':' ; Define the start of a subroutine.
db 1
colon: dq latest
    db 0
    call read_word

    cld
    mov rsi, cur_word_str
    mov rdi, [rest_of_memory_ptr]
    xor rcx, rcx
    mov cl, byte [cur_word]
    rep movsb

    mov cl, byte [cur_word]
    mov byte [rdi], cl
    add rdi, 1

    mov rax, [dictionary]
    mov [dictionary], rdi
    mov qword [rdi], rax
    add rdi, 8
    
    mov byte [rdi], 0 ; not immediate
    add rdi, 1

    mov [rest_of_memory_ptr], rdi

    ; switch to compile mode (append word calls to definition instread of executing the, unless they are immediate like ;)
    mov byte [interpreter_mode], 1
    ret

emit_call:
    ; r15: addr
    mov rdi, [rest_of_memory_ptr]

    ; emit mov rax, addr 
    mov word [rdi], 0xb848
    add rdi, 2
    mov qword [rdi], r15
    add rdi, 8
    ; emit call rax
    mov word [rdi], 0xd0ff
    add rdi, 2

    mov [rest_of_memory_ptr], rdi
    ret


db 'literal'
db 7
_literal: dq colon
    db IMMEDIATE

    pop_param r15

    mov rdi, [rest_of_memory_ptr]

    ; emit mov rbx, number
    mov word [rdi], 0xbb48
    add rdi, 2
    mov qword [rdi], r15
    add rdi, 8
    ; emit mov rax, push_number
    mov word [rdi], 0xb848
    add rdi, 2
    mov qword [rdi], push_number
    add rdi, 8
    ; emit call rax
    mov word [rdi], 0xd0ff
    add rdi, 2

    mov [rest_of_memory_ptr], rdi
    ret

push_number:
    ; rbx: number
    push_param rbx
    ret


db 'postpone'
db 8
_postpone: dq _literal
    db IMMEDIATE
    call read_word
    mov r15, cur_word
    call find_word
    ; r15: call addr
    ; r14: 1 if immediate or 0
    cmp r14, 1
    je .interpret

.compile:
    mov rdi, [rest_of_memory_ptr]

    ; emit mov rbx, call addr
    mov word [rdi], 0xbb48
    add rdi, 2
    mov qword [rdi], r15
    add rdi, 8
    ; emit mov rax, append_call
    mov word [rdi], 0xb848
    add rdi, 2
    mov qword [rdi], append_call
    add rdi, 8
    ; emit call rax
    mov word [rdi], 0xd0ff
    add rdi, 2

    mov [rest_of_memory_ptr], rdi
    ret

.interpret:
    mov rbx, r15
    call append_call
    ret

append_call:
    ; rbx: call addr
    
    mov rdi, [rest_of_memory_ptr]

    ; emit mov rax, addr 
    mov word [rdi], 0xb848
    add rdi, 2
    mov qword [rdi], rbx
    add rdi, 8
    ; emit call rax
    mov word [rdi], 0xd0ff
    add rdi, 2

    mov [rest_of_memory_ptr], rdi
    ret


db 'branch' ; ( -- )
db 6
_branch: dq _postpone
    db 0

    pop r14 ; return addr
    mov r14, qword [r14]
    push r14
    ret


db '0branch' ; ( f -- )
db 7
_0branch: dq _branch
    db 0

    pop_param r15 ; arg
    test r15, r15
    jz .ok
    pop r14 ; return addr
    add r14, 8
    push r14
    ret
.ok:
    pop r14 ; return addr
    mov r14, qword [r14]
    push r14
    ret


db ';' ; Perform a subroutine return and end the definition of a subroutine. 
db 1
semicolon: dq _0branch
    db IMMEDIATE
    ; emit ret
    mov rdi, [rest_of_memory_ptr]
    mov byte [rdi], 0xC3
    add rdi, 1
    mov [rest_of_memory_ptr], rdi
    
    ; switch to execute mode
    mov byte [interpreter_mode], 0
    ret



db 'immediate' ; Mark latest word as immediate 
db 9
immediate: dq semicolon
    db IMMEDIATE
    mov rdi, [dictionary]
    add rdi, 8
    mov byte [rdi], IMMEDIATE
    ret

db '|'
db 1
_switch: dq immediate
    db IMMEDIATE
    xor byte [interpreter_mode], 1
    ret

db '!'
db 1
write: dq _switch
    db 0
    pop_param r15 ; ADDR
    pop_param r14 ; N
    mov [r15], r14
    ret


; TODO: more complex words

dictionary: dq write
cur_word: db 0
cur_word_str: times 0xFF db 0
interpreter_mode: db 0
rest_of_memory_ptr: dq rest_of_memory

script_ptr: dq script

rest_of_memory:

times 0xFFF db 0 ; TODO: Make sure enough space reserved to not overwrite script while read

script:
