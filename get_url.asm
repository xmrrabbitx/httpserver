get_url:

        mov rdx, rcx

	;; print requested url
        ;mov rax, 1
        ;mov rdi, 1
        ;mov rsi, rsi
        ;syscall

	cmp byte [rsi+1], " " ;; check if url is just / no chars after /
        je index_file_load ;; load index file    

	mov byte [rsi + rdx], 0 ; null-terminate the URL before using it
        inc rsi ;; move to next 1 byte to pass / of start url

        push rsi ;; store url

	;; append rootPath to url
        mov  rdi, rootPathBuff    ; destination
        mov  rsi, rootPath        ; root path = "/var/www/html"
        mov  rcx, 14              ; length /var/www/html
        rep  movsb                ; copy 14 bytes from rsi to rdi

	pop  rsi                  ; restore url

        mov bl, 14
	jmp concateRegisters
