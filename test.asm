print_example:

	push rdi 
        push rsi
    	push rdx
	
	mov rax, 1
	mov rdi, 1
	mov rsi, example
	mov rdx, example_len
	syscall
	
	pop rdx
	pop rdi
	pop rsi
	ret

segment readable writeable
example db "example test",10,0
example_len = $ - example
