
SYS_GETCWD = 79 ;; read current directory

;; length of current directory
macro currDir len

	push rdi
	push rsi

	mov rax, SYS_GETCWD
	mov rdi, currentDir
	mov rsi, len
	syscall

	pop rdi
	pop rsi
	ret

end macro

;; get current directories etries
get_currentDir:

	currDir 256

segment readable writeable
	currentDir rb 256
