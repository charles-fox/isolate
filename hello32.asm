; 32 BIT BOOTLOADER

; NASM directives
; https://www.nasm.us/xdoc/2.13.03/html/nasmdoc6.html
bits 16
org 0x7c00

entry:
    jmp boot


; GLOBAL DESCRIPTOR TABLE FOR 32 BIT MODE
; sources  http://web.archive.org/web/20190424213806/http://www.osdever.net/tutorials/view/the-world-of-protected-mode
GDT32:
    .Null: equ $ - GDT32
    dq 0            ; defines 32 bits of zeroes for the null entry
    .Code: equ $ - GDT32
    dw 0xFFFF       ; segment limit
    dw 0            ; base address
    db 0            ; base address (again)
    
    ; from right to left
    ; 0 = access flag (set to 1 on first access by the cpu)
    ; 1 = readable segment
    ; 0 = 'conforming' - is less privelleged code allowed to run this segment
    ; 1 = code or data segment (1 = code, 0 = data)
    ; 1 = segment is code/data segment? (true(1)/false(0))
    ; 00 = privilege level (00 = ring 0/kernel/os)
    ; 1 = is the segment present?
    db 0b10011010

    ; from right to left
    ; 1111 (0xF) = last bits in the segment limit
    ; 0 = 'available to system programmers' but apparently the cpu ignores it anyway
    ; 0 = intel reserved, should always be zero
    ; 1 = size - 1 = 32bit, 0 = 16bit
    ; 1 = granularity - 0: access in 1 byte blocks, 1: access in 4KiB blocks
    ;           TODO: what's the math for enabling the 4GB limit???
    db 0b11001111

    db 0            ; last remaining 8 bits on the base address
    .Data: equ $ - GDT32
    dw 0xFFF        ; --|
    dw 0            ;   | - identical to code segment
    db 0            ; --|

    ; right to left
    ; 0 - access flag
    ; 1 - write access?
    ; 0 - segment expands upwards from the base address
    ; 0 - code(1)/data(0) segment
    ; 1 - is a code/data segment?
    ; 00 - privilege level (ring 0)
    ; 1 - is the segment present?
    db 0b10010010

    ; right to left
    ; 1111 - last bits in the segment limit
    ; 0 - 'available to system programmers'?
    ; 0 - intel reserved, should always be zero
    ; 1 - 'big'? should be set to allow for 4GB
    ; 1 - granularity
    db 0b11001111
    
    db 0
    .Pointer:
    dw $ - GDT32 - 1
    dd GDT32


boot:
    ; enabling a20 gate
    mov ax, 0x2401
    int 0x15

    ; changing to text mode (http://www.brackeen.com/vga/basics.html)
    mov ax, 0x3
    int 0x10

    ; disable interrupts
    cli

    ; load global descriptor table (gdt) with a pointer to the descriptor
    lgdt [GDT32.Pointer] 

    ; enabling protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; long jump
    jmp GDT32.Code:now_protected_boot

; NASM directive
bits 32

printer:
    printer_loop:
        lodsb
        or al, al
        jz printer_end
        or eax, 0x0F00
        mov word [ebx], ax
        add ebx, 2
        jmp printer_loop

    printer_end:
        ret


now_protected_boot:
    mov ax, GDT32.Data      ; --|
    mov ds, ax              ;   |
    mov ss, ax              ;   | - loading up the segment registers with the data segment position
    mov fs, ax              ;   |
    mov gs, ax              ; --|

    ; since we are in protected mode, we can no longer use bios interrupts to perform functions
    ; so we write directly to VGA memory (starting at 0xb8000)
    mov esi, boot_msg
    mov ebx, 0xb8000
    call printer

    mov esi, mode_msg
    mov ebx, 0xb80A0
    call printer

    hlt

boot_msg    db "Isolate -- University of Lincoln", 0
mode_msg    db "Hello World in 32bit! (protected mode)", 0

times 510 - ($-$$) db 0
dw 0xaa55
