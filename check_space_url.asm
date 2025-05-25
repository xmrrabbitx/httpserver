check_space_url:

        cmp byte [ rsi + rcx ], ' '
        je get_url

        inc rcx ;; mov to the next byte

        jmp check_space_url


