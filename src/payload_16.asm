; --------------------
; payload 16-bit (sector 2)
; get info from BIOS, setup long mode
; --------------------

%include "defs.inc"

BITS 16
; uses ld instead of org 0x500
payload_16:
    ; NOTE: https://wiki.osdev.org/Setting_Up_Long_Mode
    ; NOTE: "Low-Level Programming" by Igor Zhirkov

    ; Temporary stack, will be replaced with LONG_MODE_STACK_ADDR.
    mov sp, REAL_MODE_STACK_ADDR
    
    call query_memory_map_from_bios

    ; TODO: Get device info from BIOS
    ; mov ah, 00h
    ; mov dl, 0x80
    ; int 13h

    ; Setup pages.
    mov di, PAGE_TABLES_ADDR
    mov ecx, 0x1000
    xor eax, eax
    cld
    rep stosd
    mov di, PAGE_TABLES_ADDR

    ; Build PML4 (Page Map Level 4).
    lea eax, [di + PAGE_SIZE]
    or eax, PAGE_PRESENT | PAGE_WRITE
    mov [di], eax

    ; Build PDPT (Page Directory Pointer Table).
    lea eax, [di + 2*PAGE_SIZE]
    or eax, PAGE_PRESENT | PAGE_WRITE
    mov [di + PAGE_SIZE], eax
    
    ; TODO Map more than first 6 Mb memory.

    ; Build PD (Page Directory).
    lea eax, [di + 3*PAGE_SIZE]
    or eax, PAGE_PRESENT | PAGE_WRITE
    mov [di + 2*PAGE_SIZE], eax
    
    lea eax, [di + 3*PAGE_SIZE + PAGE_SIZE]
    or eax, PAGE_PRESENT | PAGE_WRITE
    mov [di + 2*PAGE_SIZE + 8], eax

    lea eax, [di + 3*PAGE_SIZE + 2*PAGE_SIZE]
    or eax, PAGE_PRESENT | PAGE_WRITE
    mov [di + 2*PAGE_SIZE + 2*8], eax
    ; TODO: Map more than 4kb memory.
    
    ; Build the Page Table from Paga Table Entries (PTE).
    ; Identity mapping 1 Page Table (512 PTE of 4Kb pages) for first 2Mb of memory.
    lea di, [di + 3*PAGE_SIZE]
    mov eax, PAGE_PRESENT | PAGE_WRITE 
    mov ecx, 512*3
.page_table_entry:
    mov [di], eax
    add eax, 0x1000
    add di, 8
    dec ecx
    test ecx, ecx
    jnz .page_table_entry


    call disable_irq


    ; NOTE: Intel manual, "10.8.5 Initializing IA-32e Mode"
    ; Enter long mode:
    ; Enable physical-address extensions (PAE) by setting CR4.PAE (bit 5) = 1.
    ; Also enable CR4.PGE (bit 5) for global pages.
    mov eax, 10100000b
    mov cr4, eax
    ; Load CR3 with the physical base address of the Level 4 page map table (PML4) or Level 5 page map table (PML5).
    mov eax, PAGE_TABLES_ADDR
    mov cr3, eax
    ; Enable IA-32e mode by setting IA32_EFER.LME = 1.
    mov ecx, 0xC0000080
    rdmsr    
    or eax, 0x00000100
    wrmsr
    ; Enable paging by setting CR0.PG = 1. This causes the processor to set the IA32_EFER.LMA bit to 1
    ; Also requires enabling protection by setting CR0.PE = 1.
    mov ecx, cr0
    or ecx,0x80000001
    mov cr0, ecx                    
    ; Load GDT with x64 bit enabled
    lgdt [GDT.Pointer]

    jmp GDT.Code:long_mode             ; Load CS with 64 bit segment and flush the instruction cache


query_memory_map_from_bios:
    ; Clear E820 memory map
    pusha
    mov di, E820_MEMORY_MAP_ADDR
    mov ecx, E820_MEMORY_MAP_SIZE / 4
    xor eax, eax
    cld
    rep stosd
    mov di, E820_MEMORY_MAP_ADDR
    ; NOTE: https://github.com/torvalds/linux/blob/master/arch/x86/include/asm/e820/types.h
    ; base: u64, length: u64, type: u32, acpi: u32
    ; es:di - latest entry
    xor ebp, ebp
    mov di, E820_MEMORY_MAP_ADDR + 4
    
    xor ebx, ebx                ; Continuation
.loop:
    mov eax, 0xE820             ; Function Code
    mov dword [es:di + 20], 1   ; Force ACPI entry
    mov ecx, 24                 ; Entry size
    mov edx, 0x0534D4150        ; Signature ("SMAP")
    int 0x15

    jc .done
    cmp eax, 0x0534D4150
    jne .fail
    jcxz .skip

    cmp cl, 20
    jbe .no_acpi
    test byte [es:di + 20], 1   ; ACPI 3.x ignore bit cleared?
    jz .skip

.no_acpi:
.ok:
    mov ecx, [es:di + 8]
    or ecx, [es:di + 12]
    jz .skip                    ; zero length?
    inc ebp
    add di, 24
.skip:
    test ebx, ebx
    jne .loop
.done:
	mov dword [es:E820_MEMORY_MAP_ADDR], ebp
    BOOT_LOADER_PRINT msg, msg_len
    BOOT_LOADER_PRINT msg, msg_len
    popa
    ret
.fail:
    mov byte [msg + 10], 'E'
    BOOT_LOADER_PRINT msg, msg_len
    jmp $
    popa
    ret

msg:
  db 'Mem map: (_)!'
msg_len equ $ - msg


disable_irq:
    mov al, 0xFF
    out PIC2_DATA, al
    out PIC1_DATA, al
    lidt [IDT]
    ret


ALIGN 4
IDT:
    .Length       dw 0
    .Base         dd 0
; Global Descriptor Table
GDT:
.Null:                          ; null descriptor
    dq 0x0000000000000000
.Code: equ $ - GDT              ; 64-bit code descriptor (exec/read).
    db 0x00, 0x00, 0x00, 0x00   ; ignore base and limit
    db 0x00
    db 10011010b                ; access byte: Present, code or data, executable, readable
    db 0010_0000b               ; flags: long mode
    db 0x00
.Data: equ $ - GDT              ; 64-bit data descriptor (read/write).
    db 0x00, 0x00, 0x00, 0x00   ; ignore base and limit
    db 0x00
    db 10010010b                ; access byte: Present, code or data, writable
    db 0000_0000b               ; flags: none
    db 0x00
ALIGN 4
    dw 0                        ; padding to make the "address of the GDT" field aligned on a 4-byte boundary
.Pointer:
    dw $ - GDT - 1              ; 16-bit Size (Limit) of GDT.
    dq GDT                      ; 32-bit Base Address of GDT.

[BITS 64]      
long_mode:
    mov ax, GDT.Data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    jmp next_sector

times 512 -( $ - $$ ) db 0
next_sector: