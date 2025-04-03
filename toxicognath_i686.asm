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
; \(")/ | Variable: first_process_block
; -( )- | Use: Serves as the first process descriptor to bootstrap the kernel
; /(_)\ | 
; =============================================================================

section .bss
align 4096
first_process_block: resb 4096

; =============================================================================
; \(")/ | Variable: gdt
; -( )- | Use: descriptor of x86 segments and segments access rings
; /(_)\ | Help: https://wiki.osdev.org/Global_Descriptor_Table
; =============================================================================

section .data
align 8
gdtp:
	dw gdt.end - gdt
	dd gdt
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
; \(")/ | Variable: idt
; -( )- | Use: descriptor of x86 interrupt handling shenanigans
; /(_)\ | Help: https://wiki.osdev.org/Interrupt_Descriptor_Table
; =============================================================================

section .data 
align 8
idtp:
	dw idt.end - idt
	dd idt 
align 8
idt:
	times 64 dq 0
idt.end:

idt_data:
	dd .not_present ; int 0x00
	dd .not_present ; int 0x01
	dd .not_present ; int 0x02
	dd .not_present ; int 0x03
	dd .not_present ; int 0x04
	dd .not_present ; int 0x05
	dd .not_present ; int 0x06
	dd .not_present ; int 0x07
	dd .not_present ; int 0x08
	dd .not_present ; int 0x09
	dd .not_present ; int 0x0A
	dd .not_present ; int 0x0B
	dd .not_present ; int 0x0C
	dd .not_present ; int 0x0D
	dd .not_present ; int 0x0E
	dd .not_present ; int 0x0F
	dd .not_present ; int 0x10
	dd .not_present ; int 0x11
	dd .not_present ; int 0x12
	dd .not_present ; int 0x13
	dd .not_present ; int 0x14
	dd .not_present ; int 0x15
	dd .not_present ; int 0x16
	dd .not_present ; int 0x17
	dd .not_present ; int 0x18
	dd .not_present ; int 0x19
	dd .not_present ; int 0x1A
	dd .not_present ; int 0x1B
	dd .not_present ; int 0x1C
	dd .not_present ; int 0x1D
	dd .not_present ; int 0x1E
	dd .not_present ; int 0x1F
	dd .not_present ; int 0x20
	dd .not_present ; int 0x21
	dd .not_present ; int 0x22
	dd .not_present ; int 0x23
	dd .not_present ; int 0x24
	dd .not_present ; int 0x25
	dd .not_present ; int 0x26
	dd .not_present ; int 0x27
	dd .not_present ; int 0x28
	dd .not_present ; int 0x29
	dd .not_present ; int 0x2A
	dd .not_present ; int 0x2B
	dd .not_present ; int 0x2C
	dd .not_present ; int 0x2D
	dd .not_present ; int 0x2E
	dd .not_present ; int 0x2F
	dd .not_present ; int 0x30
	dd .not_present ; int 0x31
	dd .not_present ; int 0x32
	dd .not_present ; int 0x33
	dd .not_present ; int 0x34
	dd .not_present ; int 0x35
	dd .not_present ; int 0x36
	dd .not_present ; int 0x37
	dd .not_present ; int 0x38
	dd .not_present ; int 0x39
	dd .not_present ; int 0x3A
	dd .not_present ; int 0x3B
	dd .not_present ; int 0x3C
	dd .not_present ; int 0x3D
	dd .not_present ; int 0x3E
	dd .not_present ; int 0x3F

.not_present        equ 0x00000000 
.interrupt_software equ 0xEE000000 
.trap_gate          equ 0x8F000000 
.interrupt_gate     equ 0x8E000000 

; =============================================================================
; \(")/ | Variable: current_thread_block 
; -( )- | Use: stores a pointer to the current thread block
; /(_)\ | 
; =============================================================================

section .data 
current_thread_block dd first_thread_block

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
	cld ; when does one even use the reverse direction for string instructions?

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

	; Initialize the physical_page_bitmap_table
	mov ecx, (131072 / 4) ; 
	mov edi, physical_page_bitmap_table
	xor eax, eax 
	rep stosd

	; initializes interrupt descriptor table from compressed format (because nasm label nonesense)
	mov ecx, (63*4)
.idt_fill_loop:
	mov eax, [idt_data + ecx] ; grab compressed entry
	mov word [idt + ecx*2 + 0], ax ; low 16 bits offset
	mov word [idt + ecx*2 + 2], 0x0008 ; kernel code segment
	mov byte [idt + ecx*2 + 4], 0x00 ; reserved byte
	rol eax, 8
	mov byte [idt + ecx*2 + 5], al ; descriptor byte
	rol eax, 8
	xor ah, ah 
	mov word [idt + ecx*2 + 6], ax ; offset top 16 bits 
	and eax, 0x00FFFFFF
	sub ecx, 4
	jns .idt_fill_loop

	; Configures PIC 
	mov al, 0x11 ; put PIC1 in config mode
	out 0x20, al 
	mov al, 0x11 ; put PIC2 in config mode
	out 0xA0, al 
	mov al, 32   ; PIC1 interrupt offset
	out 0x21, al 
	mov al, 40   ; PIC2 interrupt offset
	out 0xA1, al 
	mov al, 4    ; Tell PIC1 where PIC2 is connected
	out 0x21, al
	mov al, 2    ; Tell PIC2 where PIC1 is connected
	out 0xA1, al

	; Loads idt
	lidt [idtp]
	
	; Sets this up as an actual process
	mov edi, first_process_block + process_block.name ; place process name in struct (this will change to init once process bootstrap starts)
	mov esi, .process_name  
	mov ecx, 16
	rep movsb 
	
	; Sets this up as an actual thread
	mov esp, first_thread_block + thread_block.stack_top
	mov dword [first_thread_block + thread_block.process_block], first_process_block
	mov dword [first_thread_block + thread_block.process_thread_count], 0
	
	; Prints debug message to show kernel initialized
	mov eax, .kernel_init_msg
	call debug_message
	
	; Put init processes name here before transfering control to init
	mov edi, first_process_block + process_block.name 
    mov esi, .init_process_name
	mov ecx, 16
	rep movsb 

	jmp $

section .data 
.process_name      db "toxicognath_686", 0
.init_process_name db "init           ", 0
.kernel_init_msg   db "kernel init                                              "        

; =============================================================================
; \(")/ | Function: debug_message
; -( )- | Inputs:  eax - pointer to 56 byte message to send
; /(_)\ | Outputs: none
;       | Clobbers: ax, ecx, esi, edi, cf
;       | Requirments: cld
; =============================================================================

section .text 
debug_message:
	; mutex wait and lock
.lock_wait:
	lock bts dword [.lock_word], 1
	jnc .lock_wait

	; scroll the terminal a line
	mov esi, 0xB8000 + (80 * 2)
	mov edi, 0xB8000
	mov ecx, (80 * 24)
	rep movsw

	; puts message in terminal 
	mov esi, eax 
	mov edi, 0x000B8000 + 3840 + (24 * 2) ; we want this collumn 48-79
	mov al, 0x0F ; we want white on black
	mov ecx, 56 ; 56 byte message max 
.debug_message_loop:
	movsb ; put byte of message
	stosb ; put byte of color
	loop .debug_message_loop
	
	; puts process name in terminal
	mov ecx, 16 ; 16 byte name max
	mov esi, [current_thread_block] ; funds the actual process name
	mov esi, [esi + thread_block.process_block]
	mov edi, 0x000B8000 + 3840 + (1 * 2) ; we want this column 1-16
	mov al, 0x0B ; we want blue on black
.process_name_loop:
	movsb ; put byte of name
	stosb ; put byte of color
	loop .process_name_loop

	; puts thread id in terminal
	mov ecx, 4 ; thread ids is 16 bit, so 4 hex digits
	mov edi, 0xB8000 + 3840 + (18*2) ; we want this column 36-39
	mov esi, [current_thread_block] ; load si with actual thread id
	mov si, [esi + thread_block.process_thread_count]
.thread_id_loop: ; loop through each nibble
	rol si, 4 ; mov top 4 bits to bottom 4 bits (as we print numbers msb to lsb) this puts most significant nibble always in the bottom 4 bits of si
	mov ax, si 
	and ax, 0x000F ; isolate ax to contain nibble in si 
	add ax, 48 ; add 48 to map to ascii '0' through '9'
	cmp ax, 58 ; if greater than '9' its a letter
	jl .not_letter
	add ax, 7 ; map digits greater than '9' to 'A' through 'F'
.not_letter:
	add ax, 0x0D00 ; add blue on black backround
	stosw ; put byte of thread id and byte of color
	loop .thread_id_loop

	; place the punctuation
	mov word [0xB8000 + 3840 + (0 * 2)], 0x0F00 + '['
	mov word [0xB8000 + 3840 + (16 * 2)], 0x0F00 + ']'
	mov word [0xB8000 + 3840 + (17 * 2)], 0x0F00 + '('
	mov word [0xB8000 + 3840 + (22 * 2)], 0x0F00 + ')'
	mov word [0xB8000 + 3840 + (23 * 2)], 0x0F00 + ' ' 

	; mutex free
	lock btr dword [.lock_word], 1
	ret

section .data
.lock_word dd 0

; =============================================================================
; \(")/ | Struct: thread_block
; -( )- | Use: stores information about a thread including register state
; /(_)\ |
; =============================================================================

thread_block.stack_top            equ 2048 ; 
thread_block.fx_save_base         equ 2048 ; base used in fx_save for saving FPU/MMX reg (512 bytes)
thread_block.process_block        equ 2560 ; pointer to the parent process block for this thread (4 bytes)
thread_block.process_thread_count equ 2564 ; the thread number withen the process (4 bytes)

; =============================================================================
; \(")/ | Struct: process_block
; -( )- | Use: stores information about a process
; /(_)\ |
; =============================================================================

process_block.name                equ 0    ; stores the name of the process (do not move too much relys on this location) (16 bytes)