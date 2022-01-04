org 0x7c00

entry:
    jmp real_to_protected


; GLOBAL DESCRIPTOR TABLE FOR 32 BIT MODE
; sources http://web.archive.org/web/20190424213806/http://www.osdever.net/tutorials/view/the-world-of-protected-mode
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


; GLOBAL DESCRIPTOR TABLE FOR 64 BIT MODE
; sources  https://github.com/sedflix/lame_bootloader/   https://wiki.osdev.org/Setting_Up_Long_Mode
GDT64:
    .Null: equ $ - GDT64
    dw 0xFFFF
    dw 0
    db 0
    db 0
    db 1
    db 0
    .Code: equ $ - GDT64
    dw 0
    dw 0
    db 0
    db 10011010b         
    db 10101111b         
    db 0                 
    .Data: equ $ - GDT64 
    dw 0                 
    dw 0                 
    db 0                 
    db 10010010b         
    db 00000000b         
    db 0                 
    .Pointer:            
    dw $ - GDT64 - 1     
    dq GDT64

; nasm directive
bits 16 

; 16 bits to 32 bits
real_to_protected:

    ; enable a20 gate
    mov ax, 0x2401
    int 0x15

    ; change video mode
    mov ax, 0x3
    int 0x10

    cli
    lgdt [GDT32.Pointer]

    ; enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; perform long jump
    jmp GDT32.Code:protected_to_long


[bits 32]
protected_to_long:

    ; load registers with GDT data segment offset
    mov ax, GDT32.Data
    mov ds, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax


    ; root table - page-map level-4 table (PM4T)
    mov edi, 0x1000 ; starting address of 0x1000
    mov cr3, edi    ; move base address of page entry into control register 3 (https://wiki.osdev.org/CPU_Registers_x86)

    xor eax, eax    ; set EAX to 0

    mov ecx, 4096
    rep stosd   ; for ECX times, store EAX value at whatever position EDI points to, incrementing/decrementing as you go
                ; https://stackoverflow.com/questions/3818856/what-does-the-rep-stos-x86-assembly-instruction-sequence-do
    
    mov edi, cr3 ; restore original starting address

    ; according to https://wiki.osdev.org/Setting_Up_Long_Mode , this will set up the pointers to the other tables
    ; using an offset of 0x0003 from the destination address supposedly sets the bits to indicate that the page is present
    ;   and is also readable/writeable
    mov dword [edi], 0x2003
    add edi, 0x1000
    mov dword [edi], 0x3003
    add edi, 0x1000
    mov dword [edi], 0x4003
    add edi, 0x1000

    ; at this stage:
    ; PML4T is at 0x1000
    ; PDPT is at 0x2000
    ; PDT is at 0x3000
    ; PT is at 0x4000

    ; used to identity map the first 2MiB (see https://wiki.osdev.org/Setting_Up_Long_Mode)
    mov ebx, 0x00000003
    mov ecx, 512

    .set_entry:
        mov dword [edi], ebx
        add ebx, 0x1000
        add edi, 8
        loop .set_entry

    ; enable pae-paging by setting the appropriate bit in the control register
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    mov ecx, 0xC0000080     ; magic value actually refers to the EFER MSR 
                            ;       -> 'extended feature enable register : model specific register
    rdmsr                   ; read model specific register
    or eax, 1 << 8          ; set long-mode bit (bit 8)
    wrmsr                   ; write back to model specific register

    mov eax, cr0
    or eax, 1 << 31 | 1 << 0         ; set PG bit (31st) & PM bit (0th)
    mov cr0, eax

    ; ^ this has now entered us into 32b compatability submodee

    lgdt [GDT64.Pointer]
    jmp GDT64.Code:real_long_mode

[bits 64]

printer:
    printer_loop:
        lodsb
        or al, al
        jz printer_exit

        or rax, 0x0F00
        mov qword [rbx], rax
        add rbx, 2
        jmp printer_loop

    printer_exit:
        ret

real_long_mode:
    cli

    mov ax, GDT64.Data
    mov ds, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; clears out register RAX - if commented out then weird orange square is drawn at the end of the string
    xor rax, rax 

    mov rsi, boot_msg
    mov rbx, 0xb8000
    call printer

    mov rsi, l_mode
    mov rbx, 0xb80A0
    call printer

    hlt

boot_msg db "Isolate -- University of Lincoln",0
l_mode db "Hello World in 64bit! (long mode)",0
times 510 - ($-$$) db 0
dw 0xaa55
