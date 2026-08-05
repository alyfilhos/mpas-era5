#include <mpi.h>
#include <pio.h>
#include <stdio.h>

#define CHECK_PIO(call) do {                                               \
    int check_status = (call);                                             \
    if (check_status != PIO_NOERR) {                                       \
        fprintf(stderr, "rank %d: %s failed with PIO error %d\n",         \
                rank, #call, check_status);                                \
        MPI_Abort(MPI_COMM_WORLD, check_status);                           \
    }                                                                      \
} while (0)

int main(int argc, char **argv)
{
    const char *filename = argc > 1 ? argv[1] : "pio_pnetcdf.nc";
    int rank, nprocs, iosysid, ioid, ncid, dimid, varid;
    int global_dim[1];
    int iotype = PIO_IOTYPE_PNETCDF;
    int value, observed = -1;
    int pnetcdf_available, netcdf_available;
    int netcdf4c_available, netcdf4p_available;
    PIO_Offset compmap[1];

    if (MPI_Init(&argc, &argv) != MPI_SUCCESS)
        return 1;

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &nprocs);

    pnetcdf_available = PIOc_iotype_available(PIO_IOTYPE_PNETCDF);
    netcdf_available = PIOc_iotype_available(PIO_IOTYPE_NETCDF);
    netcdf4c_available = PIOc_iotype_available(PIO_IOTYPE_NETCDF4C);
    netcdf4p_available = PIOc_iotype_available(PIO_IOTYPE_NETCDF4P);

    if (rank == 0) {
        printf("PIO IOTYPE availability: PNETCDF=%d NETCDF=%d "
               "NETCDF4C=%d NETCDF4P=%d\n",
               pnetcdf_available, netcdf_available,
               netcdf4c_available, netcdf4p_available);
    }

    if (!pnetcdf_available || !netcdf_available ||
        netcdf4c_available || netcdf4p_available) {
        if (rank == 0)
            fprintf(stderr, "unexpected PIO IOTYPE architecture\n");
        MPI_Abort(MPI_COMM_WORLD, 2);
    }

    CHECK_PIO(PIOc_set_iosystem_error_handling(
        PIO_DEFAULT, PIO_RETURN_ERROR, NULL));
    CHECK_PIO(PIOc_Init_Intracomm(MPI_COMM_WORLD, nprocs, 1, 0,
                                  PIO_REARR_SUBSET, &iosysid));

    global_dim[0] = nprocs;
    compmap[0] = rank + 1;
    CHECK_PIO(PIOc_InitDecomp(iosysid, PIO_INT, 1, global_dim, 1,
                              compmap, &ioid, NULL, NULL, NULL));

    CHECK_PIO(PIOc_createfile(iosysid, &ncid, &iotype, filename,
                              PIO_CLOBBER | PIO_64BIT_OFFSET));
    if (iotype != PIO_IOTYPE_PNETCDF) {
        fprintf(stderr, "rank %d: PIO changed requested IOTYPE to %d\n",
                rank, iotype);
        MPI_Abort(MPI_COMM_WORLD, 3);
    }

    CHECK_PIO(PIOc_def_dim(ncid, "rank", nprocs, &dimid));
    CHECK_PIO(PIOc_def_var(ncid, "rank_value", PIO_INT, 1,
                           &dimid, &varid));
    CHECK_PIO(PIOc_enddef(ncid));

    value = 1000 + rank;
    CHECK_PIO(PIOc_write_darray(ncid, varid, ioid, 1, &value, NULL));
    CHECK_PIO(PIOc_closefile(ncid));

    iotype = PIO_IOTYPE_PNETCDF;
    CHECK_PIO(PIOc_openfile(iosysid, &ncid, &iotype, filename, PIO_NOWRITE));
    if (iotype != PIO_IOTYPE_PNETCDF) {
        fprintf(stderr, "rank %d: PIO changed reopened IOTYPE to %d\n",
                rank, iotype);
        MPI_Abort(MPI_COMM_WORLD, 5);
    }
    CHECK_PIO(PIOc_inq_varid(ncid, "rank_value", &varid));
    CHECK_PIO(PIOc_read_darray(ncid, varid, ioid, 1, &observed));
    CHECK_PIO(PIOc_closefile(ncid));

    if (observed != value) {
        fprintf(stderr, "rank %d: expected %d, read %d\n",
                rank, value, observed);
        MPI_Abort(MPI_COMM_WORLD, 4);
    }

    CHECK_PIO(PIOc_freedecomp(iosysid, ioid));
    CHECK_PIO(PIOc_finalize(iosysid));

    if (rank == 0)
        printf("PIO PnetCDF smoke test passed with %d ranks\n", nprocs);

    MPI_Finalize();
    return 0;
}
