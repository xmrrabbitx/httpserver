get_method:                                                                     
	mov rdx, rsi                                                           
	sub rdx, socketResponse ;; seperate method name lenght from socket response
  	;; test print method name eg: GET or POST
        ;; this method pints socketResponse in length of rdx
        ;; which is subtracted before
        ;mov rax, 1
        ;mov rdi, 1
        ;mov rsi, socketResponse
        ;syscall
	
	;; test print socketResponse
        ;mov rax, 1
        ;mov rdi, 1
        ;mov rsi, socketResponse
        ;mov rdx, r14
        ;syscall

	inc rsi
        xor rcx, rcx
        jmp check_space_url

