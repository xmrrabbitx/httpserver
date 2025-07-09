get_url:

    mov rdx, rcx

	;; print requested url
    ;mov rax, 1
    ;mov rdi, 1
    ;mov rsi, rsi
    ;syscall

	;;jmp pass
	xor r8, r8
	mov r8, 0

check_http:
	cmp byte [rsi], "h"
	jne pass
	cmp byte [rsi+1], "t"
	jne pass
	cmp byte [rsi+2], "t"
	jne pass
	cmp byte [rsi+3], "p"
	jne pass
	cmp byte [rsi+4], ":"
	jne pass
	cmp byte [rsi+5], "/"
	jne pass
	cmp byte [rsi+6], "/"
	jne pass
	add rsi, 7

check_slash:
	
	cmp byte [rsi+r8], "/"
	je htt_route
	inc r8
	jmp check_slash
	
htt_route:	
	add rsi, r8	
	xor r8, r8
	mov r8, 0
	jmp check_uri
check_uri:
	cmp byte [rsi+r8], " "
	je end_url 
	inc r8	
	jmp check_uri
end_url:
	mov byte [rsi + r8], 0
	inc rsi
	jmp cont
pass:

    cmp byte [rsi+1], " " ;; check if url is just / no chars after /
    je index_file_load ;; load index file  

	mov byte [rsi + rdx], 0 ; null-terminate the URL before using it
    inc rsi ;; move to next 1 byte to pass / of start url

cont:
    push rsi ;; store url
	
	;; append rootPath to url
    mov  rdi, rootPathBuff    ; destination
    mov  rsi, rootPath        ; root path = "/var/www/html"
    mov  rcx, 14              ; length /var/www/html
    rep  movsb                ; copy 14 bytes from rsi to rdi

	pop  rsi                  ; restore url

    mov bl, 14
	jmp concateRegisters
