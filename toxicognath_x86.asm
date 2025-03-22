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
; o    o                 | Variable: physical_page_bitmap_table
;  \__/                  | Use: each physical page is represented with a bit in 
;  /oo\                  |  this table and its used for allocation of physical
;  \()/                  |  pages
;  |~~|                  |
;  |~~|                  |
;  |~~|               /\ |	
;  \~~\              /\/ | 
;   \~~\____________/\/  | 
;    \/ | | | | | | \/   | 
;     ~~~~~~~~~~~~~~~    |
; =============================================================================

section .bss
align 16
physical_page_bitmap_table resb 131072

; =============================================================================
; =============================================================================

section .bss
align 4096
first_thread_block: resb 4096

; =============================================================================
; Art by Hayley Jane Wakenshaw| Variable: GDTP
;    .----.   @   @           | Use: 16 bit size and 32 bit base for GDT
;   / .-"-.`.  \v/            | Help: https://wiki.osdev.org/Global_Descriptor_Table
;   | | '\ \ \_/ )            |
; ,-\ `-.' /.'  /             |
; '---`----'----'             |
; =============================================================================

section .data
align 8
gdtp:
	dw gdt.end - gdt
	dd gdt

; =============================================================================
; Art by Graeme Porter | Variable: GDT
; _ .                  | Use: x86 requires this table for access rings
; \|                   | Help: https://wiki.osdev.org/Global_Descriptor_Table
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
;⠀⢸⠂⠀⠀⠀⠘⣧⠀⠀⣟⠛⠲⢤⡀⠀⠀⣰⠏⠀⠀⠀⠀⠀⢹ | Function: debug_terminal_println
;⠀⡿⠀⠀⠀⠀⠀⠈⢷⡀⢻⡀⠀⠀⠙⢦⣰⠏⠀⠀⠀⠀⠀⠀⢸⠀| Use: Scrolls debug terminal and prints a 
;⠀⡇⠀⠀⠀⠀⠀⠀⢀⣻⠞⠛⠀⠀⠀⠀⠻⠀⠀⠀⠀⠀⠀⠀⢸⠀ |       line
;⠀⡇⠀⠀⠀⠀⠀⠀⠛⠓⠒⠓⠓⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀ | Inputs:
;⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠀  |    - Zero terminated string to print
;⠀⢿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣀⣀⠀⠀⢀⡟⠀ | Outputs:
;⠀⠘⣇⠀⠘⣿⠋⢹⠛⣿⡇⠀⠀⠀⠀⣿⣿⡇⠀⢳⠉⠀⣠⡾⠁|    - None
;⣦⣤⣽⣆⢀⡇⠀⢸⡇⣾⡇⠀⠀⠀⠀⣿⣿⡷⠀⢸⡇⠐⠛⠛⣿|
;⠹⣦⠀⠀⠸⡇⠀⠸⣿⡿⠁⢀⡀⠀⠀⠿⠿⠃⠀⢸⠇⠀⢀⡾⠁|
;⠀⠈⡿⢠⢶⣡⡄⠀⠀⠀⠀⠉⠁⠀⠀⠀⠀⠀⣴⣧⠆⠀⢻⡄⠀ |
;⠀⢸⠃⠀⠘⠉⠀⠀⠀⠠⣄⡴⠲⠶⠴⠃⠀⠀⠀⠉⡀⠀⠀⢻⡄ |
;⠀⠘⠒⠒⠻⢦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⠞⠛⠒⠛⠋⠁ |
;⠀⠀⠀⠀⠀⠀⠸⣟⠓⠒⠂⠀⠀⠀⠀⠀⠈⢷⡀⠀⠀⠀⠀⠀⠀⠀ |
;⠀⠀⠀⠀⠀⠀⠀⠙⣦⠀⠀⠀⠀⠀⠀⠀⠀⠈⢷⠀⠀⠀⠀⠀⠀⠀
;⠀⠀⠀⠀⠀⠀⠀⣼⣃⡀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣆⠀⠀⠀⠀⠀⠀
;⠀⠀⠀⠀⠀⠀⠀⠉⣹⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⠀⠀⠀⠀⠀⠀
;⠀⠀⠀⠀⠀⠀⠀⠀⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡆⠀⠀⠀⠀⠀
; =============================================================================

section .text 
debug_terminal_println:
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
	ret

; =============================================================================⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
;⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠛⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀    
;⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⠛⢠⡀⠸⣆⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀    |
;⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡼⡁⢰⣋⡇⠀⡿⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⠤⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀    |
;⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡼⠁⣏⠉⠛⠳⢤⣟⠀⢧⠀⠀⣀⣤⣠⣤⣄⣀⠀⠀⢷⠀⠀⠈⠙⠢⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀   |
;⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡔⠃⣀⠘⢆⣀⠀⠀⠉⠀⠘⠚⠉⠀⠀⢀⡀⠀⢸⠇⣀⢸⡀⠀⠀⠀⠀⠈⢧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀   |
;⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⠙⡾⠟⣷⠂⠉⠀⠀⠀⠀⠀⠀⠀⢶⢚⣹⠃⢠⡏⠀⡏⠹⠃⠀⠀⠀⠀⠀⢸⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀   |
;⢀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣼⠇⣰⠀⠀⠀⠠⠶⠳⣦⠀⠀⠀⠘⠲⠃⢠⠟⠁⠀⡏⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀   |
;⠈⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠏⡟⠷⠟⠁⠀⠀⣴⡆⠀⢸⡇⠀⠀⢠⣄⡴⠏⠀⡀⢰⠇⠀⠀⠀⠀⠀⠀⢠⡾⠚⠋⠉⠉⢳⡀⠀⠀⠀⠀⠀ |
;⠀⢹⡌⠙⢷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⢧⡐⠶⠄⠀⠀⠻⣃⡀⠸⡷⠀⠀⠀⠹⣆⠀⢀⡿⡏⠀⠀⠀⠀⠀⠀⣠⡾⠀⠀⠀⢀⡴⠟⠁⠀⠀⠀⠀⠀  |
;⠀⠀⢷⠀⠀⠻⣷⣄⠀⠀⠀⠀⠀⠀⢀⣀⡀⠀⠙⠦⣤⣀⡀⠀⠘⠿⠇⠀⣤⠴⣶⣞⣁⣠⣾⡀⠀⠀⣤⣠⣴⠶⢾⣁⣧⠀⠀⠀⠈⢧⡤⠖⠚⠦⣄⡀⠀|
;⠀⠀⠘⡇⠀⠀⠈⠻⣷⡀⠀⠀⣠⢾⡉⢉⡍⠙⠳⣶⢟⣯⣭⠿⠷⣤⡀⣠⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠛⠚⠻⠀⠀⠀⠀⠈⣇⠀⠀⠀⠀⠙⣦ |
;⠀⠀⠀⢹⡀⠀⠀⠀⢿⣧⠀⠀⢧⣸⡀⠘⣇⣴⠀⠀⢘⠛⠛⠀⣰⠊⠻⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣤⣄⣄⡓⣶⠏
;⠀⠀⠀⠀⣧⠀⠀⠀⠈⣿⣆⣠⣤⣭⡭⠿⣹⣿⡋⠉⠛⠓⠒⠴⠃⠀⠀⠀⠀⢠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣇⠈⠙⠛⠁⠀
;⠀⠀⠀⠀⠈⠳⣄⠀⠀⠸⣿⠉⠀⠈⢻⠞⠙⡾⠁⡀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣀⣀⣀⣀⣀⣀⣀⣬⠷⠶⠤⢤⣤⣄⣀⣀⣤⣄⡀⣰⠤⢽⠆⠀⠀⠀⠀
;⠀⠀⠀⠀⠀⠀⠈⠳⣄⠀⢿⣧⠀⠀⠘⠷⠾⠷⣼⣅⣀⣀⠀⠀⠀⠀⠀⠀⠸⡅⠀⠀⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠏⠀⠀⠀⠀⠀⠀⠀
;⠀⠀⠀⠀⠀⠀⠀⠀⠘⢧⡈⡿⣄⣀⣀⣀⣀⣀⣈⣳⣍⠉⠉⠛⢿⡛⢦⡼⠛⠛⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
;⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⠻⠶⠿⠿⠷⠷⠿⠿⠾⠶⠶⠶⠶⠿⠟⠁⠀⠀
; She is just like me fr fr
; Function: debug_terminal_printlnf
; Use: prints string and if it hits 0x07 it prints in hex the second argument
; Inputs:
;	- zero terminated string
;   - register to print
; Outputs: none⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
; =============================================================================

section .text 
debug_terminal_printlnf:
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
;                       .-.   | Function: debug_terminal_scroll
;        .-""`""-.    |(@ @)  | Use: Scrolls the terminal one line
;     _/`oOoOoOoOo`\_ \ \-/   | Inputs: none
;    '.-=-=-=-=-=-=-.' \/ \   |
;jgs   `-=.=-.-=.=-'    \ /\  | Outputs: none
;         ^  ^  ^       _H_ \ |
; =============================================================================

debug_terminal_scroll:
	cld 
	push esi
	push edi
	mov edi, 0x000B8000
	mov esi, 0x000B8000 + (80 * 2)
	mov ecx, 80 * 24
	rep movsw  
	pop edi 
	pop esi 
	ret

; =============================================================================
;           ___                     | Function: physical_page_free
;         .';:;'.                   | Use: frees a physical page for allocation
;        /_' _' /\   __             | Inputs: 	
;        ;a/ e= J/-'"  '.           |     - pointer to base of page to free
;        \ ~_   (  -'  ( ;_ ,.      | Outputs: none  
;         L~"'_.    -.  \ ./  )     | 
;         ,'-' '-._  _;  )'   (     |
;       .' .'   _.'")  \  \(  |     |
;      /  (  .-'   __\{`', \  |     |
;     / .'  /  _.-'   "  ; /  |     |
;    / /    '-._'-,     / / \ (     |
; __/ (_    ,;' .-'    / /  /_'-._  |
;`"-'` ~`  ccc.'   __.','     \j\L\ |
;                 .='/|\7           |
;     snd                           |
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
;                          `-.                | Function: physical_page_alloc
;              -._ `. `-.`-. `-.              | Use: allocates a physical page
;             _._ `-._`.   .--.  `.           | Inputs: none
;          .-'   '-.  `-|\/    \|   `-.       | Outputs: 
;        .'         '-._\   (o)O) `-.         | 	- pointer to page allocated
;       /         /         _.--.\ '. `-. `-. |
;      /|    (    |  /  -. ( -._( -._ '. '.   |
;     /  \    \-.__\ \_.-'`.`.__'.   `-, '. .'|
;     |  /\    |  / \ \     `--')/  .-'.'.'   |
; .._/  /  /  /  / / \ \          .' . .' .'  |
;/  ___/  |  /   \ \  \ \__       '.'. . .    |
;\  \___  \ (     \ \  `._ `.     .' . ' .'   |
; \ `-._\ (  `-.__ | \    )//   .'  .' .-'    |
;  \_-._\  \  `-._\)//    ""_.-' .-' .' .'    |
;    `-'    \ -._\ ""_..--''  .-' .'          |
;            \/    .' .-'.-'  .-' .-'         |
;                .-'.' .'  .' .-'             |
;"PRECIOUSSSS!! What has the nasty Bagginsess |
;           got in it's pocketssss?"          |
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
; Art by Morfina                | Function: kernel_panic
; _________________.---.______  | Use: panics the mcducking kernel sargent
;(_(______________(_o o_(____() | Inputs:
;        mrf  .___.'. .'.___.   |    - pointer to message zero terminated
;             \ o    Y    o /   | 
;              \ \__   __/ /    | Outputs: none 
;               '.__'-'__.'     | THIS LITERALLY DOESNT RETURN KIDDIE
;                   '''         |
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
;    \_/-.--.--.--.--.--.  | Struct: thread_block
;    (")__)__)__)__)__)__) | Use: Stores the state and information for a thread
; jgs  ^ "" "" "" "" "" "" |
; =============================================================================

thread_block.stack_top    equ 2048 
thread_block.fx_save_base equ 2048 ; base used in fx_save for saving FPU/MMX reg
