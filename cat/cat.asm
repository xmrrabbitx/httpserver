format ELF64 executable

SYS_READ = 0
SYS_WRITE = 1
SYS_OPEN = 2
SYS_CLOSE = 3	

fdCat dq 0
bufferCat rb 1024
bytesReadCat dq 0

macro open filenamecat

	mov rax, SYS_OPEN
	mov rdi, filenamecat
	mov rsi, 0 ;;flags (O_RDONLY)
	;;mov rdx, 0 ;;mode (not needed for reading)
	syscall
	mov [fdCat], rax

end macro

macro read fdcat, buffercat

	mov rax, SYS_READ
	mov rdi, [fdcat]
	mov rsi, buffercat
	mov rdx, 1024
	syscall
	mov [bytesReadCat], rax ;; store rax into bytesRead
end macro

macro write buffercat, count

	mov rax, SYS_WRITE
	mov rdi, 1
	mov rsi, buffercat	
	mov rdx, [count]
	syscall

end macro

macro close fdcat

        mov rax, SYS_CLOSE
        mov rdi, [fdcat]
        syscall

end macro

macro newline

	mov rax, SYS_WRITE
	mov rdi, 1
	mov rsi, del
	mov rdx, 1
	syscall

end macro

macro paramsCheck

	pop rcx ; rcx = 2, rsp += 8	
	pop rsi ; rdi = argv[0], rsp += 8 (discard program name)
	pop rsi ; rdi = argv[1], rsp += 8 (now points to NULL)

	cmp rsi, 0 ;; check on NULL value
	je emptyPrmErr

	;;mov al, [rsi]    ; al = '-' first chars param
	;;mov bl, [rsi+1]  ; bl = 'f' second cars param

	;;cmp al, '-' ;; check on special chars
	;;jne prmErr

	mov rdi, filenameCat
	mov rcx, 256
	rep movsb ;; Copy until null terminator or RCX=0

end macro


segment readable executable
entry cat
cat:
	paramsCheck
	
	open filenameCat

	;; error handling
	cmp rax, -2
	je printErr

	read fdCat, bufferCat
	write bufferCat, bytesReadCat
	newline
	close fdCat
exit:

	mov rax,60
	xor rdi, rdi
	syscall

printErr:

	mov rax, SYS_WRITE
	mov rdi, 1
	mov rsi, errorMsg_filenotfound
	mov rdx, 26 ;; err message length
	syscall

	newline

	jmp exit	


prmErr:

	mov rax, SYS_WRITE
	mov rdi, 1
	mov rsi, errorMsg_param
	mov rdx, 17 ;; err message length
	syscall

	newline

	jmp exit	

emptyPrmErr:

	mov rax, SYS_WRITE
	mov rdi, 1
	mov rsi, errorMsg_emptyParam
	mov rdx, 16 ;; err message length
	syscall

	newline

	jmp exit	
segment readable writeable
filenameCat db 256 dup(?) 
del db 0xa, 0
errorMsg_filenotfound db "No such file or directory!", 0
errorMsg_param db "wrong parameters!", 0
errorMsg_emptyParam db "empty file name!", 0
