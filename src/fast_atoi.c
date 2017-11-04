// Copyright 2017 Andrey Sobolev, Tilde Materials Informatics (Berlin)
//
// This file is a part of quantum_esperanto project. The project is licensed under the MIT license.
// See the LICENSE file in the project root for license terms.


#include <limits.h>
#define white_space(c) ((c) == ' ' || (c) == '\t')
#define valid_digit(c) ((c) >= '0' && (c) <= '9')

int fast_atoi(const char* p)
{
    int value = 0, sign = 1;
    // Skip leading whitespace
    while (white_space(*p)) {
        p += 1;
    }

    // Account for FORTRAN string overflow
    if (*p == '*') {
        return INT_MAX;
    }

    // Account for sign
    if (*p == '-') {
        sign = -1;
        p += 1;
    }

    for (value = 0.0; valid_digit(*p); p += 1) {
        value = value * 10.0 + (*p - '0');
    }

    return sign * value;
}