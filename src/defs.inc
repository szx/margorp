
%define STACK_ADDR 0x6000

%define CODE_SEG 0x8
%define DATA_SEG 0x10

%define PAGE_TABLES_ADDR 0x6000
%define PAGE_TABLES_SIZE 0x4000
%define MEM_HIGH_ADDR 0x1FFFFF

%define PAGE_PRESENT    (1 << 0)
%define PAGE_WRITE      (1 << 1)

%define PIC1 0x20
%define PIC2 0xA0
%define PIC1_COMMAND PIC1
%define PIC1_DATA (PIC1+1)
%define PIC2_COMMAND PIC2
%define PIC2_DATA (PIC2+1)
%define PIC_EOI 0x20