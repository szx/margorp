
%define BOOT_SECTOR_BASE 0x7c00
%define REAL_MODE_STACK_ADDR BOOT_SECTOR_BASE - 1
%define BOOT_LOADER_PRINT_ADDR BOOT_SECTOR_BASE + 128
%macro BOOT_LOADER_PRINT 2
    pusha
    mov bp, %1
    mov cx, %2
    lea bx, [cs:BOOT_LOADER_PRINT_ADDR] ; Some weird ld relocation problem.
    call bx
    popa
%endmacro

%define CODE_SEG 0x8
%define DATA_SEG 0x10

; TODO: Sane description of memory map.
; Currently it looks something like this:
; * usable memory
;    0x00000000 real mode address space (the first MB):
; *v 0x00000500 payload_16.asm
; *  0x00000700 payload_64.asm 
; *             forth.asm 
; *^ 0x00007BFF ^ temporary real mode stack (REAL_MODE_STACK_ADDR)
; *  0x00007C00 bootsector.asm (BOOT_SECTOR_BASE)
; *v 0x00007E00 usable memory start
; *v            E820 memory map entries start (max 128 for legacy reasons) (E820_MEMORY_MAP_ADDR)
; *^ 0x000089FF
; *-
; *v 0x00009000 page table (PAGE_TABLES_ADDR)
; *^ 0x0000CFFF
; *-
; *^ 0x0007FFFF usable memory end
;  v 0x00080000 EBDA start
;  ^ 0x0009FFFF EBDA end
;  v 0x000A0000 video display memory start
; *  0x000B0000 vga text memory (VGA_TEXT_MEM_ADDR)
;  ^ 0x000BFFFF video display memory emd
; *v 0x00100000 extended memory start (14 MB)
; *v            keyboard buffer start (KEYBOARD_BUFFER_ADDR)
; *^ 0x00101000 keyboard buffer end
; *^ 0x00EFFFFF extended memory end
;  v 0x00F00000 ISA memory hole start
;  ^ 0x00FFFFFF ISA memory hole start
; *v 0x01000000 more extended memory start
;    0x???????? memory mapped devices
;               long mode stack (LONG_MODE_STACK_ADDR)
; *^ 0x???????? more extended memory end (MEM_HIGH_ADDR)
; Also should read memory map from BIOS.




%define E820_MEMORY_MAP_ADDR 0x7E00
%define E820_MEMORY_MAP_ENTRY_SIZE 24
%define E820_MEMORY_MAP_ENTRY_NUM 128
%define E820_MEMORY_MAP_SIZE E820_MEMORY_MAP_ENTRY_SIZE * E820_MEMORY_MAP_ENTRY_NUM

%define PAGE_SIZE 0x1000
%define PAGE_TABLES_ADDR 0x9000 ; has to be page-aligned addr
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
