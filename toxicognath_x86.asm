; =============================================================================
; \(")/ | Variable: multiboot_header
; -( )- | Use: Multiboot looks for this to learn how to boot our OS
; /(_)\ | Help:  https://www.gnu.org/software/grub/manual/multiboot/multiboot.html
; =============================================================================

section .multiboot
align 4
	dd 0x1BADB002
	dd 0x00000003
	dd 0xE4524FFB

; =============================================================================
; \(")/ | Variable: physical_page_bitmap_table
; -( )- | Use: each physical page is represented with a bit in this tablke and
; /(_)\ |       its used for allocation of physical pages
; =============================================================================


section .bss
align 16
physical_page_bitmap_table resb 131072

; =============================================================================
; \(")/ | Variable: first_thread_block
; -( )- | Use: Serves as the first thread descriptor to bootstrap the kernel
; /(_)\ | 
; =============================================================================

section .bss
align 4096
first_thread_block: resb 4096

; =============================================================================
; \(")/ | Variable: gdtp
; -( )- | Use: size and base pointer to gdt
; /(_)\ | Help: https://wiki.osdev.org/Global_Descriptor_Table
; =============================================================================

section .data
align 8
gdtp:
	dw gdt.end - gdt
	dd gdt

; =============================================================================
; \(")/ | Variable: gdt
; -( )- | Use: descriptor of x86 segments and segments access rings
; /(_)\ | Help: https://wiki.osdev.org/Global_Descriptor_Table
; =============================================================================

section .data
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
; \(")/ | Function: _start
; -( )- | Inputs: (none)
; /(_)\ | Outputs: (none)
; =============================================================================

section .text 
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
	; Initialize the physical_page_bitmap_table
	cld 
	mov ecx, (131072 / 4)
	mov edi, physical_page_bitmap_table
	xor eax, eax 
	rep stosd 
    jmp $
.test db 0x07, 0x00

; =============================================================================
; \(")/ | Macro: mutex_lock
; -( )- | Inputts: address of mutex to wait and lock on
; /(_)\ | Outputs: none
; =============================================================================

%macro mutex_lock 1
%%mutex_wait:
	bts dword [mutex_bitmap + (%1 / 32)], (%1 % 32)
	jc %%mutex_wait
%endmacro 

; =============================================================================
; \(")/ | Macro: mutex_unlock
; -( )- | Inputts: address of mutex to unlock
; /(_)\ | Outputs: none
; =============================================================================

%macro mutex_unlock 1
	btr dword [mutex_bitmap + (%1 / 32)], (%1 % 32)
%endmacro 

; =============================================================================
; \(")/ | Variable: mutex_bitmap
; -( )- | Use: bitmap of mutexes to lock and unlock for various purposes.
; /(_)\ |
; =============================================================================

section .data 
mutex_bitmap:
times 256 dd 0

mutex_vga_text_buffer equ 0

; =============================================================================
; \(")/ | Function: debug_terminal_println
; -( )- | Inputts: zero terminated string to print
; /(_)\ | Outputs: none
; =============================================================================

section .text 
debug_terminal_println:
	mutex_lock mutex_vga_text_buffer
	push edi 
	push esi 
	push eax 
	call debug_terminal_scroll
	pop esi 
	mov edi, 0x000B8000
.print_loop:
	lodsb
	or al, al 
	jz .print_loop_exit
	mov ah, 0x0F
	stosw
	jmp .print_loop
.print_loop_exit:
	pop esi 
	pop edi 
	mutex_unlock mutex_vga_text_buffer
	ret

; =============================================================================
; \(")/ | Function: debug_terminal_printlnf
; -( )- | Inputts: zero terminated string to print
; /(_)\ |		   register to print on string 0x07
;       | Outputs: none
; =============================================================================

section .text 
debug_terminal_printlnf:
	mutex_lock mutex_vga_text_buffer
	push edi 
	push esi 
	push ecx
	push eax 
	call debug_terminal_scroll
	pop esi 
	mov edi, 0x000B8000
.print_loop:
	lodsb
	or al, al 
	jz .print_loop_exit
	cmp al, 0x07
	je .print_reg
	mov ah, 0x0F
	stosw
	jmp .print_loop
.print_loop_exit:
	pop ecx
	pop esi 
	pop edi 
	mutex_unlock mutex_vga_text_buffer
	ret
.print_reg:
	mov edx, [esp]
	mov ecx, 8
.print_reg_loop:
	rol edx, 4
	mov eax, edx
	and eax, 0x0000000F
	add eax, 48
	cmp eax, 57
	jle .not_a_letter
	add eax, 7
.not_a_letter:
	mov ah, 0x0F
	stosw
	loop .print_reg_loop
	jmp .print_loop

; =============================================================================
; \(")/ | Function: debug_terminal_scroll
; -( )- | Inputts: none
; /(_)\ | Outputs: none
; =============================================================================

debug_terminal_scroll:
	mutex_lock mutex_vga_text_buffer
	cld 
	push esi
	push edi
	mov edi, 0x000B8000
	mov esi, 0x000B8000 + (80 * 2)
	mov ecx, 80 * 24
	rep movsw  
	pop edi 
	pop esi 
	mutex_unlock mutex_vga_text_buffer
	ret

; =============================================================================
; \(")/ | Function: physical_page_free
; -( )- | Inputts: pointer to page to free
; /(_)\ | Outputs: none
; =============================================================================

section .text 
physical_page_free:
	mov ecx, eax
	shr ecx, 12
	and ecx, 0x1F
	shr eax, 17
	lock bts [physical_page_bitmap_table + eax*4], ecx 
	ret

; =============================================================================
; \(")/ | Function: physical_page_alloc
; -( )- | Inputts: none
; /(_)\ | Outputs: pointer to allocated page
; =============================================================================

section .text 
physical_page_alloc:
	mov ecx, 32764
.dword_find_loop:
	cmp dword [ecx*4 + physical_page_bitmap_table], 0
	jne .dword_found
	loop .dword_find_loop
	mov eax, .no_more_memory_msg
	call kernel_panic
.dword_found:
	bsf edx, dword [ecx*4 + physical_page_bitmap_table]
	jz .dword_find_loop
	lock btr [ecx*4 + physical_page_bitmap_table], edx 
	jnc .dword_found
	mov eax, ecx 
	shl eax, 17
	shl edx, 12
	add eax, edx
	ret 
section .data 
.no_more_memory_msg db "NO MORE MEMORY UHOH!!!!", 0

; =============================================================================
; \(")/ | Function: kernel_panic
; -( )- | Inputts: pointer to error message zero terminated
; /(_)\ | Outputs: none
; =============================================================================

section .text 
kernel_panic:
	cli 
	cld 
	mov edx, eax 
	mov edi, 0x000B8000
	mov esi, .msg 
.kernel_print_loop:
	lodsb 
	or al, al 
	jz .kernel_print_loop_exit
	mov ah, 0xF0
	stosw 
	jmp .kernel_print_loop
.kernel_print_loop_exit:
	mov esi, edx 
.print_loop:
	lodsb
	or al, al 
	jz .print_loop_exit
	mov ah, 0xF0
	stosw
	jmp .print_loop 
.print_loop_exit:
	jmp .print_loop_exit
section .data
.msg db "KERNEL PANIC... ", 0

; =============================================================================
; \(")/ | Struct: thread_block
; -( )- | Use: stores information about a thread including register state
; /(_)\ |
; =============================================================================

thread_block.stack_top    equ 2048 
thread_block.fx_save_base equ 2048 ; base used in fx_save for saving FPU/MMX reg
