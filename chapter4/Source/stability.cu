//
// Created by elder on 7/18/2026.
//

#include <iostream>

__device__ unsigned char clip (int n) {
    return n > 255 ? 255 : (n < 0 ? 0 : n); // nested ternery operator return 255, 0 or n
}

int main() {
    return 0;
}