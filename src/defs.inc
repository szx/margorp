
%define BOOT_SECTOR_BASE 0x7c00
%define REAL_MODE_STACK_ADDR BOOT_SECTOR_BASE - 1

%define CODE_SEG 0x8
%define DATA_SEG 0x10

; TODO: Sane description of memory map.
; Currently it looks something like this:
; - REAL_MODE_STACK_ADDR
; - BOOT_SECTOR_BASE
; - PAGE_TABLES_ADDR
; - kernel code
; - forth dictionary
; - VGA_TEXT_MEM_ADDR
; - KEYBOARD_BUFFER_ADDR
; - LONG_MODE_STACK_ADDR - LONG_MODE_STACK_SIZE
; - LONG_MODE_STACK_ADDR
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

%define VGA_TEXT_MEM_ADDR 0xb8000
%define VGA_TEXT_WIDTH 80
%define VGA_TEXT_HEIGHT 25

%define KEYBOARD_BUFFER_ADDR 0x100000
%define KEYBOARD_BUFFER_SIZE 0x1000

%define LONG_MODE_STACK_SIZE 0x100000
%define LONG_MODE_STACK_ADDR MEM_HIGH_ADDR
