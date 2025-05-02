format ELF64 executable


fd dq 0
buffer rb 1024

segment readable executable
entry main
main:

	mov rax, 2
	mov rdi, pathDir
	;mov rsi, 0
	;mov rdx, 0
	syscall
	mov [fd], rax

	mov rax, 217
	mov rdi, [fd]
	mov rsi, buffer
	mov rdx, $-buffer
	syscall

    	mov rbx, buffer      
	add rbx, 18
 
 	xor rcx, rcx
	 

find_null:
 
	cmp byte [rbx+rcx], 0                    
        je print_entry                       
        inc rcx  
        jmp find_null 

print_entry:
	
	mov rax,1
	mov rdi,1
	mov rsi,rbx
	mov rdx,rcx
	syscall

	mov rax,1
	mov rdi,1
	mov rsi,del
	mov rdx,1
	syscall
	
next_entry:

	movzx rax, word [rbx - 2]
	add rbx, rax
	
	cmp byte [rbx], 0
	je exit

	xor rcx,rcx	
	
	jmp find_null
	
exit:	

	mov rax,60
	xor rdi, rdi
	syscall


segment readable writeable
pathDir db "listdir",0	
del db 0xa, 0
mssg db "exited!",0
