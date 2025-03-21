build: toxicognath_x86.bin
run_x86: toxicognath_x86.bin
	qemu-system-i386 -kernel toxicognath_x86.bin
toxicognath_x86.bin: toxicognath_x86.o 
	ld -m elf_i386 -T kernel_linker_x86.ld $^ -o $@
%_x86.o: %_x86.asm
	nasm -felf32 $< -o $@
clean:
	rm -f *.o *_x86