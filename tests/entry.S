//credit: https://wiki.osdev.org/RISC-V_Bare_Bones
//
.section .init

.option norvc

.type _start, @function
.global _start
_start:
	.cfi_startproc
	
.option push
.option norelax
	la gp, global_pointer
.option pop
	
	/* Setup stack */
	la sp, stack_top
	
	/* Clear the BSS section */
	la t5, bss_start
	la t6, bss_end
bss_clear:
	sw zero, (t5)
	addi t5, t5, 8
	bltu t5, t6, bss_clear
	
	j main
	
	.cfi_endproc

.end
