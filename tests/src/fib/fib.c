#define SYS_exit 93

__attribute__((section(".result"))) int fib[10];

void init_fibonacci() {
    fib[0] = 0;
    fib[1] = 1;
    for (int i = 2; i < 10; i++) {
        fib[i] = fib[i - 1] + fib[i - 2];
    }
}

__attribute__((noreturn)) void exit(int code) {
    asm volatile (
        "li a7, %0\n"
        "mv a0, %1\n"
        "ecall\n"
        :
        : "i" (SYS_exit), "r" (code)
        : "a0", "a7"
    );
    while (1) {}
}

void _start() {

    /* main body of program: call main(), etc */
    init_fibonacci();
    exit(0);
}
