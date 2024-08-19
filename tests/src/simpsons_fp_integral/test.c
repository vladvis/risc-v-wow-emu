#include <math.h>

#define N_SPLIT 1024
#define SYS_exit 93

float func(float x) {
    return sin(x) / x;
}

volatile simpsons(float ll, float ul) {
    float stepSize = (ul - ll) / N_SPLIT;

    float integration = func(ll) + func(ul);
    for(int i = 1; i<= N_SPLIT-1; i++) {
        float k = ll + i*stepSize;
        if(!(i & 1))
            integration = integration + 2 * func(k);
        else
            integration = integration + 4 * func(k);
        
    }
    integration = integration * stepSize/3;
    return integration;
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
{
    float lower_limit = 1;
    float upper_limit = 100;
    float result = simpsons(lower_limit, upper_limit);
    const float ok = 0.61614239215850830078125;
    exit(fabs(result - ok) < 1e-4);
}
