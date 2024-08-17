// Define syscall numbers for RISC-V Linux
#define SYS_write 64
#define SYS_exit 93

// Define file descriptor numbers
#define STDOUT_FILENO 1

// Write function using inline assembly
void _start() {
    const char *message = "Hello, World!\n";
    asm volatile (
        "li a7, %0\n"        // Load syscall number for write
        "li a0, %1\n"        // Load file descriptor (stdout)
        "mv a1, %2\n"        // Load pointer to the message
        "li a2, %3\n"        // Load message length
        "ecall\n"            // Make the syscall
        "li a7, %4\n"        // Load syscall number for exit
        "li a0, 0\n"         // Load exit code (0)
        "ecall\n"            // Make the syscall
        :
        : "i" (SYS_write), "i" (STDOUT_FILENO), "r" (message), "i" (14), "i" (SYS_exit)
        : "a0", "a1", "a7"
    );
}
