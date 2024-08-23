#include <stdio.h>
#include <complex.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#define ENABLE_WOW_API

#define SYS_WOW_toggle_window 101
#define SYS_WOW_send_framebuffer 102

#define WIDTH 320
#define HEIGHT 200


void volatile wow_toggle_window() {
#ifdef ENABLE_WOW_API
    asm volatile (
        "li a7, %0\n"
        "ecall\n"
        :
        : "i" (SYS_WOW_toggle_window)
        : "a7"
    );
#endif
}

void wow_send_framebuffer(uint8_t grid[HEIGHT * WIDTH]) {
#ifdef ENABLE_WOW_API
    asm volatile (
        "li a7, %0\n"
        "mv a0, %1\n"
        "ecall\n"
        : 
        : "i" (SYS_WOW_send_framebuffer), "r" (grid)
        : "a0", "a7"
    );
#else
    printf("\033[H\033[J");

    for (int y = 0; y < HEIGHT; y++) {
        for (int x = 0; x < WIDTH; x++) {
            if (grid[y * WIDTH + x]) {
                printf("O");
            } else {
                printf(" ");
            }
        }
        printf("\n");
    }
    printf("%p\n", grid);
#endif
}

uint8_t is_in_mandelbrot_set(double real, double imag, int max_iter) {
    double complex c = real + imag * I;
    double complex z = 0;
    int iter;

    for (iter = 0; iter < max_iter; iter++) {
        z = z * z + c;

        if (cabs(z) > 2.0) {
            return 0;
        }
    }

    return 1;
}


int main() {
    int max_iter = 10;
    double center_real = -0.75, center_imag = 0.1;
    uint8_t grid[HEIGHT * WIDTH];
    memset(grid, 0, HEIGHT * WIDTH);


    wow_toggle_window();

    double range = 2.0 / (1.0f + 1 / 10.0f);
    double real_start = center_real - range / 2.0;
    double real_end = center_real + range / 2.0;
    double imag_start = center_imag - range / 2.0;
    double imag_end = center_imag + range / 2.0;
    double real_step = (real_end - real_start) / (WIDTH - 1);
    double imag_step = (imag_end - imag_start) / (HEIGHT - 1);

    for (int i = 0; i < 16; i+=2) {
        for (int yi = 0; yi < HEIGHT / 16; yi++) {
            int y = yi * 16 + i;
            for (int x = 0; x < WIDTH ; x+=2) {
                double real = real_start + x * real_step;
                double imag = imag_start + y * imag_step;
                uint8_t res = is_in_mandelbrot_set(real, imag, max_iter) ? 15 : 0;
                grid[y * WIDTH + x] = res;
                grid[y * WIDTH + x + 1] = res;
                grid[(y+1) * WIDTH + x] = res;
                grid[(y+1) * WIDTH + x + 1] = res; 
            }
            wow_send_framebuffer(grid);
        }
    }

    // wow_toggle_window();

    return 0;
}
