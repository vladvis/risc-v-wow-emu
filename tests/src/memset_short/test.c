#include <stdio.h>
#include <string.h>

int main() {
    short vals;

    // memset(&vals, -1, sizeof(short));
    *(char*)(&vals) = -1;
    *((char*)(&vals) + 1) = -1;

    printf("vals=%d\n", vals);
    
    return 0;
}
