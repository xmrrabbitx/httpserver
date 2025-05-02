
macro write 
	
	
	mov rax, 1
	mov rdi, 1
	mov rsi, mssgTest
	mov rdx, 256
	ret
	
end macro


test2_lable:
	write

