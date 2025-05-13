format ELF64 executable


SYS_WRITE = 1
SYS_READ = 0
SYS_SOCKET = 41
SYS_CONNECT = 42
SYS_BIND = 49
SYS_LISTEN  = 50
SYS_SETSOCKOPT = 54
SYS_ACCEPT = 43
SYS_OPEN = 2 ;; open file
SYS_EXEC = 59 ;; exec syscall

af_inet = 2
af_unix = 1
domain = af_inet ;; af_inet = 2
type = 1 
protocol = 0 ;; default value is 0
phpfpmDomain = af_unix ;; af_unix = 1 


fd dq 0
bufferHtml rb 8192
socketResponse rb 1024
bytesReadHtml dq 0
fcgi_response_buffer rb 1024
fcgiRespBuffer rb 1024
optval dd 1  ; int 1 for SO_REUSEADDR


;;creating socket
macro socket Domain, Type, Protocol
	;;rdi   rsi   rdx   r10	  r8   r9
	mov rax, SYS_SOCKET
	mov rdi, Domain
	mov rsi, Type
	mov rdx, Protocol
	syscall
end macro

;; create bind
macro bind R12, Address
	mov rax, SYS_BIND
	mov rdi, R12 ;;socket fd
	mov rsi, Address 
	mov rdx, 16
	syscall
end macro

;; create listen
macro listen R12
	mov rax, SYS_LISTEN
	mov rdi, R12 ;;assign socket
	mov rsi, 10 ;;backlog 
	syscall
end macro

;; create accept
macro accept R12
	mov rax, SYS_ACCEPT
	mov rdi, R12
	mov rsi, 0
	mov rdx, 0
	syscall
end macro

;; reuse address after close
macro sockopt R12, Optval
	mov rax, SYS_SETSOCKOPT    ; SYS_SETSOCKOPT
	mov rdi, R12               ; socket fd
	mov rsi, 1                 ; SOL_SOCKET
	mov rdx, 2                 ; SO_REUSEADDR _ 2 means use address again
	mov r10, Optval            ; pointer to int 1
	mov r8, 4                  ; length of int
	syscall
end macro

macro open Rsi
	;;open file index.html
	mov rax, SYS_OPEN
	mov rdi, Rsi
	mov rsi, 0
	syscall
end macro

macro exec execPath, execArgs
	mov rax, SYS_EXEC
	mov rdi, execPath
	mov rsi, execArgs
	mov rdx, 0 ;;execArgsCount
	syscall
end macro

macro write Rdi, Rsi, Rdx
	mov rax, SYS_WRITE
	mov rdi, Rdi 
        mov rsi, Rsi 
        mov rdx, Rdx 
        syscall
end macro

macro connect Rdi, Rsi, Rdx
	mov rax, SYS_CONNECT
	mov rdi, Rdi ;; r15
	mov rsi, Rsi ;; sockaddr
	mov rdx, Rdx ;; size sockaddr
	syscall
end macro

macro fcgiBeginRequest fd, buffer, length

	mov rax, SYS_WRITE
	mov rdi, fd 
	mov rsi, buffer
	mov rdx, length
	syscall

end macro


macro fcgiParamsRequest fd, buffer, length

	mov rax, SYS_WRITE
	mov rdi, fd 
	mov rsi, buffer
	mov rdx, length
	syscall

end macro

macro fcgiStdinRequest fd, buffer, length

	mov rax, SYS_WRITE
	mov rdi, fd 
	mov rsi, buffer
	mov rdx, length
	syscall

end macro

macro fcgiResponse fd, buffer, length

	mov rax, SYS_READ
	mov rdi, fd 
	mov rsi, buffer
	mov rdx, length
	syscall

end macro


segment readable executable
entry main
main:
	socket domain, type, protocol ;; socket macro

	mov r12, rax ;;copy socket fd to r12

	sockopt r12, optval ;; reuse address after close
	
	bind r12, address ;; bind macro

	listen r12 ;; listen macro

	accept r12 ;; accept macro

	mov r13, rax ;;result of acceppt, client socket fd	
	;;read client socket request _ forexample curl request info
	mov rax, 0
	mov rdi, r13
	mov rsi, socketResponse
	mov rdx, 1024
	syscall	

	mov r14, rax ;; length of socket response

	mov rsi, socketResponse
	jmp get_space_method
get_space_method:

	cmp byte [rsi], ' '
	je get_method

	inc rsi ;; mov to the nexy byte

	;;cmp rsi, socketResponse+8
	jmp get_space_method

get_method:
	mov rdx, rsi
	sub rdx, socketResponse ;; seperate method name lenght from socket response 

	;; test print method name eg: GET or POST
	;; this method pints socketResponse in length of rdx
	;; which is subtracted before	
    	;;mov rax, 1
    	;;mov rdi, 1
    	;;mov rsi, socketResponse
	;;syscall

	;; test print socketResponse	
    	;mov rax, 1
    	;mov rdi, 1
    	;mov rsi, socketResponse
    	;mov rdx, r14
	;syscall
	
	;;add rsi, rcx
	inc rsi	

	xor rcx, rcx
	;;jmp exit
	;;jmp handle_requests
	;;jmp find_url
	jmp get_space_url
	
get_space_url:

	cmp byte [ rsi + rcx ], ' '
	je get_url

	inc rcx ;; mov to the nexy byte

	;;cmp rsi, socketResponse+8
	jmp get_space_url

get_url:
	mov rdx, rcx	
    	mov rax, 1
    	mov rdi, 1
	mov rsi, rsi
	syscall

	cmp byte [rsi+1], " " ;; check if url is just /
	je index_file_load ;; load index file 

	mov byte [rsi + rdx], 0 ; null-terminate the URL before using it
	inc rsi ;; move to next 1 byte to pass / of start url 
	
	open rsi ;; open file
	jmp handle_requests

;; load index.php / index.html
index_file_load:	
	
	;; load php
	mov rsi, indexPhpPath ;; load index.php file

	open rsi ;; open file
	test rax, rax ;; check if rax < 0, rax < 0 means error
	;;jge php_fork ;; in case of php cli	
	jge php_fpm    ;; incase of php fpm fastcgi

	mov rsi, indexHtmlPath ;; load index.html file

	;; load html
	open rsi ;; open file
	cmp rax, -1 ;; check if file existed
	;;jmp handle_requests

	jmp handle_requests

php_fpm:
	socket phpfpmDomain, type, protocol ;; php fpm socket 
	mov r15, rax
	connect r15, sockaddr, 110 ;; connect to socket fd phpfpm
	
	fcgiBeginRequest r15, fcgi_begin, fcgi_begin_length 

	jmp exit	
	fcgiParamsRequest r15, fcgi_params, fcgi_params_length
	fcgiParamsRequest r15, fcgi_params_end, fcgi_params_end_length
	fcgiStdinRequest r15, fcgi_stdin, fcgi_stdin_length 
	fcgiResponse r15, fcgi_response_buffer, 1024
	
	mov rdi, fcgi_response_buffer
	mov al, [rdi+1] ;; response type is 6
	cmp al, 6 ;; check if successful
	;;jne exit ;; error mesg

	jmp read_data
	;;mov rdi, fcgi_response_buffer
	;;add rdi, 8 ;; skip headers data like version, type
	;;mov rdi, [rdi] ;; store actual data 	

	;; read the response	
	;;fcgiResponse r15, fcgiRespBuffer, 1024
	;;mov rdi, fcgiRespBuffer
	;;mov rax, [rdi]	
	;;test rax, rax
	;;jz exit
	
	;;write 1, fcgiRespBuffer, rax 
	;;jmp exit

read_data:
    	fcgiResponse r15, fcgi_response_buffer, 1024 ;; read the next chunk of data

    	cmp rax, 0 ;; check if we reached end of stream
    	je write_data ;; if no more data, move to writing

    	;; Otherwise, increment counter and continue reading
    	add rbx, rax ;; increment byte counter by the number of bytes read
    	jmp read_data ;; continue reading

write_data:
    	;; Now we write the data
    	mov rdi, 1               ;; File descriptor 1 (stdout)
    	mov rsi, fcgi_response_buffer ;; Data to write
    	mov rdx, rbx             ;; Number of bytes to write (from the byte counter)
    	syscall
	jmp close

handle_requests:
	
	mov [fd], rax
  	
	;;read index.html file
        mov rax, 0
        mov rdi, [fd] ;;read index file
        mov rsi, bufferHtml
        mov rdx, 8192
        syscall

	mov [bytesReadHtml], rax	
	;; close file
    	mov rax, 3
    	mov rdi, [fd]
    	syscall

    	;; write HTTP headers
    	mov rax, 1
    	mov rdi, r13
    	mov rsi, http_html_header
    	mov rdx, http_html_header_len
    	syscall

	;;write r14 into r13
	mov rax, 1
	mov rdi, r13
	mov rsi, bufferHtml
	mov rdx, [bytesReadHtml]
	syscall
	jmp close
close:
	;;close socket 
	mov rax, 3
	mov rdi, r13
	syscall	

	;; close setsockopt
	mov rax, 3
	mov rdi, r12
	syscall

	jmp main	
exit:	
	mov rax, 60
	mov rdi, 69 ;; exit code 69 is optional code
	syscall


segment readable writeable
address:
dw af_inet 
dw 0x901f
dd 0
dq 0

indexHtmlPath db 'index.html',0

http_html_header  db 'HTTP/1.1 200 OK',13,10
             db 'Connection: close',13,10,13,10
http_html_header_len = $ - http_html_header

del db 0xa, 0

sockaddr:
	db 1, 0 ;; af_unix = 1
	db "/run/php/php7.0-fpm.sock", 0

;; https://fastcgi-archives.github.io/FastCGI_Specification.html#S5.1
fcgi_begin:
	db 0 ;; high byte roleB0
	db 1 ;; low byte roleB1
	db 0 ;; flags
	db 5 dup(0)
fcgi_begin_length = $ - fcgi_begin
	
fcgi_params:
		
fcgi_params_length = $ - fcgi_params ; Calculate the length of FCGI_PARAMS


fcgi_stdin:

fcgi_stdin_length = $ - fcgi_stdin


fcgi_params_end:
		
fcgi_params_end_length = $ - fcgi_params_end 

