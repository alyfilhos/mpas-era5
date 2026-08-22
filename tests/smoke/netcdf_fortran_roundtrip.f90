program netcdf_fortran_roundtrip
    use netcdf
    implicit none

    integer, parameter :: sample_count = 8
    integer :: ncid, dimid, varid, index
    integer :: expected(sample_count), observed(sample_count)
    character(len=4096) :: output_path

    if (command_argument_count() /= 1) then
        write (*, '(a)') 'usage: netcdf_fortran_roundtrip OUTPUT.nc'
        stop 2
    end if
    call get_command_argument(1, output_path)
    expected = [(200 + index, index = 1, sample_count)]
    observed = 0

    call check(nf90_create(trim(output_path), &
                           ior(nf90_clobber, nf90_netcdf4), ncid))
    call check(nf90_def_dim(ncid, 'sample', sample_count, dimid))
    call check(nf90_def_var(ncid, 'value', nf90_int, [dimid], varid))
    call check(nf90_def_var_deflate(ncid, varid, 0, 1, 6))
    call check(nf90_enddef(ncid))
    call check(nf90_put_var(ncid, varid, expected))
    call check(nf90_close(ncid))

    call check(nf90_open(trim(output_path), nf90_nowrite, ncid))
    call check(nf90_inq_varid(ncid, 'value', varid))
    call check(nf90_get_var(ncid, varid, observed))
    call check(nf90_close(ncid))

    if (any(observed /= expected)) then
        write (*, '(a)') 'netCDF-Fortran smoke: round-trip mismatch'
        stop 1
    end if

    write (*, '(a)') 'netcdf_fortran_format=netCDF-4 deflate_level=6'
    write (*, '(a)') 'netcdf_fortran_roundtrip=PASS'

contains

    subroutine check(code)
        integer, intent(in) :: code

        if (code /= nf90_noerr) then
            write (*, '(a,a)') 'netCDF-Fortran smoke failed: ', &
                trim(nf90_strerror(code))
            stop 1
        end if
    end subroutine check
end program netcdf_fortran_roundtrip
