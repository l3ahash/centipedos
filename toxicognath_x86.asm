section .multiboot
align 4
	dd 0x1BADB002
	dd 0x00000003
	dd 0xE4524FFB

section .bss
align 16
stack: resb 16384

section .text
align 16
global _start
_start:
    jmp $
