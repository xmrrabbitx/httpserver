format ELF64 executable

;; include necessary files
include "./permissions/permission.asm"
include "./check_space_method.asm"
include "./get_method.asm"
include "./check_space_url.asm"
include "./get_url.asm"

SYS_WRITE = 1
SYS_READ = 0
SYS_SOCKET = 41
SYS_CONNECT = 42
SYS_BIND = 49
SYS_LISTEN  = 50
SYS_SETSOCKOPT = 54
SYS_ACCEPT = 43
SYS_OPEN = 2 ;; open file
SYS_STAT = 262 ;; check type of file


FCGI_BEGIN_REQUEST = 1
FCGI_STDIN = 5

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
optReuseAddr dd 1  ; int 1 for SO_REUSEADDR

rootPathBuff rb 1024
statBuff rb 144
slashUrlBuff rb 1024
reqRouteBuff rb 1024

paramBuff dq 0
bytesReadPhp dq 0

fcgi_param1_buf rb 1024

testbuff rb 256

;;creating socket
macro socket Domain, Type, Protocol
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

;; open dir/file
macro open opDir
	mov rax, SYS_OPEN
	mov rdi, opDir 
	mov rsi, 0
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

macro fcgiHeaders fd, buffer, length
	
	mov rax, SYS_WRITE
        mov rdi, fd
        mov rsi, buffer
        mov rdx, length
        syscall

end macro

macro fcgiParamHeaders fd, contentLength

	mov [paramBuff], 1 ;; version = 1
	mov [paramBuff+1], 4 ;; type = 4
	mov [paramBuff+2], 0 ;; requestIdB1
	mov [paramBuff+3], 1 ;; requestIdB0
	mov [paramBuff+4], 0 ;; contentLengthB1
	mov [paramBuff+5], contentLength ;; contentLengthB0 content of key:value + 
	mov [paramBuff+6], 0 ;; paddingLength = 0
	mov [paramBuff+7], 0 ;; reserved = 0
	
	mov rax, SYS_WRITE
        mov rdi, fd
        mov rsi, paramBuff
        mov rdx, 8 ;; headers is always 8 bytes
        syscall
end macro

macro fcgiHeadersRequest fd, buffer, length

	mov rax, SYS_WRITE
        mov rdi, fd
        mov rsi, buffer
        mov rdx, 8 ;; headers is always 8 bytes
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


macro fcgiResponse fd, buffer, length

	mov rax, SYS_READ
	mov rdi, fd 
	mov rsi, buffer
	mov rdx, length
	syscall

end macro

;; init params url length < 128
macro initfcgiparams1_l128 key_name, key_len, value_path, value_len
	mov byte [rdi], key_len 
	mov byte [rdi+1], r9b ;; < 128 _ pass r9b instead of r9 or even value_len beacause r9 is 64bit and could not assign to 8 bytes, so r9b is 8 bytes of r9

	;; copy key to rdi
	mov rsi, key_name
	mov rcx, key_len
	lea rdi, [rdi+2] ;; < 128
	rep movsb

	;; copy value to rdi
	mov rsi, value_path
	mov rcx, value_len
	rep movsb
end macro

;; init params url length > 128
macro initfcgiparams1_g128 key_name, key_len, value_path, encoded_len, value_len
	  
	;; make compatible with > 128 length
    mov byte [rdi], key_len
    mov eax, encoded_len
    mov dword [rdi+1], eax
    lea rdi, [rdi+5]
    
   ;; copy key to rdi
    mov rsi, key_name
    mov ecx, key_len
    rep movsb
    
    ;; copy value to rdi
    mov rsi, value_path
    mov ecx, value_len
    rep movsb
end macro

segment readable executable
entry main
main:
	call www_data_permission ;; make fpm permissions	
	socket domain, type, protocol ;; socket macro

	mov r12, rax ;;copy socket fd to r12

	sockopt r12, optReuseAddr ;; reuse address after close
	
	bind r12, address ;; bind macro

	listen r12 ;; listen macro

	accept r12 ;; accept macro

	mov r13, rax ;;result of acceppt, client socket fd	
	
	;; read client socket request _ forexample curl request info
	mov rax, SYS_READ
	mov rdi, r13
	mov rsi, socketResponse
	mov rdx, 1024
	syscall	

	mov r14, rax ;; length of socket response

	mov rsi, socketResponse

	call check_space_method ;; check space after method 

	call get_method ;; get method url
	
	call check_space_url ;; check apace after url

	call get_url ;; get url from socket response
	
;; prepend root path into rsi
concateRegisters:
    	lodsb  ;; load one byte to al             
	stosb  ;; store the byte in al                  
    	inc bl ;; length of address
	test al, al               
    	jnz  concateRegisters     

	;; check dir/file type
	mov rax, SYS_STAT ;; 262
	mov rdi, -100 ;; current dir
	mov rsi, rootPathBuff 
	mov rdx, statBuff
	mov r10, 0 ;; flags = 0 its necessary
	syscall

	;; check SYS_STAT status
	cmp rax, 0	
	jl error_404 ;; throws error later	

	;; you can see dir and files numbers in /usr/include/x86_64-linux-gnu/bits/stat.h
	;; st_mode is on byte 24
	mov eax, dword [statBuff+24]
	and eax, 0xF000 ;; seperate permissions from type
	mov dword [statBuff], eax
	
	cmp eax, 0x4000 ;; directory type
	je route_request
	jmp open_other_files

route_request:
	movzx rcx, bl
	mov rbx, rcx
	sub rbx, 1 ;; sub null terminated \0 	

	;; check here for endian slash later
	cmp byte [rootPathBuff+rbx-1], "/"
	jne without_slash_url
	jmp ending_slash_url

without_slash_url:
	
	lea rdi, [reqRouteBuff]
	mov rsi, rootPathBuff
	rep movsb
	lea rdi, [reqRouteBuff+rbx]
	mov rsi, slashChars	
	mov rcx, 1
	rep movsb

	add rbx, 1

	jmp final_req_url

ending_slash_url:

	;; store rootPathBuff in a larger rb
	lea rdi, [reqRouteBuff]
	mov  rsi, rootPathBuff
	rep movsb	
	jmp final_req_url

final_req_url:
	;; append indexPhpFile after reqRouteBuff
	lea rdi, [reqRouteBuff+rbx]
	mov rsi, indexPhpFile	
	mov rcx, 9
	rep movsb

	add rbx, 9 ;; recalculate rbx + 9 

	mov r8, reqRouteBuff	
	mov r9, rbx
	jmp php_fpm
 
open_other_files:
	open rootPathBuff ;; open other files except index
	test rax,rax
	jl error_404

	xor rcx, rcx ;; reset rcx 
	movzx rcx, bl ;;  make bl compatible with 64bits
	
	sub rcx, 5 ;; point to start of .php
	
	cmp byte [rootPathBuff+rcx],"."
	jne handle_requests

	cmp byte [rootPathBuff+rcx+1],"p"
	jne handle_requests

	cmp byte [rootPathBuff+rcx+2],"h"
	jne handle_requests
	
	cmp byte [rootPathBuff+rcx+3],"p"
	jne handle_requests

	mov r8, rootPathBuff ;; buffer
	add rcx, 4 ;; restore the actual length of url - null terminated
	mov r9, rcx ;; length
	jmp php_fpm


;; load index.php or index.html
index_file_load:	
	
	;; load php
	mov rsi, indexPhpPath ;; load index.php file
	mov r8, indexPhpPath
	mov r9, indexPhpPath_len 	
	
	open rsi ;; open file
	test rax, rax ;; check if rax < 0, rax < 0 means error
	jge php_fpm    ;; in case of php fpm fastcgi
	
	mov rsi, indexHtmlPath ;; load index.html file

	;; load html
	open rsi ;; open file
	test rax, rax	
	jge handle_requests
	jmp error_noindex ;; error handling 

php_fpm:

	socket phpfpmDomain, type, protocol ;; php fpm socket 
	mov r15, rax ;; sockfd

	connect r15, sockaddr, 110 ;; connect to socket fd phpfpm
	test rax, rax
	jl err_sockfpm_conn ;; check fpm permissions
	
	fcgiHeaders r15, fcgi_begin_headers, fcgi_begin_headers_length
	fcgiBeginRequest r15, fcgi_begin, fcgi_begin_length 

	;; check url length
	cmp r9, 128
	jge encode
	jmp l128 ;; < 128

encode:
	mov eax, r9d ; zero-extend r9 -> eax
	or eax, 0x80000000
	bswap eax
	mov r10d, eax
	jmp g128 ;; > 128

;; length < 128 
l128:

	;; init fcgi fcgi_param1 buff for request
	mov rdi, fcgi_param1_buf
	mov r11, rdi
	initfcgiparams1_l128 key_script_filename, 15, r8, r9 ;; r9 is length of url
	jmp fcgi_params_handle

;; length > 128
g128:
	;; init fcgi fcgi_param1 buff for request
	mov rdi, fcgi_param1_buf
	mov r11, rdi
	initfcgiparams1_g128 key_script_filename, 15, r8, r10d, r9d ;; r10d is encoded length of url
	jmp fcgi_params_handle

fcgi_params_handle:

	;; get length of fcgiparams _ store in r9	
	mov rdx, rdi
	sub rdx, r11
	xor r11, r11
	mov r11, rdx
	mov r9, r11
	
	fcgiParamHeaders r15, r9 
	fcgiParamsRequest r15, fcgi_param1_buf, r9
	
	;; reset register for later usage
	xor r11, r11
	xor r9, r9

	fcgiParamHeaders r15, fcgi_params_length_2 
	fcgiParamsRequest r15, fcgi_params_2, fcgi_params_length_2

	fcgiParamHeaders r15, fcgi_params_length_3
	fcgiParamsRequest r15, fcgi_params_3, fcgi_params_length_3

	fcgiParamHeaders r15, fcgi_params_length_4
	fcgiParamsRequest r15, fcgi_params_4, fcgi_params_length_4

	fcgiParamHeaders r15, fcgi_params_length_5
	fcgiParamsRequest r15, fcgi_params_5, fcgi_params_length_5

	fcgiParamHeaders r15, fcgi_params_length_6
	fcgiParamsRequest r15, fcgi_params_6, fcgi_params_length_6
	
	fcgiParamHeaders r15, fcgi_params_length_7
	fcgiParamsRequest r15, fcgi_params_7, fcgi_params_length_7
	
	fcgiParamHeaders r15, fcgi_params_length_8
	fcgiParamsRequest r15, fcgi_params_8, fcgi_params_length_8
	
	fcgiParamHeaders r15, fcgi_params_length_9
	fcgiParamsRequest r15, fcgi_params_9, fcgi_params_length_9
	
	fcgiHeadersRequest r15, fcgi_end_params, fcgi_end_params_length
	fcgiHeadersRequest r15, fcgi_stdin, fcgi_stdin_length
		
	fcgiResponse r15, bytesReadPhp, 1024 ;; read response of php _ make length dynamic later

	movzx rbp, byte [bytesReadPhp+1] ;; type = 6
	;;cmp rbp, 6 ;; in case of multiple responses
	;;jne close
	
	;; get content length of body
	movzx rbx, byte [bytesReadPhp+4] ;; high byte
	movzx rcx, byte [bytesReadPhp+5] ;; low byte
	shl rbx, 8 ;; shif left 8 bytes _ in C << 8
	or rbx, rcx ;; bitwise ot between high and low bytes

	lea r9, [bytesReadPhp + 8] ;; skip headers info

	mov rsi, r9
	mov rcx, 0 ;; counter to count headers info

;; skip headers until \r\n\r\n chars
loop_php_headers:

	;;cmp rcx, 4 ;; if nothing found, throws error
	;;jmp exit ;; err handling 
 	
	cmp byte [rsi], 0x0D ;; \r
	jne loop_php_headers_next	

	cmp byte [rsi+1], 0x0A ;; \n
	jne loop_php_headers_next

	cmp byte [rsi+2], 0x0D ;; \r
        jne loop_php_headers_next

	cmp byte [rsi+3], 0x0A ;; \n
	jne loop_php_headers_next

	jmp loop_php_end

loop_php_headers_next:
	inc rsi
	inc rcx
	jmp loop_php_headers

loop_php_end:
	add rsi, 4 ;; skip \r\n\r\n
	mov r9, rsi ;; skip headers 
	sub rbx, rcx ;; recalculate length ( content len - counter )	
	
	write r13, http_php_header, http_php_header_length ;; response headers
	
	write r13, r9, rbx ;; php response

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
	;;close fpm socket
        mov rax, 3
        mov rdi, r15
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
	mov rdi, 69 ;; exit code 69 is optional code
	syscall
 
error_404:
	
	;; write HTTP headers
        mov rax, 1
        mov rdi, r13
        mov rsi, http_404_header
        mov rdx, http_404_header_len
        syscall
	
        mov rax, 1
        mov rdi, r13
        mov rsi, error404Msg
        mov rdx, error404Msg_len 
        syscall

	jmp close


error_noindex:
	
	;; write HTTP headers
        mov rax, 1
        mov rdi, r13
        mov rsi, http_404_header
        mov rdx, http_404_header_len
        syscall
	
        mov rax, 1
        mov rdi, r13
        mov rsi, errorNoindexMsg
        mov rdx, errorNoindexMsg_len 
        syscall

	jmp close

err_sockfpm_conn:
       
	;; write HTTP headers
        mov rax, 1
        mov rdi, r13
        mov rsi, http_400_header
        mov rdx, http_400_header_len
        syscall
	
	mov rax, 1
        mov rdi, r13
        mov rsi, err_sockfpm_mssg
        mov rdx, err_sockfpm_mssg_len 
        syscall
	jmp close

segment readable writeable
address:
dw af_inet 
dw 0x901f
dd 0
dq 0

slashChars db "/",0

error404Msg db "Not Found: The requested URL was not found on this server."
error404Msg_len = $ - error404Msg

errorNoindexMsg db "Not Found: no index file found!"
errorNoindexMsg_len = $ - errorNoindexMsg

err_sockfpm_mssg db "Forbidden: you don't have permission to access this server!"
err_sockfpm_mssg_len = $ - err_sockfpm_mssg

http_400_header:
		db 'HTTP/1.1 500',13,10
             	db 'Connection: close',13,10,13,10
http_400_header_len = $ - http_400_header

http_404_header:
		db 'HTTP/1.1 404',13,10
             	db 'Connection: close',13,10,13,10
http_404_header_len = $ - http_404_header

indexPhpFile db 'index.php'

rootPath db '/var/www/html/'

indexHtmlPath:
	db '/var/www/html/' 
	db 'index.html',0
indexPhpPath:
	db '/var/www/html/'
	db 'index.php',0
indexPhpPath_len = $ - indexPhpPath

http_html_header  db 'HTTP/1.1 200 OK',13,10
             db 'Connection: close',13,10,13,10
http_html_header_len = $ - http_html_header


http_php_header: 
	    	db "HTTP/1.1 200 OK", 13, 10
    		db "Content-Type: text/html", 13, 10
    		db "Connection: close", 13, 10, 13, 10
http_php_header_length = $ - http_php_header


del db 0xa, 0

sockaddr:
	db 1, 0 ;; af_unix = 1
	db "/run/php/php-fpm.sock", 0


fcgi_begin_headers:
	db 1 ;; version = 1
	db 1 ;; type its variable
	db 0 ;; requestB1 = 0
	db 1 ;; requestB0 = 1
	db 0 ;; contentLnegthB1 = 0
	db 8 ;; contentLnegthB0 = 8
	db 0 ;; padding length = 0
	db 0 ;; reserved = 0
fcgi_begin_headers_length = $ - fcgi_begin_headers

;; https://fastcgi-archives.github.io/FastCGI_Specification.html#S5.1
fcgi_begin:
	db 0 ;; high byte roleB1
	db 1 ;; low byte roleB0
	db 0 ;; flags
	db 5 dup(0) ;;
fcgi_begin_length = $ - fcgi_begin
	
key_script_filename db "SCRIPT_FILENAME"

fcgi_params_2:
	db 14 ;; key length
	db 3 ;; value length

	db "REQUEST_METHOD"
	db "GET" 
fcgi_params_length_2 = $ - fcgi_params_2

fcgi_params_3:
	db 14 ;; key length
	db 1 ;; value length

	db "CONTENT_LENGTH"
	db "0" 
fcgi_params_length_3 = $ - fcgi_params_3


fcgi_params_4:
	db 15 ;; key length
	db 8 ;; value length

	db "SERVER_PROTOCOL"
	db "HTTP/1.1" 
fcgi_params_length_4 = $ - fcgi_params_4


fcgi_params_5:
	db 17  ;; key length
	db 7 ;; value length

	db "GATEWAY_INTERFACE"
	db "CGI/1.1" 
fcgi_params_length_5 = $ - fcgi_params_5


fcgi_params_6:
	db 11  ;; key length
	db 9 ;; value length

	db "REMOTE_ADDR"
	db "127.0.0.1" 
fcgi_params_length_6 = $ - fcgi_params_6

fcgi_params_7:
	db 11 ;; key length
	db 9 ;; value length

	db "SERVER_NAME"
	db "localhost" 
fcgi_params_length_7 = $ - fcgi_params_7


fcgi_params_8:
	db 11 ;; key length
	db 2 ;; value length

	db "SERVER_PORT"
	db "80" ;; port localhost _ not asm httpserver port 
fcgi_params_length_8 = $ - fcgi_params_8

fcgi_params_9:
	db 11 ;; key length
	db 10 ;; value length

	db "REQUEST_URI"
	db "/index.php" 
fcgi_params_length_9 = $ - fcgi_params_9

fcgi_end_params:
	db 1
	db 4
	db 0
	db 1
	dp 4 dup(0)
fcgi_end_params_length = $ - fcgi_end_params


fcgi_stdin:
	db 1
	db 5
	db 0
	db 1
	dp 4 dup(0)
fcgi_stdin_length = $ - fcgi_stdin
