
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

cat:
	open filenameCat
	read fdCat, bufferCat
	write bufferCat, bytesReadCat
	close fdCat
	ret
;;segment readable writeable
filenameCat db "1.txt", 0
