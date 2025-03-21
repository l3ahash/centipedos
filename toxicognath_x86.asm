; =============================================================================
; o       o              | Variable: Multiboot header
;  \_____/               | Use: Multiboot looks for this to learn how to boot
;  /=O=O=\     _______   |       our OS
; /   ^   \   /\\\\\\\\  | Help: https://www.gnu.org/software/grub/manual/multiboot/multiboot.html
; \ \___/ /  /\   ___  \ |       (I know this doc is outdated but it helped me)
; \_ V _/  /\   /\\\\  \ |
;   \  \__/\   /\ @_/  / |
;    \____\____\______/  |
; =============================================================================

section .multiboot
align 4
	dd 0x1BADB002
	dd 0x00000003
	dd 0xE4524FFB

; =============================================================================
section .bss
; =============================================================================
align 4096
first_thread_block: resb 4096

; =============================================================================
section .data
; =============================================================================

; =============================================================================
; Art by Hayley Jane Wakenshaw| Variable: GDTP
;    .----.   @   @           | Use: 16 bit size and 32 bit base for GDT
;   / .-"-.`.  \v/            | Help: https://wiki.osdev.org/Global_Descriptor_Table
;   | | '\ \ \_/ )            |
; ,-\ `-.' /.'  /             |
; '---`----'----'             |
; =============================================================================

align 8
gdtp:
	dw gdt.end - gdt
	dd gdt

; =============================================================================
; Art by Graeme Porter | Variable: GDT
; _ .                  | Use: x86 requires this table for access rings
; \|                   | Help: https://wiki.osdev.org/Global_Descriptor_Table
; =============================================================================

align 8
gdt:
	dq 0x0000000000000000 ; 0x0000 null segment
	dq 0x00CF9A000000FFFF ; 0x0008 kernel code
	dq 0x00CF92000000FFFF ; 0x0010 kernel data
	dq 0x00CFFA000000FFFF ; 0x0018 user code
	dq 0x00CFF2000000FFFF ; 0x0020 user data
	dq 0x0000000000000000 ; 0x0028 TODO TSS
gdt.end:

; =============================================================================
section .text
; =============================================================================

; =============================================================================
; \(")/ | Function: _start
; -( )- | Inputs: (none)
; /(_)\ | Outputs: (none)
; =============================================================================

align 16
global _start
_start:
	; clear interrupts in case bootloader didnt for some reason, prevents interrupts being done on idt/gdt mid modification (we also need to wait to configure the PIC)
	cli
	; Load new gdt since we have zero clue what fuck ass one bootloader uses
	lgdt [gdtp]
	mov ax, 0x0010
	mov ds, ax 
	mov es, ax 
	mov ss, ax 
	mov fs, ax 
	mov gs, ax 
	jmp 0x0008:.reset_cs
	nop
.reset_cs:
	; Stack, self explanatory
	mov esp, first_thread_block + thread_block.stack_top
	mov byte [0xB8000], 'A'
    jmp $

; =============================================================================
;    \_/-.--.--.--.--.--.  | Struct: thread_block
;    (")__)__)__)__)__)__) | Use: Stores the state and information for a thread
; jgs  ^ "" "" "" "" "" "" |
; =============================================================================

thread_block.stack_top    equ 2048 
thread_block.fx_save_base equ 2048 ; base used in fx_save for saving FPU/MMX reg
