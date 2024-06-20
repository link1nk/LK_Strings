BITS 64

global strlen
global print_string
global print_char
global print_stderr
global newline
global print_uint
global print_int
global parse_uint
global parse_int
global print_hex
global strcmp
global string_hex
global set_terminal_color
global get_file_size
global open_file
global fposition
global write_file
global close_file
global read_file
global memory_alloc
global free_memory


;-------FLAGS FOR SYS_OPEN--------
%define O_APPEND 0x1000
%define O_CREAT  0x40
%define O_TRUNC  0x200
%define O_RDWR   0x2
%define O_WRONLY 0x1
%define O_RDONLY 0x0
;---------------------------------


;-------FLAGS FOR SYS_MMAP--------
%define PROT_EXEC  0x4
%define PROT_READ  0x1
%define PROT_WRITE 0x2
%define PROT_NONE  0x0

%define MAP_SHARED    0x1
%define MAP_PRIVATE   0x2
%define MAP_ANONYMOUS 0x20
%define MAP_FIXED     0x10
;---------------------------------


;---CONSTANTES SIMBOLICAS CORES---
;--------------ANSI---------------
%define TERMINAL_COLOR_BLACK   30
%define TERMINAL_COLOR_RED     31
%define TERMINAL_COLOR_GREEN   32
%define TERMINAL_COLOR_YELLOW  33
%define TERMINAL_COLOR_BLUE    34
%define TERMINAL_COLOR_MAGENTA 35
%define TERMINAL_COLOR_CYAN    36
%define TERMINAL_COLOR_WHITE   37
%define TERMINAL_COLOR_RESET   0
;------------- 256 ---------------
%define COLOR_GREEN_256        1
%define COLOR_RED_256          2
;---------------------------------


struc STAT
    .st_dev         resq 1
    .st_ino         resq 1
    .st_nlink       resq 1
    .st_mode        resd 1
    .st_uid         resd 1
    .st_gid         resd 1
    .pad0           resb 4
    .st_rdev        resq 1
    .st_size        resq 1
    .st_blksize     resq 1
    .st_blocks      resq 1
    .st_atime       resq 1
    .st_atime_nsec  resq 1
    .st_mtime       resq 1
    .st_mtime_nsec  resq 1
    .st_ctime       resq 1
    .st_ctime_nsec  resq 1
endstruc


segment .data
    color_green_256: db 0x1b, "[38;5;46m", 0
    color_red_256:   db 0x1b, "[38;5;196m", 0

    file_info:
        istruc STAT
        iend


segment .text

;int strlen(char *);
;RDI -> Ponteiro para uma string terminada com 0
strlen:
    xor eax, eax
    .loop:
    cmp byte[rdi + rax], 0
    jz .end
    inc rax
    jmp .loop
    .end:
    ret
;RAX -> Tamanho da string


;void print_string(char *);
;RDI -> Ponteiro para uma string terminada em 0
print_string:
    call strlen
    mov rsi, rdi
    mov rdx, rax
    mov rax, 1
    mov rdi, 1
    syscall
    ret


;void print_char(char);
;RDI -> Numero ASCII do caractere a ser impresso
print_char:
    and rdi, 0xff
    push rdi
    mov rdi, rsp
    call print_string
    add rsp, 8
    ret

;void print_stderr(char *);
;RDI -> Ponteiro para a mensagem de erro a ser impressa
print_stderr:
    call strlen
    mov rdx, rax
    mov rsi, rdi
    mov rdi, 2
    mov rax, 1
    syscall
    ret

;void newline(void);
newline:
    mov rdi, 0xa
    jmp print_char


;void print_uint(unsigned int);
;RDI -> Numero unsigned int a ser impresso
print_uint:
    mov rax, rdi
    mov r8, 10
    mov rdi, rsp
    push 0
    dec rdi
    sub rsp, 16
    .loop:
    xor rdx, rdx
    div r8
    add rdx, 0x30
    dec rdi
    mov byte[rdi], dl
    test rax, rax
    jnz .loop
    call print_string
    add rsp, 24
    ret


;void print_int(int);
;RDI -> Numero int
print_int:
    test rdi, rdi
    js .signed
    jmp print_uint
    .signed:
    push rdi
    mov rdi, '-'
    call print_char
    pop rdi
    neg rdi
    jmp print_uint


;unsigned int parse_uint(char *);
;RDI -> Ponteiro para uma string numerica unsigned a ser convertida para numero
parse_uint:
    xor rax, rax
    mov r8, 10
    .loop:
    cmp byte[rdi], '0'
    jb .end
    cmp byte[rdi], '9'
    ja .end

    mul r8
    movzx rdx, byte[rdi]
    sub rdx, 0x30
    add rax, rdx
    inc rdi
    jmp .loop
    .end:
    ret

    
;int parse_int(char *);
;RDI -> Ponteiro para uma string numera signed a ser convertida para numero
parse_int:
    cmp byte[rdi], '-'
    je .signed
    jmp parse_uint
    .signed:
    inc rdi
    call parse_uint
    neg rax
    ret


;void print_hex(int);
;RDI -> Numero a ser impresso em hexadecimal
print_hex:
    push rdi
    push 0x7830
    mov rdi, rsp
    call print_string
    add rsp, 8
    pop rdi

    mov r8, 16
    mov rax, rdi
    mov rdi, rsp
    push 0
    dec rdi
    sub rsp, 16
    .loop:
    xor rdx, rdx
    div r8
    cmp rdx, 9
    ja .letra
    .numero:
    add rdx, 0x30
    dec rdi
    mov byte[rdi], dl
    jmp .conditional
    .letra:
    add rdx, 0x57
    dec rdi
    mov byte[rdi], dl
    .conditional:
    test rax, rax
    jnz .loop
    call print_string
    add rsp, 24
    ret


;int strcmp(char *, char *);
;RDI -> Ponteiro para a primeira string
;RSI -> Ponteiro para a segunda string
strcmp:
    mov al, byte[rdi]
    cmp al, byte[rsi]
    jne .not_equal
    cmp al, 0
    jz .equal
    inc rdi
    inc rsi
    jmp strcmp
    .not_equal:
    mov rax, 1
    ret
    .equal:
    mov rax, 0
    ret
;RAX -> 1 caso seja falso, 0 caso seja verdadeiro


;int string_hex(char *);
;RDI -> Ponteiro para a "string hexadecimal" a ser convertida em hexadecimal
string_hex:
    xor rax, rax
    mov r8, 16

    cmp byte[rdi], '0'
    jne .whileLoop
    cmp byte[rdi + 1], 'x'
    jne .whileLoop
    add rdi, 2

    .whileLoop:
    cmp byte[rdi], '0'
    jb .nextCMP
    cmp byte[rdi], '9'
    ja .nextCMP

    .codeInsideWhile:
    xor rdx, rdx
    mul r8
    cmp byte[rdi], '0'
    jb .else
    cmp byte[rdi], '9'
    ja .else

    push rdi
    movzx rdi, byte[rdi]
    add rax, rdi
    pop rdi
    sub rax, 0x30
    inc rdi
    jmp .whileLoop

    .else:
    push rdi
    movzx rdi, byte[rdi]
    add rax, rdi
    pop rdi
    sub rax, 0x57
    inc rdi
    jmp .whileLoop

    .nextCMP:
    cmp byte[rdi], 'a'
    jb .end
    cmp byte[rdi], 'f'
    ja .end
    jmp .codeInsideWhile

    .end:
    ret
;RAX -> Valor hexadecimal ("0x4fa" -> 4fa)


;void set_terminal_color(int);
;RDI -> Codigo da cor ANSI
set_terminal_color:
    cmp rdi, 1
    je .green
    cmp rdi, 2
    je .red

    cmp rdi, TERMINAL_COLOR_RESET
    je .reset
    mov rax, rdi
    and rax, 0xff
    mov rdi, 0x006d00003b315b1b
    mov r8, 10
    mov cl, 40
    .convert:
    xor rdx, rdx
    div r8
    add dl, 0x30
    sal rdx, cl
    or rdi, rdx
    sub cl, 8
    test rax, rax
    jnz .convert
    .print:
    push rdi
    mov rdi, rsp
    call print_string
    add rsp, 8
    ret
    .reset:
    mov rdi, 0x6d303b315b1b
    push rdi
    mov rdi, rsp
    call print_string
    add rsp, 8
    ret

    .green:
    mov rdi, color_green_256
    call print_string
    ret
    .red:
    mov rdi, color_red_256
    call print_string
    ret

;int get_file_size(char *);
;RDI -> File path
get_file_size:
    mov rax, 4
    mov rsi, file_info
    syscall
    mov rax, [file_info + STAT.st_size]
    ret
;RAX -> Tamanho do arquivo em bytes


;int open_file(char *, int);
;RDI -> File path
;RSI -> Flags de permissoes
open_file:
    mov rax, 2
    mov rdx, 0
    syscall
    ret
;RAX -> File Descriptor do arquivo aberto


;void fposition(int, int);
;RDI -> File Descriptor
;RSI -> offset
fposition:
    mov rax, 8
    mov rdx, 0
    syscall
    ret


;void write_file(int, char *, int);
;RDI -> File Descriptor
;RSI -> Ponteiro para oque escrever
;RDX -> Quantos bytes escrever
write_file:
    mov rax, 1
    syscall
    ret


;void close_file(int);
;RDI -> File Descriptor
close_file:
    mov rax, 2
    syscall
    ret


;void read_file(int, int, int);
;RDI -> File Descriptor
;RSI -> Endereço de para onde ler 
;RDX -> Quantos bytes ler
read_file:
    mov rax, 0
    syscall
    ret


;void * memory_alloc(int);
;RDI -> Tamanho da memoria a ser alocada
memory_alloc:
    mov rsi, rdi
    mov rax, 9
    mov rdi, 0
    mov rdx, PROT_WRITE | PROT_READ
    mov r10, MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    mov r9, 0
    syscall
    ret
;RAX -> Ponteiro para a memoria alocada


;void free_memory(void *, int);
;RDI -> Ponteiro para a memoria a ser liberada
;RSI -> Tamanho da memoria a ser liberada
free_memory:
    mov rax, 11
    syscall
    ret
