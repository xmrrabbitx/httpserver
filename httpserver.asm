format ELF64 executable


af_inet = 2
domain = af_inet ;;af_inet = 2
type = 1 
protocol = 0 ;; default value is 0


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
	
	;;read file
	mov rax, 0
	mov rdi, r13 ;;read client socket
	mov rsi, buffer
	mov rdx, 256
	syscall	

	;;open file
	mov rax, 2
	mov rdi, path
	mov rsi, 0
	syscall

	mov r14, rax

  	;;read index.html file
        mov rax, 0
        mov rdi, r14 ;;read index file
        mov rsi, buffer2
        mov rdx, 256
        syscall

	mov r15, rax
	
	;;write r14 into r13
	mov rax, 1
	mov rdi, r13
	mov rsi, buffer2
	mov rdx, r15
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
	
	mov rax, 60
	mov rdx, rdx
	syscall


segment readable writeable
address:
dw af_inet 
dw 0x901f
dd 0
dq 0
buffer:
db 256 dup 0 ;;dup is loop in zero times
buffer2:
db 256 dup 0
path:
db 'index.html',0


