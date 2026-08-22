#include <stdio.h>
#include <stdlib.h>

#include <hdf5.h>

#define H5_CHECK(call)                                                        \
    do {                                                                      \
        if ((call) < 0) {                                                     \
            fprintf(stderr, "HDF5 smoke failed at %s:%d: %s\n", __FILE__,  \
                    __LINE__, #call);                                         \
            goto fail;                                                        \
        }                                                                     \
    } while (0)

int main(int argc, char **argv) {
    const int expected[8] = {10, 20, 30, 40, 50, 60, 70, 80};
    int observed[8] = {0};
    const hsize_t dimensions[1] = {8};
    const hsize_t chunk[1] = {8};
    unsigned int filter_config = 0;
    hid_t file = H5I_INVALID_HID;
    hid_t space = H5I_INVALID_HID;
    hid_t dcpl = H5I_INVALID_HID;
    hid_t dataset = H5I_INVALID_HID;

    if (argc != 2) {
        fprintf(stderr, "usage: %s OUTPUT.h5\n", argv[0]);
        return EXIT_FAILURE;
    }
    if (H5Zfilter_avail(H5Z_FILTER_DEFLATE) <= 0 ||
        H5Zget_filter_info(H5Z_FILTER_DEFLATE, &filter_config) < 0 ||
        (filter_config & H5Z_FILTER_CONFIG_ENCODE_ENABLED) == 0 ||
        (filter_config & H5Z_FILTER_CONFIG_DECODE_ENABLED) == 0) {
        fputs("HDF5 smoke: zlib deflate filter is unavailable\n", stderr);
        return EXIT_FAILURE;
    }

    file = H5Fcreate(argv[1], H5F_ACC_TRUNC, H5P_DEFAULT, H5P_DEFAULT);
    H5_CHECK(file);
    space = H5Screate_simple(1, dimensions, NULL);
    H5_CHECK(space);
    dcpl = H5Pcreate(H5P_DATASET_CREATE);
    H5_CHECK(dcpl);
    H5_CHECK(H5Pset_chunk(dcpl, 1, chunk));
    H5_CHECK(H5Pset_deflate(dcpl, 6));
    dataset = H5Dcreate2(file, "values", H5T_NATIVE_INT, space, H5P_DEFAULT,
                         dcpl, H5P_DEFAULT);
    H5_CHECK(dataset);
    H5_CHECK(H5Dwrite(dataset, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                      expected));
    H5_CHECK(H5Dclose(dataset));
    dataset = H5I_INVALID_HID;
    H5_CHECK(H5Pclose(dcpl));
    dcpl = H5I_INVALID_HID;
    H5_CHECK(H5Sclose(space));
    space = H5I_INVALID_HID;
    H5_CHECK(H5Fclose(file));
    file = H5I_INVALID_HID;

    file = H5Fopen(argv[1], H5F_ACC_RDONLY, H5P_DEFAULT);
    H5_CHECK(file);
    dataset = H5Dopen2(file, "values", H5P_DEFAULT);
    H5_CHECK(dataset);
    H5_CHECK(H5Dread(dataset, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT,
                     observed));
    for (size_t index = 0; index < 8; ++index) {
        if (observed[index] != expected[index]) {
            fprintf(stderr, "HDF5 smoke: value mismatch at index %zu\n", index);
            goto fail;
        }
    }
    H5_CHECK(H5Dclose(dataset));
    dataset = H5I_INVALID_HID;
    H5_CHECK(H5Fclose(file));
    file = H5I_INVALID_HID;

    puts("hdf5_deflate_filter=encode+decode");
    puts("hdf5_roundtrip=PASS");
    return EXIT_SUCCESS;

fail:
    if (dataset >= 0) H5Dclose(dataset);
    if (dcpl >= 0) H5Pclose(dcpl);
    if (space >= 0) H5Sclose(space);
    if (file >= 0) H5Fclose(file);
    return EXIT_FAILURE;
}
