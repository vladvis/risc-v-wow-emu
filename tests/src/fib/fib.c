
__attribute__((section(".result"))) int fib[10];

void init_fibonacci() {
    fib[0] = 0;
    fib[1] = 1;
    for (int i = 2; i < 10; i++) {
        fib[i] = fib[i - 1] + fib[i - 2];
    }
}

void _start() {

    /* main body of program: call main(), etc */
    init_fibonacci();

    while (1) {}
}
