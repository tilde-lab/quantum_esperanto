
#define white_space(c) ((c) == ' ' || (c) == '\t')
#define valid_digit(c) ((c) >= '0' && (c) <= '9')

int fast_atoi(const char* p)
{
    int value = 0;
    // Skip leading whitespace
    while (white_space(*p)) {
        p += 1;
    }

    for (value = 0.0; valid_digit(*p); p += 1) {
        value = value * 10.0 + (*p - '0');
    }

    return value;
}