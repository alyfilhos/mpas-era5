program pnetcdf_mpi_smoke
    use mpi
    use pnetcdf
    implicit none

    character(len=512) :: filename
    integer :: ierr, rank, nprocs
    integer :: ncid, dimid, varid
    integer :: local_failures, global_failures
    integer :: write_buffer(1), read_buffer(1)
    integer(kind=MPI_OFFSET_KIND) :: global_size
    integer(kind=MPI_OFFSET_KIND) :: start(1), count(1)

    call MPI_Init(ierr)
    if (ierr /= MPI_SUCCESS) error stop 1

    call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
    call check_mpi(ierr, "MPI_Comm_rank")
    call MPI_Comm_size(MPI_COMM_WORLD, nprocs, ierr)
    call check_mpi(ierr, "MPI_Comm_size")

    filename = "pnetcdf_mpi.nc"
    if (command_argument_count() >= 1) call get_command_argument(1, filename)

    global_size = int(nprocs, kind=MPI_OFFSET_KIND)
    write_buffer(1) = rank
    read_buffer(1) = -1
    start(1) = int(rank + 1, kind=MPI_OFFSET_KIND)
    count(1) = 1_MPI_OFFSET_KIND

    call check_pnetcdf(nf90mpi_create(MPI_COMM_WORLD, trim(filename), &
        ior(NF90_CLOBBER, NF90_64BIT_DATA), MPI_INFO_NULL, ncid), &
        "nf90mpi_create")
    call check_pnetcdf(nf90mpi_def_dim(ncid, "rank", global_size, dimid), &
        "nf90mpi_def_dim")
    call check_pnetcdf(nf90mpi_def_var(ncid, "rank_value", NF90_INT, &
        (/dimid/), varid), "nf90mpi_def_var")
    call check_pnetcdf(nf90mpi_enddef(ncid), "nf90mpi_enddef")
    call check_pnetcdf(nf90mpi_put_var_all(ncid, varid, write_buffer, &
        start=start, count=count), "nf90mpi_put_var_all")
    call check_pnetcdf(nf90mpi_close(ncid), "nf90mpi_close after write")

    call check_pnetcdf(nf90mpi_open(MPI_COMM_WORLD, trim(filename), &
        NF90_NOWRITE, MPI_INFO_NULL, ncid), "nf90mpi_open")
    call check_pnetcdf(nf90mpi_inq_varid(ncid, "rank_value", varid), &
        "nf90mpi_inq_varid")
    call check_pnetcdf(nf90mpi_get_var_all(ncid, varid, read_buffer, &
        start=start, count=count), "nf90mpi_get_var_all")
    call check_pnetcdf(nf90mpi_close(ncid), "nf90mpi_close after read")

    local_failures = 0
    if (read_buffer(1) /= rank) then
        write(*, '(A,I0,A,I0,A,I0)') "rank ", rank, &
            " read ", read_buffer(1), " but expected ", rank
        local_failures = 1
    end if

    call MPI_Allreduce(local_failures, global_failures, 1, MPI_INTEGER, &
        MPI_SUM, MPI_COMM_WORLD, ierr)
    call check_mpi(ierr, "MPI_Allreduce")

    if (global_failures /= 0) then
        if (rank == 0) write(*, '(A,I0)') &
            "PnetCDF validation failures: ", global_failures
        call MPI_Abort(MPI_COMM_WORLD, 2, ierr)
    end if

    if (rank == 0) write(*, '(A,I0,A)') &
        "PnetCDF MPI/Fortran smoke test passed with ", nprocs, " ranks"

    call MPI_Finalize(ierr)
    if (ierr /= MPI_SUCCESS) error stop 3

contains

    subroutine check_mpi(status, operation)
        integer, intent(in) :: status
        character(len=*), intent(in) :: operation
        integer :: abort_ierr

        if (status /= MPI_SUCCESS) then
            write(*, '(A,I0,A,A)') "rank ", rank, &
                ": MPI error in ", trim(operation)
            call MPI_Abort(MPI_COMM_WORLD, status, abort_ierr)
        end if
    end subroutine check_mpi

    subroutine check_pnetcdf(status, operation)
        integer, intent(in) :: status
        character(len=*), intent(in) :: operation
        integer :: abort_ierr

        if (status /= NF90_NOERR) then
            write(*, '(A,I0,A,A,A,A)') "rank ", rank, ": ", &
                trim(operation), ": ", trim(nf90mpi_strerror(status))
            call MPI_Abort(MPI_COMM_WORLD, status, abort_ierr)
        end if
    end subroutine check_pnetcdf

end program pnetcdf_mpi_smoke
