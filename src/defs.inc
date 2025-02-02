
%define STACK_ADDR 0x6000

%define CODE_SEG 0x8
%define DATA_SEG 0x10

; TODO: Sane description of memory map.
; Currently it looks something like this:
; - PAGE_TABLES_ADDR
; - kernel code
; - forth dictionary
; - KEYBOARD_BUFFER_ADDR
; - stack at MEM_HIGH_ADDR
; Also should read memory map from BIOS.

%define PAGE_SIZE 0x1000
%define PAGE_TABLES_ADDR 0x6000
%define PAGE_TABLES_SIZE 0x4000
%define MEM_HIGH_ADDR 0x5FFFFF

%define PAGE_PRESENT    (1 << 0)
%define PAGE_WRITE      (1 << 1)

%define PIC1 0x20
%define PIC2 0xA0
%define PIC1_COMMAND PIC1
%define PIC1_DATA (PIC1+1)
%define PIC2_COMMAND PIC2
%define PIC2_DATA (PIC2+1)
%define PIC_EOI 0x20

%define KEYBOARD_BUFFER_ADDR 0x100000
%define KEYBOARD_BUFFER_SIZE 0x1000