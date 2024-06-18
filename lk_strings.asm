%include "lib.inc"

%define argv(x) qword[rbp+x*8+8]
%define argc    qword[rbp]

%define LF   0x0A
%define NULL 0x00

section .data
    ;------- ERROR MESSAGES -------
    error_std_msg:           db "ERRO: ", NULL
    error_missing_args:      db "Precisa de mais argumentos!", LF, NULL
    error_missing_file_path: db "Arquivo não especificado! (utilize -f <nome_arquivo>)", LF, NULL
    error_open_file:         db "Arquivo não encontrado ou sem permissão de escrita!", LF, NULL
    error_memory_alloc:      db "Memória insuficiente!", LF, NULL    
    error_invalid_option:    db "Opção Invalida: ", NULL 
    ;------------------------------

    ;---------- KEYWORDS ----------
    arg_file_path:      db "-f", NULL
    arg_show_strings:   db "--show-strings", NULL
    arg_no_show_offset: db "--no-show-offset", NULL
    arg_lines:          db "-l", NULL
    arg_chars:          db "-c", NULL
    arg_end_byte:       db "--end", NULL
    arg_read_only:      db "--read-only", NULL
    arg_search_strings: db "-s", NULL
    ;------------------------------

    ;--------- CHECK BOX ----------
    success_check: db "[+] ", NULL
    fail_check:    db "[-] ", NULL
    ;-----------------------------

    ;------- FAIL MESSAGES --------
    fail_to_find_any_string: db "Não foi encontrada nenhuma string!", LF, NULL

    fail_to_search_incio:    db "Nenhuma referencia a ", '"',  NULL
    fail_to_search_fim:      db '"', " foi encontrada!", LF, NULL
    ;------------------------------

    ;------ SUCCESS MESSAGES ------
    string_found_one:        db "Found ", NULL
    string_found_two:        db " at offset ", NULL
    string_found_three:      db " -> ", NULL    
    ;------------------------------

section .bss
    ;-------- SET OPTIONS ---------
    OPT_file_path:      resq 1
    OPT_show_strings:   resb 1
    OPT_no_show_offset: resb 1
    OPT_lines:          resq 1
    OPT_chars:          resq 1
    OPT_end_byte:       resb 1
    OPT_read_only:      resb 1
    OPT_search_strings: resb 1
    ;------------------------------

    ;--------- FILE INFO ----------
    file_descriptor:    resq 1
    file_size:          resq 1
    file_addr:          resq 1
    ;------------------------------

    ;---- VARIAVEIS DE CONTROLE GERAIS ----
    end_byte:           resb 1
    temp_buffer:        resq 1
    any_output:         resb 1
    printed_lines:      resq 1
    match_byte:         resq 1
    iterate_loop:       resq 1
    ;--------------------------------------

    ;---- SEARCH STRINGS ----
    string_to_search:   resq 1
    string_inicio:      resq 1
    string_fim:         resq 1
    string_size:        resq 1
    break_loop:         resb 1
    contador:           resq 1
    iterate_helper:     resq 1
    ;------------------------------


section .text
    global _start

exit:
    mov rax, 60
    syscall

error:
    push rdi
    
    mov rdi, COLOR_RED_256
    call set_terminal_color

    mov rdi, error_std_msg
    call print_stderr

    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color

    pop rdi
    call print_stderr
    
    mov rax, 60
    mov rdi, 1
    syscall

command_line_args:
    mov r12, 1
    .loop:
    mov rdi, arg_file_path
    mov rsi, argv(r12)
    call strcmp
    cmp rax, 0
    je .OPT_file_path
    mov rdi, arg_show_strings
    mov rsi, argv(r12)
    call strcmp
    cmp rax, 0
    je .OPT_show_strings
    mov rdi, arg_no_show_offset
    mov rsi, argv(r12)
    call strcmp
    cmp rax, 0
    je .OPT_no_show_offset
    mov rdi, arg_lines
    mov rsi, argv(r12)
    call strcmp
    cmp rax, 0
    je .OPT_lines
    mov rdi, arg_chars
    mov rsi, argv(r12)
    call strcmp
    cmp rax, 0
    je .OPT_chars
    mov rdi, arg_end_byte
    mov rsi, argv(r12)
    call strcmp
    cmp rax, 0
    je .OPT_end_byte
    mov rdi, arg_read_only
    mov rsi, argv(r12)
    call strcmp
    cmp rax, 0
    je .OPT_read_only
    mov rdi, arg_search_strings
    mov rsi, argv(r12)
    call strcmp
    cmp rax, 0
    je .OPT_search_strings
    ;-------------------------------
    inc r12
    .check:
    cmp r12, argc
    jne .loop
    ret
    ;-------------------------------
    .OPT_file_path:
    inc r12
    mov rax, argv(r12)
    mov [OPT_file_path], rax
    jmp .check
    .OPT_show_strings:
    inc r12
    mov byte[OPT_show_strings], 1
    jmp .check
    .OPT_no_show_offset:
    inc r12
    mov byte[OPT_no_show_offset], 1
    jmp .check
    .OPT_lines:
    inc r12
    mov rdi, argv(r12)
    call parse_uint
    mov qword[OPT_lines], rax
    jmp .check
    .OPT_chars:
    inc r12
    mov rdi, argv(r12)
    call parse_uint
    mov qword[OPT_chars], rax
    jmp .check
    .OPT_end_byte:
    inc r12
    mov rdi, argv(r12)
    call string_hex
    mov byte[OPT_end_byte], al
    mov byte[end_byte], 1
    jmp .check
    .OPT_read_only:
    inc r12 
    mov byte[OPT_read_only], 1
    jmp .check
    .OPT_search_strings:
    inc r12 
    mov rax, argv(r12)
    mov qword[string_to_search], rax
    mov byte[OPT_search_strings], 1
    jmp .check

set_default_options:
    ; Opção padrao para "-f" (file_path) = Exibe uma mensagem de erro e encerra o programa
    .file_path:
    cmp qword[OPT_file_path], 0
    jne .lines
    mov rdi, error_missing_file_path
    jmp error
    ; Opção padrao para "-l" (lines) = File_size
    .lines:
    cmp qword[OPT_lines], 0
    jne .chars
    mov rax, [file_size]
    mov [OPT_lines], rax
    ; Opçao padrao para "-c" (chars) = 4
    .chars:
    cmp qword[OPT_chars], 0
    jne .end
    mov qword[OPT_chars], 3
    .end:
    ret

_start:
    ; Montagem do Stack Frame
    mov rbp, rsp

    ; Verifica se foi passada a quantidade minima de argumentos
    mov rax, argc
    mov rdi, error_missing_args
    cmp rax, 4
    jb error

    ; Salva as opçoes escolhidas nos argumentos em suas respectivas variaveis
    call command_line_args
    
    ; Obtem o tamanho do arquivo
    mov rdi, [OPT_file_path]
    call get_file_size
    mov [file_size], rax

    ; Seta as opçoes padroes para alguns argumentos
    ; caso o usuario nao tenha especificado
    call set_default_options

    ; Abre o arquivo especificado por -f e exibe
    ; uma mensagem de erro caso nao consiga abrir
    mov rdi, [OPT_file_path]
    cmp byte[OPT_read_only], 0
    jnz .open_read_only
    mov rsi, O_RDWR
    call open_file
    jmp .next
    .open_read_only:
    mov rsi, O_RDONLY
    call open_file
    .next:
    test rax, rax
    mov rdi, error_open_file
    js error

    ; Salva o File Descriptor do arquivo aberto
    mov [file_descriptor], rax
    
    ; Aloca memoria para o arquivo e exibe uma
    ; mensagem de erro caso a memoria não seja
    ; alocada com sucesso.
    mov rdi, [file_size]
    call memory_alloc
    test rax, rax
    mov rdi, error_memory_alloc
    js error
    mov [file_addr], rax

    ; Le do arquivo indicado pelo file descriptor
    ; para o endereço de memoria determinado para 
    ; o mesmo.
    mov rdi, [file_descriptor]
    mov rsi, [file_addr]
    mov rdx, [file_size]
    call read_file

    ; Verifica se o usuario quer usar a função --show-strings
    .show_strings:
    cmp byte[OPT_show_strings], 0
    je .search_strings
    call show_strings
    jmp .end
    
    .search_strings:
    cmp byte[OPT_search_strings], 0
    call search_strings 
    jmp .end

    .end:

    ; Libera a memoria alocada com base em seu endereço e tamanho
    mov rdi, [file_addr]
    mov rsi, [file_size]
    call free_memory

    ; Fecha o arquivo identificado pelo seu File Descriptor
    mov rdi, [file_descriptor]
    call close_file

    ; Encerra o programa
    mov rax, 60
    mov rdi, 0
    syscall

show_strings:
    mov rdi, [file_size]
    call memory_alloc
    mov qword[temp_buffer], rax

    ;------------------------------
    .loop:
    mov rax, [file_size]
    cmp qword[iterate_loop], rax
    je .end
    mov rax, [file_addr]
    add rax, [iterate_loop]
    cmp byte[rax], 0x20
    jb .check_match_bytes
    cmp byte[rax], 0x7e
    ja .check_match_bytes
    mov rax, [temp_buffer]
    add rax, [match_byte]
    mov rcx, [file_addr]
    add rcx, [iterate_loop]
    mov cl, byte[rcx] 
    mov byte[rax], cl
    add qword[match_byte], 1
    add qword[iterate_loop], 1
    jmp .loop
    ;------------------------------
    .check_match_bytes:
    movzx rax, byte[OPT_chars]
    cmp qword[match_byte], rax
    jb .clear_temp_buffer
    movzx rax, byte[end_byte]
    cmp rax, 0
    je .print_offset
    mov rax, [file_addr]
    add rax, [iterate_loop]
    mov cl, [OPT_end_byte]
    cmp byte[rax], cl
    jne .clear_temp_buffer
    ;------------------------
    .print_offset:
    movzx rax, byte[OPT_no_show_offset]
    test rax, rax
    jnz .print_string
    mov rdi, COLOR_GREEN_256
    call set_terminal_color
    mov rax, [iterate_loop]
    sub rax, [match_byte]
    mov rdi, rax
    call print_hex
    mov rdi, 0x20
    call print_char
    mov rdi, 0x20
    call print_char
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    .print_string:
    mov rdi, [temp_buffer]
    call print_string
    call newline
    add qword[printed_lines], 1
    mov byte[any_output], 1
    mov rax, [OPT_lines]
    cmp rax, [printed_lines]
    je .end
    ;------------------------
    .clear_temp_buffer:
    add qword[iterate_loop], 1
    .clear_temp_bufferLoop:
    mov rax, [match_byte]
    test rax, rax
    jz .loop
    mov rax, [temp_buffer]
    mov rcx, [match_byte]
    add rax, rcx
    mov byte[rax], 0
    sub qword[match_byte], 1
    mov rax, [match_byte]
    test rax, rax
    jnz .clear_temp_bufferLoop
    jmp .loop
    ;--------------------------------
    .fail_to_find_any_string:
    mov rdi, COLOR_RED_256
    call set_terminal_color
    mov rdi, fail_check
    call print_string
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, fail_to_find_any_string
    call print_string
    jmp .retornar
    ;------------------------------
    .end:
    movzx rax, byte[any_output]
    test rax, rax
    jz .fail_to_find_any_string
    .retornar:
    mov rdi, [temp_buffer]
    mov rsi, [file_size]
    call free_memory
    ret


search_strings:
    mov rdi, [file_size]
    call memory_alloc
    mov [string_inicio], rax
    mov rdi, [file_size]
    call memory_alloc
    mov [string_fim], rax

    mov rdi, [string_to_search]
    call strlen
    mov qword[string_size], rax


    ;------------------------------
    .loop:
    mov rax, [file_size]
    cmp qword[iterate_loop], rax
    jae .end
    mov rax, [file_addr]
    add rax, [iterate_loop]
    mov al, byte[rax]
    mov rcx, [string_to_search]
    add rcx, [match_byte]
    mov cl, byte[rcx]
    cmp al, cl
    jne .reset_match_byte
    add qword[match_byte], 1
    ;--------------------------
    .get_full_string:
    mov rax, [match_byte]
    cmp rax, [string_size]
    jne .clear_strings_inicio
    ;---------------------------
    .get_start_offset:
    mov qword[iterate_helper], 0
    .get_start_offsetLOOP:
    mov rax, [file_addr]
    add rax, [iterate_loop]
    sub rax, [match_byte]
    sub rax, [iterate_helper]
    mov al, byte[rax]
    cmp al, 0x20
    jb .get_start_string
    cmp al, 0x7e
    ja .get_start_string
    add qword[contador], 1
    add qword[iterate_helper], 1
    jmp .get_start_offsetLOOP
    ;----------------------------
    .get_start_string:
    mov qword[iterate_helper], 0
    .get_start_stringLOOP:
    mov rax, [iterate_helper]
    cmp rax, [contador]
    jae .get_end_string
    mov rax, [string_inicio]
    add rax, [iterate_helper]
    mov rcx, [file_addr]
    add rcx, [iterate_loop]
    sub rcx, [match_byte]
    sub rcx, [contador]
    inc rcx
    add rcx, [iterate_helper]
    mov cl, byte[rcx]
    mov byte[rax], cl
    add qword[iterate_helper], 1
    jmp .get_start_stringLOOP
    ;----------------------------
    .get_end_string:
    mov qword[iterate_helper], 0
    .get_end_stringLOOP:
    mov rax, [file_addr]
    add rax, [iterate_loop]
    inc rax
    add rax, [iterate_helper]
    mov al, byte[rax]
    cmp al, 0x20
    jb .print_string_no_end_byte
    cmp al, 0x7e
    ja .print_string_no_end_byte
    mov rax, [string_fim]
    add rax, [iterate_helper]
    mov rcx, [file_addr]
    add rcx, [iterate_loop]
    inc rcx
    add rcx, [iterate_helper]
    mov cl, byte[rcx]
    mov byte[rax], cl
    add qword[iterate_helper], 1
    jmp .get_end_stringLOOP
    ;---------------------------
    .print_string_no_end_byte:
    mov rax, [match_byte]
    cmp rax, [string_size]
    jne .clear_strings_inicio
    mov al, [end_byte]
    test al, al
    jnz .print_string_end_byte
    jmp .print_string
    .print_string_end_byte:
    mov rax, [file_addr]
    add rax, [iterate_loop]
    inc rax
    mov al, byte[rax]
    cmp al, [OPT_end_byte]
    je .print_string
    jmp .clear_strings_inicio
    ;---------------------------
    .print_string:
    mov byte[any_output], 1
    mov rdi, COLOR_GREEN_256
    call set_terminal_color
    mov rdi, success_check
    call print_string
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, string_found_one
    call print_string
    mov rdi, COLOR_GREEN_256
    call set_terminal_color
    mov rdi, '"'
    call print_char
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, COLOR_RED_256
    call set_terminal_color
    mov rdi, [string_to_search]
    call print_string
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, COLOR_GREEN_256
    call set_terminal_color
    mov rdi, '"'
    call print_char
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, string_found_two
    call print_string
    mov rdi, COLOR_GREEN_256
    call set_terminal_color
    mov rdi, [iterate_loop]
    sub rdi, [match_byte]
    inc rdi
    call print_hex
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, string_found_three
    call print_string
    mov rdi, COLOR_GREEN_256
    call set_terminal_color
    mov rdi, '"'
    call print_char
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, [string_inicio]
    call print_string
    mov rdi, COLOR_RED_256
    call set_terminal_color
    mov rdi, [string_to_search]
    call print_string
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, [string_fim]
    call print_string
    mov rdi, COLOR_GREEN_256
    call set_terminal_color
    mov rdi, '"'
    call print_char
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    call newline
    mov qword[match_byte], 0
    jmp .clear_strings_inicio
    ;---------------------------
    .clear_strings_inicio:
    mov rax, [string_inicio]
    .inicioLOOP:
    cmp byte[rax], 0
    jz .clear_strings_fim
    mov byte[rax], 0
    inc rax
    jmp .inicioLOOP
    .clear_strings_fim:
    mov rax, [string_fim]
    .fimLOOP:
    cmp byte[rax], 0
    jz .clear_contador
    mov byte[rax], 0
    inc rax
    jmp .fimLOOP
    ;---------------------------
    .clear_contador:
    mov qword[contador], 0
    add qword[iterate_loop], 1
    jmp .loop
    ;---------------------------
    .reset_match_byte:
    add qword[iterate_loop], 1
    mov qword[match_byte], 0
    jmp .loop
    ;---------------------------
    .end:
    movzx rax,  byte[any_output]
    test rax, rax
    jnz .return
    mov rdi, COLOR_RED_256
    call set_terminal_color
    mov rdi, fail_check
    call print_string
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, fail_to_search_incio
    call print_string
    mov rdi, COLOR_RED_256
    call set_terminal_color
    mov rdi, [string_to_search]    
    call print_string
    mov rdi, TERMINAL_COLOR_RESET
    call set_terminal_color
    mov rdi, fail_to_search_fim
    call print_string
    .return:
    mov rdi, [string_inicio]
    mov rsi, [file_size]
    call free_memory
    mov rdi, [string_fim]
    mov rsi, [file_size]
    call free_memory
    ret







