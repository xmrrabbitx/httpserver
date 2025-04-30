get_currentDir:

	push rdi 
        push rsi
	
	mov rax, 79
	mov rdi, currentDir
	mov rsi, 256
	syscall
	
	pop rdi
	pop rsi
	ret

segment readable writeable
currentDir rb 256
