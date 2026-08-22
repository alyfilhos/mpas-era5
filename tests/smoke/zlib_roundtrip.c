#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <zlib.h>

int main(void) {
    static const unsigned char input[] =
        "MPAS-ERA5 installed zlib round-trip validation";
    const uLong input_size = (uLong)sizeof(input);
    uLong compressed_size = compressBound(input_size);
    unsigned char *compressed = malloc(compressed_size);
    unsigned char output[sizeof(input)] = {0};
    uLong output_size = (uLong)sizeof(output);

    if (compressed == NULL) {
        fputs("zlib smoke: allocation failed\n", stderr);
        return EXIT_FAILURE;
    }
    if (compress2(compressed, &compressed_size, input, input_size,
                  Z_BEST_COMPRESSION) != Z_OK) {
        fputs("zlib smoke: compression failed\n", stderr);
        free(compressed);
        return EXIT_FAILURE;
    }
    if (uncompress(output, &output_size, compressed, compressed_size) != Z_OK) {
        fputs("zlib smoke: decompression failed\n", stderr);
        free(compressed);
        return EXIT_FAILURE;
    }
    free(compressed);

    if (output_size != input_size || memcmp(input, output, input_size) != 0) {
        fputs("zlib smoke: round-trip mismatch\n", stderr);
        return EXIT_FAILURE;
    }

    printf("zlib_version=%s input_bytes=%lu compressed_bytes=%lu\n",
           zlibVersion(), (unsigned long)input_size,
           (unsigned long)compressed_size);
    puts("zlib_roundtrip=PASS");
    return EXIT_SUCCESS;
}
