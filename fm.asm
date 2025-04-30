format ELF64 executable

fd dq 0
buffer rb 1024


include "helper.asm"


segment readable executable
entry main
main:

	call get_currentDir
		
	mov rax, 79
	mov rdi, currentDir
	mov rsi, 256
	syscall

	mov rax, 2
	mov rdi, currentDir
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
	;;je check_dots
	je print_entry

	inc rcx  
        jmp find_null 

check_dots:
	cmp byte [rbx+1], '.'
	je next_entry
	jmp print_entry

print_entry:

	push rcx
	mov [ascii_digit], cl   
	add byte [ascii_digit], '0' 
    	push rdi
	push rsi
	push rdx

	mov rax, 1       
    	mov rdi, 1         
    	mov rsi, ascii_digit   
    	mov rdx, 2        
    	syscall 
	
	pop rdi
	pop rsi
	pop rdx
	pop rcx

	cmp rcx, 2
	je check_dots	
	cmp rcx, 3
	je check_dots	


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
;;pathDir db "listdir",0	
del db 0xa, 0
mssg db "exited!",0
dotMsg db "dots detected!",0
ascii_digit db 0, 0xA
