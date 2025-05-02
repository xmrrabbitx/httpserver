
SYS_OPEN = 2

fdCat dq 0
bufferCat rb 1024

macro open fileName

	mov rax, SYS_OPEN
	mov rdi, filename
	mov [fd], rax
	ret

end macro


test_cat:

	open filename

filename db "1.txt", 0
