#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

// Safe string length to use with strncpy and strncmp
#define SAFE_STR_LEN 26

int main() {
    printf("Starting malloc/free tests...\n");

    // 1. Simple Allocation and Deallocation
    printf("Test 1: Simple Allocation and Deallocation\n");
    char *ptr1 = malloc(10 * sizeof(char));
    assert(ptr1 != NULL);
    strncpy(ptr1, "Hello", 9);
    ptr1[9] = '\0';  // Ensure null termination
    printf("ptr1 contains: %s\n", ptr1);
    free(ptr1);
    printf("Test 1 passed.\n\n");

    // 2. Multiple Allocations
    printf("Test 2: Multiple Allocations\n");
    int *ptr2 = malloc(5 * sizeof(int));
    double *ptr3 = malloc(5 * sizeof(double));
    char *ptr4 = malloc(SAFE_STR_LEN * sizeof(char));

    assert(ptr2 != NULL && ptr3 != NULL && ptr4 != NULL);

    for (int i = 0; i < 5; i++) {
        ptr2[i] = i * 10;
        ptr3[i] = i * 0.1;
    }
    strncpy(ptr4, "Multiple allocations test", SAFE_STR_LEN - 1);
    ptr4[SAFE_STR_LEN - 1] = '\0';  // Ensure null termination

    // Verify contents
    for (int i = 0; i < 5; i++) {
        assert(ptr2[i] == i * 10);
        assert(ptr3[i] == i * 0.1);
    }
    assert(strncmp(ptr4, "Multiple allocations test", SAFE_STR_LEN) == 0);

    // Free allocated memory
    free(ptr2);
    free(ptr3);
    free(ptr4);
    printf("Test 2 passed.\n\n");

    // 3. Edge Cases
    printf("Test 3: Edge Cases\n");

    // a. Allocate zero bytes
    printf("  Subtest a: Allocate zero bytes\n");
    char *ptr5 = malloc(0);
    // According to the C standard, malloc(0) may return NULL or a unique pointer
    // We'll check that it's either NULL or can be safely passed to free
    if (ptr5 != NULL) {
        free(ptr5);
    }
    printf("  Subtest a passed.\n");

    // b. Large Allocation
    printf("  Subtest b: Large Allocation\n");
    size_t large_size = 1024 * 1024; // 1 MB
    char *ptr6 = malloc(large_size);
    if (ptr6 != NULL) {
        memset(ptr6, 'A', large_size);
        // Verify a few bytes
        assert(ptr6[0] == 'A');
        assert(ptr6[large_size / 2] == 'A');
        assert(ptr6[large_size - 1] == 'A');
        free(ptr6);
        printf("  Subtest b passed.\n");
    } else {
        printf("  Subtest b: Large allocation failed (as expected on limited environments).\n");
    }

    // c. Freeing NULL
    printf("  Subtest c: Freeing NULL pointer\n");
    free(NULL); // Should not cause any issues
    printf("  Subtest c passed.\n");

    // d. Double Free
    printf("  Subtest d: Double Free\n");
    char *ptr7 = malloc(10);
    assert(ptr7 != NULL);
    free(ptr7);

    printf("  Subtest d skipped (double free can cause undefined behavior).\n");

    printf("Test 3 passed.\n\n");

    // 4. Stress Test
    printf("Test 4: Stress Test with Multiple Allocations and Frees\n");
    #define NUM_PTRS 1000
    char *ptrs[NUM_PTRS];

    // Allocate
    for (int i = 0; i < NUM_PTRS; i++) {
        ptrs[i] = malloc(64); // Allocate 64 bytes
        assert(ptrs[i] != NULL);
        memset(ptrs[i], i % 256, 64); // Fill with a pattern
        // printf("%d %d\n", i, ptrs[i][15]);
    }

    // Verify and Free
    for (int i = 0; i < NUM_PTRS; i++) {
        for (int j = 0; j < 64; j++) {
            //printf("%d %d\n", i, ptrs[i][15]);
            assert(ptrs[i][j] == (char)(i % 256));
        }
        free(ptrs[i]);
    }

    printf("Test 4 passed.\n\n");

    // All tests passed
    printf("All malloc/free tests passed successfully.\n");
    return 0;
}
