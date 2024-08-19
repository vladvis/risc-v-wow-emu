#include <math.h>

#define N_SPLIT 1024

float func(float x) {
    return (log(x) + sin(x)) / sqrt(x);
}

float simpsons(float ll, float ul) {
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

int main()
{
    float lower_limit = 1;
    float upper_limit = 100;
    float result = simpsons(lower_limit, upper_limit);
    const float ok = 56.65020751953125f;
    return fabs(result - ok) < 1e-4;
}
