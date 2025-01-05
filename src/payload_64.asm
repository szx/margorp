; --------------------
; payload 64-bit (sector 3+)
; Setup IRQ
; Jump to Forth
; --------------------

%include "defs.inc"

BITS 64
%define ORGIN 0x700 ; uses ld instead of org 0x700

payload_64:
    call enable_irq

    ; TODO: Figure out MMIO using PCI?
    jmp forth

enable_irq:
    lidt [IDTR.Pointer]

    ; PIC initialization sequence:
    ; ICW1
    mov al, 0x11        ; ICW1_INIT | ICW1_ICW4
    out PIC1, al
    mov al, 0x11        ; ICW1_INIT | ICW1_ICW4
    out PIC2, al
    ; ICW2
    mov al, 0x20        ; IRQ 0-7: interrupts 20h-27h
    out PIC1_DATA, al
    mov al, 0x28        ; IRQ 8-15: interrupts 28h-2Fh
    out PIC2_DATA, al
    ; ICW3
    mov al, 4
    out PIC1_DATA, al
    mov al, 2
    out PIC2_DATA, al
    ; ICW4
    mov al, 1
    out PIC1_DATA, al
    mov al, 1
    out PIC2_DATA, al

    ; Unmask all interrupts.
    mov al, 0x80
    out PIC1_DATA, al
    mov al, 0x80
    out PIC2_DATA, al
    ret

%macro isr_entry 1
    dw ((ORGIN + %1 - $$) & 0xFFFF)             ; Low offset.
    dw CODE_SEG                                 ; Code segment.
    db 0                                        ; IST in TTS.
    db 0x8F                                     ; Attributes.
    dw ((ORGIN + %1 - $$) >> 16) & 0xFFFF       ; Middle offset
    dd ((ORGIN + %1 - $$) >> 32) & 0xFFFFFFFF   ; High offset
    dd 0                                        ; Reserved.
%endmacro
IDT:
%assign i 0
%rep 256
    isr_entry isr_%+ i
    %assign i i+1
%endrep
IDTR:
ALIGN 8
    dq 0
    .Pointer:
    dw $ - IDT - 1
    dq IDT



isr_32: ; systimer
    push rax
    inc qword [systimer_ticks]
    mov al, PIC_EOI
    out PIC1_COMMAND, al
    pop rax
    iretq
systimer_ticks: dq 0

isr_33: ; keyboard
    push rax
    xor rax, rax
    in al, 0x60 ; Read byte.
    ; xchg bx, bx ; magic breakpoint
    mov [keyboard_scancode], al
    mov al, PIC_EOI
    out PIC1_COMMAND, al
    pop rax
    iretq
keyboard_scancode: dq 0

%assign i 0
%rep 256
    %if i != 32 && i != 33
        isr_%+ i:
            xchg bx, bx ; magic breakpoint
            push rax
            mov rax, i
            jmp isr_dummy
    %endif
    %assign i i+1
%endrep
isr_dummy:
    pop rax
    iretq

%include "forth.asm"