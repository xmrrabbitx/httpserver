format ELF64 executable

af_inet = 2
domain = af_inet ;;af_inet = 2
type = 1 
protocol = 0 ;; default value is 0

fd dq 0
bufferHtml rb 1024
bytesReadHtml dq 0

segment readable executable

entry main
main:
	;;creating socket
	;;rdi   rsi   rdx   r10	  r8   r9
	mov rax, 41
	mov rdi, domain
	mov rsi, type
	mov rdx, protocol
	syscall

	mov r12, rax ;;copy socket fd to r12
	
	;;create bind
	mov rax, 49
	mov rdi, r12 ;;socket fd
	mov rsi, address 
	mov rdx, 16
	syscall

	;;create listen
	mov rax, 50
	mov rdi, r12 ;;assign socket
	mov rsi, 10 ;;backlog 
	syscall

;accept_loop:

	;;create accept
	mov rax, 43
	mov rdi, r12
	mov rsi, 0
	mov rdx, 0
	syscall

	mov r13, rax ;;result of acceppt, client socket fd	
	
	;;read client socket request _ its curl request
	mov rax, 0
	mov rdi, r13 ;;read client socket
	mov rsi, bufferHtml
	mov rdx, 1024
	syscall	

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
        mov rdx, 1024
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

	;;close 
	mov rax, 3
	mov rdi, r13
	syscall	

	;;close
	mov rax, 3
	mov rdi, r14
	syscall

	;jmp accept_loop	
	
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

