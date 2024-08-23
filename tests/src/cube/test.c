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


unsigned char framebuffer[SCREEN_SIZE];


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


int edges[][2] = {
    {0, 1}, {1, 2}, {2, 3}, {3, 0},  
    {4, 5}, {5, 6}, {6, 7}, {7, 4},  
    {0, 4}, {1, 5}, {2, 6}, {3, 7}   
};


int faces[][4] = {
    {0, 1, 2, 3},  
    {4, 5, 6, 7},  
    {0, 1, 5, 4},  
    {2, 3, 7, 6},  
    {0, 3, 7, 4},  
    {1, 2, 6, 5}   
};


unsigned char face_colors[] = {
    31, 63, 95, 127, 159, 191  
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

Point2D project(float x, float y, float z) {
    float scale = 100.0f;
    float distance = 5.0f;
    float f = scale / (z + distance);
    Point2D p;
    p.x = (int)(WIDTH / 2 + x * f);
    p.y = (int)(HEIGHT / 2 - y * f);
    return p;
}


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


void fill_triangle(unsigned char *framebuffer, Point2D v0, Point2D v1, Point2D v2, unsigned char color) {
    int x0 = v0.x, y0 = v0.y;
    int x1 = v1.x, y1 = v1.y;
    int x2 = v2.x, y2 = v2.y;

    
    if (y0 > y1) { int temp; temp = y0; y0 = y1; y1 = temp; temp = x0; x0 = x1; x1 = temp; }
    if (y0 > y2) { int temp; temp = y0; y0 = y2; y2 = temp; temp = x0; x0 = x2; x2 = temp; }
    if (y1 > y2) { int temp; temp = y1; y1 = y2; y2 = temp; temp = x1; x1 = x2; x2 = temp; }

    int total_height = y2 - y0;
    for (int i = 0; i < total_height; i++) {
        int second_half = i > y1 - y0 || y1 == y0;
        int segment_height = second_half ? y2 - y1 : y1 - y0;
        float alpha = (float)i / total_height;
        float beta  = (float)(i - (second_half ? y1 - y0 : 0)) / segment_height;
        int ax = x0 + (x2 - x0) * alpha;
        int bx = second_half ? x1 + (x2 - x1) * beta : x0 + (x1 - x0) * beta;
        if (ax > bx) { int temp = ax; ax = bx; bx = temp; }
        for (int j = ax; j <= bx; j++) {
            if (j >= 0 && j < WIDTH && (y0 + i) >= 0 && (y0 + i) < HEIGHT) {
                framebuffer[(y0 + i) * WIDTH + j] = color;
            }
        }
    }
}


void fill_face(unsigned char *framebuffer, Point2D p0, Point2D p1, Point2D p2, Point2D p3, unsigned char color) {
    fill_triangle(framebuffer, p0, p1, p2, color);
    fill_triangle(framebuffer, p2, p3, p0, color);
}


void render_cube(float angle) {
    memset(framebuffer, 0, SCREEN_SIZE);  

    Point2D transformed_vertices[8];
    for (int i = 0; i < 8; i++) {
        Point3D vertex = vertices[i];

        
        rotate_x(&vertex, angle);
        rotate_y(&vertex, angle);
        rotate_z(&vertex, angle);

        
        transformed_vertices[i] = project(vertex.x, vertex.y, vertex.z);
    }

    
    for (int i = 0; i < 6; i++) {
        Point2D p0 = transformed_vertices[faces[i][0]];
        Point2D p1 = transformed_vertices[faces[i][1]];
        Point2D p2 = transformed_vertices[faces[i][2]];
        Point2D p3 = transformed_vertices[faces[i][3]];

        
        fill_face(framebuffer, p0, p1, p2, p3, face_colors[i]);
    }

    
    for (int i = 0; i < 12; i++) {
        int x0 = transformed_vertices[edges[i][0]].x;
        int y0 = transformed_vertices[edges[i][0]].y;
        int x1 = transformed_vertices[edges[i][1]].x;
        int y1 = transformed_vertices[edges[i][1]].y;
        draw_line(framebuffer, x0, y0, x1, y1, 255);  
    }

    
    output_framebuffer(framebuffer);
}

int main() {
    float angle = 0;
    wow_toggle_window();
    while (angle < 2 * M_PI) {  
        render_cube(angle);
        angle += 0.05f;
    }

    return 0;
}
