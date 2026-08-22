#include <stdio.h>
#include <stdlib.h>

#include <netcdf.h>

#define NC_CHECK(call)                                                        \
    do {                                                                      \
        const int status = (call);                                            \
        if (status != NC_NOERR) {                                             \
            fprintf(stderr, "netCDF-C smoke failed at %s:%d: %s\n",        \
                    __FILE__, __LINE__, nc_strerror(status));                  \
            return EXIT_FAILURE;                                              \
        }                                                                     \
    } while (0)

int main(int argc, char **argv) {
    const int expected[8] = {101, 102, 103, 104, 105, 106, 107, 108};
    int observed[8] = {0};
    int ncid = -1;
    int dimid = -1;
    int varid = -1;
    int format = 0;
    int shuffle = 0;
    int deflate = 0;
    int deflate_level = 0;

    if (argc != 2) {
        fprintf(stderr, "usage: %s OUTPUT.nc\n", argv[0]);
        return EXIT_FAILURE;
    }

    NC_CHECK(nc_create(argv[1], NC_CLOBBER | NC_NETCDF4, &ncid));
    NC_CHECK(nc_def_dim(ncid, "sample", 8, &dimid));
    NC_CHECK(nc_def_var(ncid, "value", NC_INT, 1, &dimid, &varid));
    NC_CHECK(nc_def_var_deflate(ncid, varid, 0, 1, 6));
    NC_CHECK(nc_enddef(ncid));
    NC_CHECK(nc_put_var_int(ncid, varid, expected));
    NC_CHECK(nc_close(ncid));

    NC_CHECK(nc_open(argv[1], NC_NOWRITE, &ncid));
    NC_CHECK(nc_inq_format(ncid, &format));
    if (format != NC_FORMAT_NETCDF4) {
        fprintf(stderr, "netCDF-C smoke: unexpected format %d\n", format);
        return EXIT_FAILURE;
    }
    NC_CHECK(nc_inq_varid(ncid, "value", &varid));
    NC_CHECK(nc_inq_var_deflate(ncid, varid, &shuffle, &deflate,
                                &deflate_level));
    if (deflate != 1 || deflate_level != 6) {
        fputs("netCDF-C smoke: deflate settings were not preserved\n", stderr);
        return EXIT_FAILURE;
    }
    NC_CHECK(nc_get_var_int(ncid, varid, observed));
    NC_CHECK(nc_close(ncid));

    for (size_t index = 0; index < 8; ++index) {
        if (observed[index] != expected[index]) {
            fprintf(stderr, "netCDF-C smoke: value mismatch at index %zu\n",
                    index);
            return EXIT_FAILURE;
        }
    }
    puts("netcdf_c_format=netCDF-4 deflate_level=6");
    puts("netcdf_c_roundtrip=PASS");
    return EXIT_SUCCESS;
}
