www_data_permission:
	;; set/change group id to 33 which is www-data group id
	mov rax, 106 ;; setgid syscall
	mov rdi, 33
	syscall

	;; set/change user id to 33 which is www-data id
	mov rax, 105 ;; setuid syscall
	mov rdi, 33
	syscall
	ret

