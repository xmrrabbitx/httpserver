
macro write 
	
	
	mov rax, 1
	mov rdi, 1
	mov rsi, mssgTest
	mov rdx, 256
	ret
	
end macro


test_lable:
	write
mssgTest db "exited test!",0
