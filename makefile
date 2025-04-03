build: toxicognath_i686.bin
run_i686: toxicognath_i686.bin
	qemu-system-i386 -kernel toxicognath_i686.bin
toxicognath_i686.bin: toxicognath_i686.o 
	ld -m elf_i386 -T kernel_linker_i686.ld $^ -o $@ 
%_i686.o: %_i686.asm
	nasm -felf32 $< -o $@
clean:
	rm -f *.o *_i686