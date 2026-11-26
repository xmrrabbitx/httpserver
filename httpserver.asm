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
SYS_CLOSE = 3
SYS_DUP2 = 33
SYS_FORK = 57
SYS_EXECVE = 59
SYS_WAIT4 = 61
SYS_PIPE = 22


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
tmp_reqRouteBuff rb 1024

paramBuff dq 0
bytesReadPhp dq 0
requestUriPtr dq 0
requestUriLen dq 0

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
	;; set encoded length for value length
    mov byte [rdi], key_len
    mov eax, encoded_len
    mov dword [rdi+1], eax
    lea rdi, [rdi+5]
    
   ;; copy key to rdi
    mov rsi, key_name
    mov ecx, key_len
    rep movsb
    
    ;; copy value to rdi
	;; set value based on actual lenght not encoded length
    mov rsi, value_path
    mov ecx, value_len
    rep movsb
end macro

segment readable executable
entry main
main:
	call load_config ;; read response size limits from server.conf
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
	mov rsi, rootPathBuff
	rep movsb	

	jmp final_req_url

final_req_url:

	;; use for index.html case
	mov rsi, reqRouteBuff
	mov rdi, tmp_reqRouteBuff
	mov rcx, 20 ;; length of /var/www/html/test
	rep movsb

	lea rdi, [tmp_reqRouteBuff+rbx]
	mov rsi, static_html_index_path	
	mov rcx, 10 ;; length of index.html
	rep movsb

	;; append static_php_index_path after reqRouteBuff
	lea rdi, [reqRouteBuff+rbx]
	mov rsi, static_php_index_path	
	mov rcx, 9 ;; length of index.php
	rep movsb

	add rbx, 9 ;; recalculate rbx + 9 

	open reqRouteBuff
	test rax, rax
	jl finalHtml
	mov byte [indexFallback], 1 ;; directory index -> index.html fallback if fpm is down
	jmp route_php

finalHtml:

	add rbx, 10 ;; recalculate rbx + 10 

	open tmp_reqRouteBuff
	test rax, rax
	jge handle_requests
	jmp error_404

route_php:
	;; fpm opens the index file itself; close the detection fd to avoid leaks
	mov rdi, rax
	mov rax, SYS_CLOSE
	syscall
	mov r8, reqRouteBuff	
	mov r9, rbx
	jmp php_fpm
 
open_other_files:
	open rootPathBuff ;; open other files except index
	test rax,rax
	jl error_404
	mov [exec_file_fd], rax ;; remember opened fd (needed for static fallback)

	xor rcx, rcx ;; reset rcx 
	movzx rcx, bl ;;  make bl compatible with 64bits
	
	sub rcx, 5 ;; point to start of .php
	
	cmp byte [rootPathBuff+rcx],"."
	je check_other_php
	jmp try_exec

check_other_php:
	cmp byte [rootPathBuff+rcx+1],"p"
	jne try_exec

	cmp byte [rootPathBuff+rcx+2],"h"
	jne try_exec
	
	cmp byte [rootPathBuff+rcx+3],"p"
	jne try_exec

	mov r8, rootPathBuff ;; buffer
	add rcx, 4 ;; restore the actual length of url - null terminated
	mov r9, rcx ;; length

	;; fpm opens the script itself; close the detection fd to avoid leaks
	mov rax, SYS_CLOSE
	mov rdi, [exec_file_fd]
	syscall

	jmp php_fpm

;; decide whether the requested file should be executed (ELF binary or .so)
try_exec:
	;; scan filename backwards for a ".so" suffix (also matches lib.so.N)
	movzx rbx, bl        ;; bl = length incl null terminator
	sub rbx, 2           ;; index of last real character
scan_so:
	cmp rbx, 0
	jle check_exec_bit
	cmp byte [rootPathBuff+rbx], '.'
	jne scan_so_dec
	cmp byte [rootPathBuff+rbx+1], 's'
	jne scan_so_dec
	cmp byte [rootPathBuff+rbx+2], 'o'
	je is_so_file
scan_so_dec:
	dec rbx
	jmp scan_so

is_so_file:
	mov byte [exec_kind], 1 ;; 1 = shared library -> run via ld.so
	jmp exec_prepare

check_exec_bit:
	;; execute only if any execute permission bit is set
	mov eax, dword [statBuff+24]
	test eax, 0x49       ;; 0o111 in low bits
	jz serve_static
	mov byte [exec_kind], 0 ;; 0 = regular executable
	jmp exec_prepare

serve_static:
	mov rax, [exec_file_fd] ;; restore fd for handle_requests
	jmp handle_requests

;; send headers, run the program, forward its output through a pipe (size-limited)
exec_prepare:
	mov r15, -1 ;; make sure close: does not close an inherited fpm fd

	;; close the fd we opened just for detection
	mov rax, SYS_CLOSE
	mov rdi, [exec_file_fd]
	syscall

	;; HTTP headers first so the forwarded body lands after them
	mov rax, SYS_WRITE
	mov rdi, r13
	mov rsi, http_exec_header
	mov rdx, http_exec_header_len
	syscall

	;; create a pipe for the child's stdout/stderr
	mov rax, SYS_PIPE
	lea rdi, [exec_pipefd]
	syscall
	test rax, rax
	jl close             ;; pipe failed (headers already sent) - just close

	mov rax, SYS_FORK
	syscall
	test rax, rax
	jl exec_pipe_fail    ;; fork failed
	jz exec_child

	;; parent: remember pid and close the write end
	mov [exec_child_pid], rax
	mov rax, SYS_CLOSE
	mov edi, [exec_pipefd+4]
	syscall

	;; forward child output up to max_exec_output_size (0 = unlimited)
	xor rbx, rbx
exec_fwd_loop:
	mov rcx, [max_exec_output_size]
	test rcx, rcx
	jz exec_fwd_full
	sub rcx, rbx
	jbe exec_fwd_done               ;; configured limit reached
	mov rdx, rcx
	cmp rdx, 4096
	jbe exec_fwd_ready
exec_fwd_full:
	mov rdx, 4096
exec_fwd_ready:
	mov rax, SYS_READ
	mov edi, [exec_pipefd]
	lea rsi, [exec_fwd_buf]
	syscall
	test rax, rax
	jle exec_fwd_done               ;; EOF or read error
	mov r10, rax
	mov rdi, r13
	lea rsi, [exec_fwd_buf]
	mov rdx, r10
	call write_full
	add rbx, r10
	jmp exec_fwd_loop

exec_fwd_done:
	;; close read end; a still-running child gets SIGPIPE at the limit
	mov rax, SYS_CLOSE
	mov edi, [exec_pipefd]
	syscall

	;; reap the child
	mov rdi, [exec_child_pid]
	mov rax, SYS_WAIT4
	xor rsi, rsi
	xor rdx, rdx
	xor r10, r10
	syscall
	jmp close

exec_pipe_fail:
	;; close both pipe ends after a failed fork
	mov rax, SYS_CLOSE
	mov edi, [exec_pipefd]
	syscall
	mov rax, SYS_CLOSE
	mov edi, [exec_pipefd+4]
	syscall
	jmp close

exec_child:
	;; stdout / stderr -> pipe write end
	mov rax, SYS_DUP2
	mov edi, [exec_pipefd+4]
	mov rsi, 1
	syscall
	mov rax, SYS_DUP2
	mov edi, [exec_pipefd+4]
	mov rsi, 2
	syscall
	;; close pipe fds and inherited sockets in the child
	mov rax, SYS_CLOSE
	mov edi, [exec_pipefd]
	syscall
	mov rax, SYS_CLOSE
	mov edi, [exec_pipefd+4]
	syscall
	mov rax, SYS_CLOSE
	mov rdi, r12
	syscall
	mov rax, SYS_CLOSE
	mov rdi, r13
	syscall

	cmp byte [exec_kind], 1
	je exec_so_child

	;; run compiled executable directly
	mov rax, SYS_EXECVE
	mov rdi, rootPathBuff
	mov rsi, exec_argv
	xor rdx, rdx
	syscall
	jmp exec_child_exit

exec_so_child:
	;; run shared library through the dynamic loader
	mov rax, SYS_EXECVE
	mov rdi, ldso_path
	mov rsi, exec_ldso_argv
	xor rdx, rdx
	syscall

exec_child_exit:
	mov rax, 60
	mov rdi, 1
	syscall


;; load index.php or index.html
index_file_load:	
	
	;; load php
	mov rsi, indexPhpPath ;; load index.php file
	mov r8, indexPhpPath
	mov r9, indexPhpPath_len 	
	
	open rsi ;; open file
	test rax, rax ;; check if rax < 0, rax < 0 means error
	jl index_try_html

	;; fpm opens index.php itself; close the detection fd to avoid leaks
	mov rdi, rax
	mov rax, SYS_CLOSE
	syscall
	jmp php_fpm    ;; in case of php fpm fastcgi

index_try_html:
	mov rsi, indexHtmlPath ;; load index.html file

	;; load html
	open rsi ;; open file
	test rax, rax	
	jge handle_requests
	jmp error_noindex ;; error handling 

php_fpm:

	;; try each known fpm socket in order until one connects
	lea rbx, [fpmSockets]
php_try_fpm:
	mov r10, [rbx]
	test r10, r10
	jz err_sockfpm_conn ;; no socket reachable
	socket phpfpmDomain, type, protocol
	mov r15, rax ;; sockfd
	connect r15, r10, 110
	test rax, rax
	jge fpm_connected
	mov rax, SYS_CLOSE
	mov rdi, r15
	syscall
	add rbx, 8
	jmp php_try_fpm
fpm_connected:
	
	fcgiHeaders r15, fcgi_begin_headers, fcgi_begin_headers_length
	fcgiBeginRequest r15, fcgi_begin, fcgi_begin_length 

	;; check url length
	cmp r9, 128
	jge encode
	jmp l128 ;; < 128

encode:
	mov eax, r9d ;; zero-extend r9 -> eax 32bit
	or eax, 0x80000000 ;; set bit 31 highest bit _ fastcgi knows its 4 byte
	bswap eax ;; make 32bit value to big endian fastcgi accepts it beacause x86 is little endian
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

	;; read the whole FastCGI response (all records) into phpCgiBuf
	call php_read_cgi

	cmp byte [phpOverflow], 1
	je err_php_too_large

	mov rbx, [phpCgiLen]
	test rbx, rbx
	jz err_php_too_large

	;; locate end of CGI headers (\r\n\r\n)
	lea rsi, [phpCgiBuf]
	xor rcx, rcx
php_find_hdr_end:
	lea rax, [rcx+4]
	cmp rax, rbx
	ja err_php_too_large
	cmp byte [rsi+rcx], 0x0D
	jne php_find_hdr_next
	cmp byte [rsi+rcx+1], 0x0A
	jne php_find_hdr_next
	cmp byte [rsi+rcx+2], 0x0D
	jne php_find_hdr_next
	cmp byte [rsi+rcx+3], 0x0A
	jne php_find_hdr_next
	jmp php_hdr_found
php_find_hdr_next:
	inc rcx
	jmp php_find_hdr_end

php_hdr_found:
	add rcx, 4                    ;; skip \r\n\r\n
	mov rbx, [phpCgiLen]
	sub rbx, rcx                  ;; body length

	;; enforce max_php_response_size (0 = unlimited)
	mov rax, [max_php_response_size]
	test rax, rax
	jz php_size_ok
	cmp rbx, rax
	ja err_php_too_large
php_size_ok:
	lea r9, [phpCgiBuf]
	add r9, rcx                   ;; body pointer

	write r13, http_php_header, http_php_header_length ;; response headers

	mov rdi, r13
	mov rsi, r9
	mov rdx, rbx
	call write_full               ;; php response body

	jmp close

handle_requests:
	
	mov [fd], rax

	;; write HTTP headers first, then stream the file body
	mov rax, SYS_WRITE
	mov rdi, r13
	mov rsi, http_html_header
	mov rdx, http_html_header_len
	syscall

	mov qword [staticTotal], 0

static_send_loop:
	;; how many bytes are still allowed? (0 = unlimited)
	mov rcx, [max_static_file_size]
	test rcx, rcx
	jz static_chunk_full
	sub rcx, [staticTotal]
	jbe static_send_done          ;; configured limit reached
	mov rdx, rcx
	cmp rdx, 8192
	jbe static_chunk_ready
static_chunk_full:
	mov rdx, 8192
static_chunk_ready:
	mov rax, SYS_READ
	mov rdi, [fd]
	mov rsi, bufferHtml
	syscall
	test rax, rax
	jle static_send_done          ;; EOF or read error
	mov rbx, rax

	mov rdi, r13
	mov rsi, bufferHtml
	mov rdx, rbx
	call write_full

	add [staticTotal], rbx
	jmp static_send_loop

static_send_done:
	;; close file
	mov rax, SYS_CLOSE
	mov rdi, [fd]
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
	jmp clear
	
clear:
	;; reset reqRouteBuff to prevent overwitten values
	xor rax, rax           ; Set AL = 0 (byte to write)
	lea rdi, [reqRouteBuff] ; Destination = start of buffer
	mov rcx, 256           ; Number of bytes to clear
	rep stosb              ; Write AL (0) to [RDI], RCX times

	;; reset rootPathBuff to prevent overwitten values
	xor rax, rax           ; Set AL = 0 (byte to write)
	lea rdi, [rootPathBuff] ; Destination = start of buffer
	mov rcx, 256           ; Number of bytes to clear
	rep stosb              ; Write AL (0) to [RDI], RCX times

	;; reset tmp_reqRouteBuff to prevent overwitten values
	xor rax, rax           ; Set AL = 0 (byte to write)
	lea rdi, [tmp_reqRouteBuff] ; Destination = start of buffer
	mov rcx, 256           ; Number of bytes to clear
	rep stosb              ; Write AL (0) to [RDI], RCX times

	mov byte [indexFallback], 0 ;; reset per-request flag

	jmp main	

;; ---------------------------------------------------------------
;; read_full: read exactly rdx bytes from fd rdi into rsi
;;   returns rax = number of bytes actually read (short on EOF/error)
;; ---------------------------------------------------------------
read_full:
	push rbx
	push r12
	push r13
	push r14
	mov r12, rdi          ;; fd
	mov r13, rsi          ;; buffer
	mov r14, rdx          ;; remaining
	mov rbx, rdx          ;; original count
read_full_loop:
	test r14, r14
	jz read_full_done
	mov rax, SYS_READ
	mov rdi, r12
	mov rsi, r13
	mov rdx, r14
	syscall
	test rax, rax
	jle read_full_done
	add r13, rax
	sub r14, rax
	jmp read_full_loop
read_full_done:
	mov rax, rbx
	sub rax, r14
	pop r14
	pop r13
	pop r12
	pop rbx
	ret

;; ---------------------------------------------------------------
;; write_full: write rdx bytes from rsi to fd rdi
;;   returns rax = number of bytes actually written
;; ---------------------------------------------------------------
write_full:
	push rbx
	push r12
	push r13
	push r14
	mov r12, rdi          ;; fd
	mov r13, rsi          ;; buffer
	mov r14, rdx          ;; remaining
	mov rbx, rdx          ;; original count
write_full_loop:
	test r14, r14
	jz write_full_done
	mov rax, SYS_WRITE
	mov rdi, r12
	mov rsi, r13
	mov rdx, r14
	syscall
	test rax, rax
	jle write_full_done
	add r13, rax
	sub r14, rax
	jmp write_full_loop
write_full_done:
	mov rax, rbx
	sub rax, r14
	pop r14
	pop r13
	pop r12
	pop rbx
	ret

;; ---------------------------------------------------------------
;; parse_uint: parse a decimal number at rsi
;;   returns rax = value, rsi advanced past the last digit
;; ---------------------------------------------------------------
parse_uint:
	xor rax, rax
parse_uint_loop:
	movzx rcx, byte [rsi]
	cmp cl, '0'
	jb parse_uint_done
	cmp cl, '9'
	ja parse_uint_done
	imul rax, rax, 10
	sub rcx, '0'
	add rax, rcx
	inc rsi
	jmp parse_uint_loop
parse_uint_done:
	ret

;; ---------------------------------------------------------------
;; str_eq: compare [rdi,rdi+rcx) with [rsi,rsi+rdx)
;;   returns rax = 1 if equal, else 0
;; ---------------------------------------------------------------
str_eq:
	cmp rcx, rdx
	jne str_eq_no
	push rbx
	mov rbx, rcx
	test rbx, rbx
	jz str_eq_yes_pop
str_eq_loop:
	mov al, [rdi]
	cmp al, [rsi]
	jne str_eq_no_pop
	inc rdi
	inc rsi
	dec rbx
	jnz str_eq_loop
str_eq_yes_pop:
	pop rbx
	mov rax, 1
	ret
str_eq_no_pop:
	pop rbx
str_eq_no:
	xor rax, rax
	ret

;; ---------------------------------------------------------------
;; php_read_cgi: read all FastCGI response records from fd r15,
;;   strip record headers/padding and append STDOUT content to
;;   phpCgiBuf. Stops on FCGI_END_REQUEST or EOF.
;;   Sets phpCgiLen and phpOverflow.
;; ---------------------------------------------------------------
php_read_cgi:
	push rbx
	push r12
	push r13
	push r14
	push rbp

	mov qword [phpCgiLen], 0
	mov byte [phpOverflow], 0

php_cgi_loop:
	;; read the 8-byte FastCGI record header
	mov rdi, r15
	lea rsi, [phpRecHdr]
	mov rdx, 8
	call read_full
	cmp rax, 8
	jne php_cgi_done

	;; content length = big-endian 16-bit at offset 4
	movzx r12d, byte [phpRecHdr+4]
	shl r12d, 8
	movzx eax, byte [phpRecHdr+5]
	or r12d, eax
	movzx r13d, byte [phpRecHdr+6]   ;; padding length
	movzx ebx, byte [phpRecHdr+1]    ;; record type

	cmp ebx, 3                       ;; FCGI_END_REQUEST
	je php_cgi_done

	;; read the record content (max FCGI record fits phpRecBuf)
	mov rdi, r15
	lea rsi, [phpRecBuf]
	mov rdx, r12
	call read_full
	mov r14, rax                     ;; bytes actually read

	;; only STDOUT (type 6) contributes to the CGI stream
	cmp ebx, 6
	jne php_cgi_skip_pad

	;; append to phpCgiBuf, bounded by phpCgiBufSize
	mov rcx, [phpCgiLen]
	lea rdi, [phpCgiBuf]
	add rdi, rcx
	lea rsi, [phpRecBuf]
	mov rbx, r14
	mov rax, phpCgiBufSize
	sub rax, rcx
	cmp rbx, rax
	jbe php_cgi_copy
	mov rbx, rax
	mov byte [phpOverflow], 1
php_cgi_copy:
	test rbx, rbx
	jz php_cgi_skip_pad
	mov rcx, rbx
	rep movsb
	add [phpCgiLen], rbx

php_cgi_skip_pad:
	;; discard any record padding
	test r13d, r13d
	jz php_cgi_loop
	mov rdi, r15
	lea rsi, [phpRecBuf]
	mov rdx, r13
	call read_full
	jmp php_cgi_loop

php_cgi_done:
	pop rbp
	pop r14
	pop r13
	pop r12
	pop rbx
	ret

;; ---------------------------------------------------------------
;; load_config: parse server.conf into the response size limits.
;;   Missing file or unknown keys keep the built-in defaults.
;; ---------------------------------------------------------------
load_config:
	push rbx
	push r12
	push r13
	push r14

	;; config is parsed only once (main restarts on every request)
	cmp byte [configLoaded], 1
	je load_config_ret
	mov byte [configLoaded], 1

	;; open server.conf
	mov rax, SYS_OPEN
	lea rdi, [configPath]
	xor rsi, rsi
	xor rdx, rdx
	syscall
	test rax, rax
	js load_config_ret
	mov r12, rax                     ;; fd

	mov rax, SYS_READ
	mov rdi, r12
	lea rsi, [configBuf]
	mov rdx, configBufSize - 1
	syscall
	mov r13, rax                     ;; bytes read

	mov rax, SYS_CLOSE
	mov rdi, r12
	syscall

	test r13, r13
	jle load_config_ret
	lea rdi, [configBuf]
	mov byte [rdi+r13], 0            ;; null terminate

	lea rsi, [configBuf]

load_config_line:
	movzx eax, byte [rsi]
	test al, al
	jz load_config_ret
	cmp al, 10
	je load_config_nl
	cmp al, 13
	je load_config_nl
	cmp al, ' '
	je load_config_skip
	cmp al, 9
	je load_config_skip
	cmp al, '#'
	je load_config_to_eol
	jmp load_config_parse

load_config_skip:
	inc rsi
	jmp load_config_line

load_config_nl:
	inc rsi
	jmp load_config_line

load_config_parse:
	mov [cfgKeyPtr], rsi             ;; rsi = key start

load_config_find_eq:
	movzx eax, byte [rsi]
	test al, al
	jz load_config_ret
	cmp al, 10
	je load_config_nl
	cmp al, 13
	je load_config_nl
	cmp al, '='
	je load_config_have_eq
	inc rsi
	jmp load_config_find_eq

load_config_have_eq:
	mov rax, rsi
	sub rax, [cfgKeyPtr]             ;; key length

load_config_trim:
	test rax, rax
	jz load_config_trim_done
	mov rcx, [cfgKeyPtr]
	movzx edx, byte [rcx+rax-1]
	cmp dl, ' '
	je load_config_trim_dec
	cmp dl, 9
	je load_config_trim_dec
	jmp load_config_trim_done
load_config_trim_dec:
	dec rax
	jmp load_config_trim
load_config_trim_done:
	mov [cfgKeyLen], rax

	inc rsi                          ;; past '='
load_config_val_skip:
	movzx eax, byte [rsi]
	cmp al, ' '
	je load_config_val_inc
	cmp al, 9
	je load_config_val_inc
	jmp load_config_val
load_config_val_inc:
	inc rsi
	jmp load_config_val_skip

load_config_val:
	mov [cfgValPtr], rsi
	movzx eax, byte [rsi]
	cmp al, '0'
	jb load_config_no_value
	cmp al, '9'
	ja load_config_no_value
	call parse_uint
	mov [cfgValNum], rax
	mov [cfgCursor], rsi             ;; resume point after the digits

	;; match key against known names
	mov rdi, [cfgKeyPtr]
	mov rcx, [cfgKeyLen]
	lea rsi, [key_php]
	mov rdx, key_php_len
	call str_eq
	test rax, rax
	jz load_config_try_static
	mov rax, [cfgValNum]
	mov [max_php_response_size], rax
	jmp load_config_store_done

load_config_try_static:
	mov rdi, [cfgKeyPtr]
	mov rcx, [cfgKeyLen]
	lea rsi, [key_static]
	mov rdx, key_static_len
	call str_eq
	test rax, rax
	jz load_config_try_exec
	mov rax, [cfgValNum]
	mov [max_static_file_size], rax
	jmp load_config_store_done

load_config_try_exec:
	mov rdi, [cfgKeyPtr]
	mov rcx, [cfgKeyLen]
	lea rsi, [key_exec]
	mov rdx, key_exec_len
	call str_eq
	test rax, rax
	jz load_config_store_done
	mov rax, [cfgValNum]
	mov [max_exec_output_size], rax
	jmp load_config_store_done

load_config_no_value:
	mov [cfgCursor], rsi
load_config_store_done:
	mov rsi, [cfgCursor]             ;; restore cursor after the value
load_config_to_eol:
	movzx eax, byte [rsi]
	test al, al
	jz load_config_ret
	cmp al, 10
	je load_config_nl
	cmp al, 13
	je load_config_nl
	inc rsi
	jmp load_config_to_eol

load_config_ret:
	pop r14
	pop r13
	pop r12
	pop rbx
	ret

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

err_php_too_large:
	;; PHP/FastCGI response exceeded the configured size limit
	mov rax, SYS_WRITE
	mov rdi, r13
	mov rsi, http_503_header
	mov rdx, http_503_header_len
	syscall

	mov rax, SYS_WRITE
	mov rdi, r13
	mov rsi, err_php_too_large_msg
	mov rdx, err_php_too_large_msg_len
	syscall
	jmp close

err_sockfpm_conn:

	;; if this was a directory index request, fall back to index.html when fpm is down
	cmp byte [indexFallback], 1
	jne err_sockfpm_plain
	mov rdi, r15           ;; close the unused fpm socket
	mov rax, SYS_CLOSE
	syscall
	mov r15, -1
	open tmp_reqRouteBuff
	test rax, rax
	jl err_sockfpm_plain
	jmp handle_requests

err_sockfpm_plain:
       
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

;; --- execution support data ---
indexFallback db 0
exec_kind db 0
exec_file_fd dq 0
exec_argv dq rootPathBuff, 0
ldso_path db '/lib64/ld-linux-x86-64.so.2', 0
exec_ldso_argv dq ldso_path, rootPathBuff, 0

;; --- configurable response size limits (bytes; 0 = unlimited) ---
max_php_response_size dq 1048576    ;; max PHP/FastCGI response body
max_static_file_size  dq 8388608    ;; max static file served
max_exec_output_size  dq 1048576    ;; max executable/.so output streamed

configPath db 'server.conf', 0
configBufSize = 16384
configLoaded db 0
cfgKeyPtr dq 0
cfgKeyLen dq 0
cfgValPtr dq 0
cfgValNum dq 0
cfgCursor dq 0
key_php db 'max_php_response_size'
key_php_len = $ - key_php
key_static db 'max_static_file_size'
key_static_len = $ - key_static
key_exec db 'max_exec_output_size'
key_exec_len = $ - key_exec

;; --- PHP FastCGI / exec state ---
phpRecHdr rb 8
phpRecBufSize = 65536
phpCgiBufSize = 2097152
phpCgiLen dq 0
phpOverflow db 0

;; --- executable/.so output pipe forwarding ---
exec_pipefd dd 0, 0
exec_child_pid dq 0

staticTotal dq 0

http_exec_header:
	db 'HTTP/1.1 200 OK',13,10
	db 'Content-Type: text/plain',13,10
	db 'Connection: close',13,10,13,10
http_exec_header_len = $ - http_exec_header

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

http_503_header:
		db 'HTTP/1.1 503 Service Unavailable',13,10
        db 'Connection: close',13,10,13,10
http_503_header_len = $ - http_503_header

err_php_too_large_msg db "503: response exceeds configured size limit."
err_php_too_large_msg_len = $ - err_php_too_large_msg

static_php_index_path db 'index.php'
static_html_index_path db 'index.html'

rootPath db '/var/www/html/'

indexHtmlPath:
	db '/var/www/html/' 
	db 'index.html',0
indexPhpPath:
	db '/var/www/html/'
	db 'index.php',0
indexPhpPath_len = $ - indexPhpPath

http_html_header:  
			db 'HTTP/1.1 200 OK',13,10
            db 'Connection: close',13,10,13,10
http_html_header_len = $ - http_html_header

http_php_header: 
	    	db "HTTP/1.1 200 OK", 13, 10
    		db "Content-Type: text/html", 13, 10
    		db "Connection: close", 13, 10, 13, 10
http_php_header_length = $ - http_php_header

del db 0xa, 0 ;; not used anywhere _ its new line character!

sockaddr:
	db 1, 0 ;; af_unix = 1
	db "/run/php/php-fpm.sock", 0

sockaddr_alt:
	db 1, 0 ;; af_unix = 1
	db "/run/php/php8.4-fpm.sock", 0

;; last-resort socket for php-fpm started by a normal user (no root / no systemd)
sockaddr_tmp:
	db 1, 0 ;; af_unix = 1
	db "/tmp/php-fpm.sock", 0

fpmSockets dq sockaddr, sockaddr_alt, sockaddr_tmp, 0

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

;; --- large uninitialized buffers (kept last so they live in .bss) ---
configBuf rb configBufSize
phpRecBuf rb phpRecBufSize
phpCgiBuf rb phpCgiBufSize
exec_fwd_buf rb 4096
