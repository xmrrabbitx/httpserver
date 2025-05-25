check_space_method:

        cmp byte [rsi], ' ' ;; check on empty space after method
        je get_method

        inc rsi ;; move to the next byte

        jmp check_space_method



