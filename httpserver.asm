format ELF64 executable

SYS_SOCKET = 41
SYS_BIND = 49
SYS_LISTEN  = 50
SYS_SETSOCKOPT = 54

af_inet = 2
domain = af_inet ;;af_inet = 2
type = 1 
protocol = 0 ;; default value is 0

fd dq 0
bufferHtml rb 8192
socketResponse rb 1024
bytesReadHtml dq 0

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
	mov rax, 43
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
	jmp find_space_method

find_space_method:

	cmp byte [rsi], ' '
	je found_space_method

	inc rsi ;; mov to the nexy byte

	;;cmp rsi, socketResponse+8
	jmp find_space_method

found_space_method:
	mov rdx, rsi
	sub rdx, socketResponse ;; seperate method name lenght from socket response 

	;; test print method name eg: GET or POST
	;; this method pints socketResponse in length of rdx
	;; which is subtracted before	
    	mov rax, 1
    	mov rdi, 1
    	mov rsi, socketResponse
	syscall

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
	jmp find_space_url
	
find_space_url:

	cmp byte [rsi+rcx], ' '
	je found_space_url

	inc rcx ;; mov to the nexy byte

	;;cmp rsi, socketResponse+8
	jmp find_space_url

found_space_url:
	
    	mov rax, 1
    	mov rdi, 1
	mov rdx, rcx
	syscall


	;; test print socketResponse	
    	;mov rax, 1
    	;mov rdi, 1
    	;mov rsi, socketResponse
    	;mov rdx, r14
	;syscall
	
	;;jmp exit
	;;jmp handle_requests
	;;jmp find_url
	jmp handle_requests
handle_requests:
	;;open file index.html
	mov rax, 2
	mov rdi, path
	mov rsi, 0
	syscall

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
    	mov rsi, http_header
    	mov rdx, http_header_len
    	syscall

	;;write r14 into r13
	mov rax, 1
	mov rdi, r13
	mov rsi, bufferHtml
	mov rdx, [bytesReadHtml]
	syscall

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
	mov rdx, rdx
	syscall


segment readable writeable
address:
dw af_inet 
dw 0x901f
dd 0
dq 0

path:
db 'index.html',0

http_header db 'HTTP/1.1 200 OK',13,10
             db 'Content-Type: text/html',13,10
             db 'Connection: close',13,10,13,10
http_header_len = $ - http_header

