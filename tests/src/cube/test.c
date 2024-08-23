#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

#define ENABLE_WOW_API

#define SYS_WOW_toggle_window 101
#define SYS_WOW_send_framebuffer 102

#define WIDTH 320
#define HEIGHT 200
#define SCREEN_SIZE (WIDTH * HEIGHT)

// Define the framebuffer as a global array
unsigned char framebuffer[SCREEN_SIZE];

// Define cube vertices
typedef struct {
    float x, y, z;
} Point3D;

typedef struct {
    int x, y;
} Point2D;

Point3D vertices[] = {
    {-1, -1, -1},
    { 1, -1, -1},
    { 1,  1, -1},
    {-1,  1, -1},
    {-1, -1,  1},
    { 1, -1,  1},
    { 1,  1,  1},
    {-1,  1,  1}
};

// Define cube edges
int edges[][2] = {
    {0, 1}, {1, 2}, {2, 3}, {3, 0},  // back face
    {4, 5}, {5, 6}, {6, 7}, {7, 4},  // front face
    {0, 4}, {1, 5}, {2, 6}, {3, 7}   // connecting edges
};

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

// Placeholder function to output the framebuffer
void output_framebuffer(unsigned char *framebuffer) {
#ifdef ENABLE_WOW_API

        asm volatile (
        "li a7, %0\n"
        "mv a0, %1\n"
        "ecall\n"
        : 
        : "i" (102), "r" (framebuffer)
        : "a0", "a7"
    );
#endif
}

// Projection matrix for 2D rendering (assuming orthogonal projection)
Point2D project(float x, float y, float z) {
    float scale = 100.0f;
    float distance = 5.0f;
    float f = scale / (z + distance);
    Point2D p;
    p.x = (int)(WIDTH / 2 + x * f);
    p.y = (int)(HEIGHT / 2 - y * f);
    return p;
}

// Rotation functions
void rotate_x(Point3D *p, float angle) {
    float cos_a = cosf(angle);
    float sin_a = sinf(angle);
    float y = p->y * cos_a - p->z * sin_a;
    float z = p->y * sin_a + p->z * cos_a;
    p->y = y;
    p->z = z;
}

void rotate_y(Point3D *p, float angle) {
    float cos_a = cosf(angle);
    float sin_a = sinf(angle);
    float x = p->x * cos_a + p->z * sin_a;
    float z = -p->x * sin_a + p->z * cos_a;
    p->x = x;
    p->z = z;
}

void rotate_z(Point3D *p, float angle) {
    float cos_a = cosf(angle);
    float sin_a = sinf(angle);
    float x = p->x * cos_a - p->y * sin_a;
    float y = p->x * sin_a + p->y * cos_a;
    p->x = x;
    p->y = y;
}

// Bresenham's line algorithm for drawing lines in the framebuffer
void draw_line(unsigned char *framebuffer, int x0, int y0, int x1, int y1, unsigned char color) {
    int dx = abs(x1 - x0);
    int dy = abs(y1 - y0);
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    while (1) {
        if (x0 >= 0 && x0 < WIDTH && y0 >= 0 && y0 < HEIGHT) {
            framebuffer[y0 * WIDTH + x0] = color;
        }
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 > -dy) {
            err -= dy;
            x0 += sx;
        }
        if (e2 < dx) {
            err += dx;
            y0 += sy;
        }
    }
}

// Main rendering loop
void render_cube(float angle) {
    memset(framebuffer, 0, SCREEN_SIZE);  // Clear the framebuffer

    Point2D transformed_vertices[8];
    for (int i = 0; i < 8; i++) {
        Point3D vertex = vertices[i];

        // Rotate around X, Y, and Z axes
        rotate_x(&vertex, angle);
        rotate_y(&vertex, angle);
        rotate_z(&vertex, angle);

        // Project to 2D
        transformed_vertices[i] = project(vertex.x, vertex.y, vertex.z);
    }

    // Draw edges by setting pixels in the framebuffer
    for (int i = 0; i < 12; i++) {
        int x0 = transformed_vertices[edges[i][0]].x;
        int y0 = transformed_vertices[edges[i][0]].y;
        int x1 = transformed_vertices[edges[i][1]].x;
        int y1 = transformed_vertices[edges[i][1]].y;
        draw_line(framebuffer, x0, y0, x1, y1, 255);  // Draw line with color value 255 (white)
    }

    // Output the framebuffer
    output_framebuffer(framebuffer);
}

int main() {
    wow_toggle_window();
    float angle = 0;
    while (angle < 2 * M_PI) {  // Simulate some rotation
        render_cube(angle);
        angle += 0.05f;
    }

    return 0;
}