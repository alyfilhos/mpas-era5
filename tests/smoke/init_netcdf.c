#include <math.h>
#include <netcdf.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LEN(a) (sizeof(a) / sizeof((a)[0]))

static void fail(const char *message)
{
    fprintf(stderr, "error: %s\n", message);
    exit(EXIT_FAILURE);
}

static void check(int status, const char *context)
{
    if (status != NC_NOERR) {
        fprintf(stderr, "error: %s: %s\n", context, nc_strerror(status));
        exit(EXIT_FAILURE);
    }
}

static void require_dim(int ncid, const char *name, size_t expected)
{
    int id;
    size_t actual;
    check(nc_inq_dimid(ncid, name, &id), name);
    check(nc_inq_dimlen(ncid, id, &actual), name);
    if (actual != expected) {
        fprintf(stderr, "error: dimension %s=%zu, expected %zu\n", name, actual, expected);
        exit(EXIT_FAILURE);
    }
    printf("dimension_%s=%zu\n", name, actual);
}

static size_t require_shape(int ncid, const char *name, size_t expected_ndims,
                            const char *const expected[])
{
    int varid, ndims, dimids[NC_MAX_VAR_DIMS];
    size_t count = 1;
    check(nc_inq_varid(ncid, name, &varid), name);
    check(nc_inq_varndims(ncid, varid, &ndims), name);
    if ((size_t)ndims != expected_ndims) fail("unexpected variable rank");
    check(nc_inq_vardimid(ncid, varid, dimids), name);
    for (int i = 0; i < ndims; ++i) {
        char actual[NC_MAX_NAME + 1];
        size_t length;
        check(nc_inq_dimname(ncid, dimids[i], actual), name);
        check(nc_inq_dimlen(ncid, dimids[i], &length), name);
        if (strcmp(actual, expected[i]) != 0) {
            fprintf(stderr, "error: %s dimension %d is %s, expected %s\n",
                    name, i, actual, expected[i]);
            exit(EXIT_FAILURE);
        }
        count *= length;
    }
    return count;
}

static double *load_var(int ncid, const char *name, size_t *count_out)
{
    int varid, ndims, dimids[NC_MAX_VAR_DIMS];
    nc_type type;
    size_t count = 1;
    double *values;
    check(nc_inq_varid(ncid, name, &varid), name);
    check(nc_inq_vartype(ncid, varid, &type), name);
    if (type == NC_CHAR || type == NC_STRING) fail("expected numeric variable");
    check(nc_inq_varndims(ncid, varid, &ndims), name);
    check(nc_inq_vardimid(ncid, varid, dimids), name);
    for (int i = 0; i < ndims; ++i) {
        size_t length;
        check(nc_inq_dimlen(ncid, dimids[i], &length), name);
        count *= length;
    }
    values = malloc(count * sizeof(*values));
    if (values == NULL) fail("memory allocation failed");
    check(nc_get_var_double(ncid, varid, values), name);
    *count_out = count;
    return values;
}

static bool marker(int ncid, int varid, const char *name, double *value)
{
    int status = nc_get_att_double(ncid, varid, name, value);
    if (status == NC_ENOTATT) return false;
    check(status, name);
    return true;
}

static void scan(int ncid, const char *name, double low, double high)
{
    int varid;
    size_t count, negative = 0;
    double *values = load_var(ncid, name, &count);
    double fill = 0.0, missing = 0.0, minimum = INFINITY, maximum = -INFINITY;
    bool has_fill, has_missing;
    check(nc_inq_varid(ncid, name, &varid), name);
    has_fill = marker(ncid, varid, "_FillValue", &fill);
    has_missing = marker(ncid, varid, "missing_value", &missing);
    for (size_t i = 0; i < count; ++i) {
        double value = values[i];
        if (!isfinite(value)) fail("NaN or Inf found");
        if ((has_fill && value == fill) || (has_missing && value == missing))
            fail("fill/missing value found");
        if (value < low || value > high) {
            fprintf(stderr, "error: %s[%zu]=%.17g outside [%.17g, %.17g]\n",
                    name, i, value, low, high);
            exit(EXIT_FAILURE);
        }
        if (value < 0.0) ++negative;
        if (value < minimum) minimum = value;
        if (value > maximum) maximum = value;
    }
    printf("range_%s=%.9g..%.9g count=%zu negative=%zu missing=0 nonfinite=0\n",
           name, minimum, maximum, count, negative);
    free(values);
}

static void require_timestamp(int ncid, const char *name)
{
    static const char expected[] = "2014-09-10_00:00:00";
    int varid, ndims, dimids[NC_MAX_VAR_DIMS];
    nc_type type;
    size_t count = 1;
    char *value;
    check(nc_inq_varid(ncid, name, &varid), name);
    check(nc_inq_vartype(ncid, varid, &type), name);
    if (type != NC_CHAR) fail("timestamp is not NC_CHAR");
    check(nc_inq_varndims(ncid, varid, &ndims), name);
    check(nc_inq_vardimid(ncid, varid, dimids), name);
    for (int i = 0; i < ndims; ++i) {
        size_t length;
        check(nc_inq_dimlen(ncid, dimids[i], &length), name);
        count *= length;
    }
    if (count < strlen(expected)) fail("timestamp is too short");
    value = malloc(count);
    if (value == NULL) fail("memory allocation failed");
    check(nc_get_var_text(ncid, varid, value), name);
    if (memcmp(value, expected, strlen(expected)) != 0) fail("timestamp mismatch");
    free(value);
    printf("%s=%s\n", name, expected);
}

static void require_att_int(int ncid, const char *name, int expected)
{
    int actual;
    check(nc_get_att_int(ncid, NC_GLOBAL, name, &actual), name);
    if (actual != expected) {
        fprintf(stderr, "error: attribute %s=%d, expected %d\n",
                name, actual, expected);
        exit(EXIT_FAILURE);
    }
}

static void require_att_double(int ncid, const char *name, double expected)
{
    double actual;
    check(nc_get_att_double(ncid, NC_GLOBAL, name, &actual), name);
    if (!isfinite(actual) || fabs(actual - expected) > 1e-6) {
        fprintf(stderr, "error: attribute %s=%.17g, expected %.17g\n",
                name, actual, expected);
        exit(EXIT_FAILURE);
    }
}

static void require_att_text(int ncid, const char *name, const char *expected)
{
    nc_type type;
    size_t length;
    char *actual;
    check(nc_inq_atttype(ncid, NC_GLOBAL, name, &type), name);
    check(nc_inq_attlen(ncid, NC_GLOBAL, name, &length), name);
    if (type != NC_CHAR) fail("expected text global attribute");
    actual = malloc(length + 1);
    if (actual == NULL) fail("memory allocation failed");
    check(nc_get_att_text(ncid, NC_GLOBAL, name, actual), name);
    actual[length] = '\0';
    if (strcmp(actual, expected) != 0) {
        fprintf(stderr, "error: attribute %s=%s, expected %s\n",
                name, actual, expected);
        exit(EXIT_FAILURE);
    }
    free(actual);
}

static void validate_configuration(int ncid)
{
    require_att_text(ncid, "version", "8.4.1");
    require_att_int(ncid, "config_init_case", 7);
    require_att_text(ncid, "config_start_time", "2014-09-10_00:00:00");
    require_att_int(ncid, "config_nvertlevels", 55);
    require_att_int(ncid, "config_nsoillevels", 4);
    require_att_int(ncid, "config_nfglevels", 38);
    require_att_int(ncid, "config_nfgsoillevels", 4);
    require_att_text(ncid, "config_met_prefix", "ERA5");
    require_att_text(ncid, "config_use_spechumd", "NO");
    require_att_text(ncid, "config_noahmp_static", "NO");
    require_att_double(ncid, "config_ztop", 30000.0);
    require_att_text(ncid, "config_extrap_airtemp", "lapse-rate");
    require_att_text(ncid, "config_static_interp", "NO");
    require_att_text(ncid, "config_native_gwd_static", "NO");
    require_att_text(ncid, "config_native_gwd_gsl_static", "NO");
    require_att_text(ncid, "config_vertical_grid", "YES");
    require_att_text(ncid, "config_met_interp", "YES");
    require_att_text(ncid, "config_input_sst", "NO");
    require_att_text(ncid, "config_frac_seaice", "YES");
    require_att_text(ncid, "config_block_decomp_file_prefix",
                     "x1.10242.graph.info.part.");
    puts("configuration_attributes=PASS");
}

static void validate_zgrid(int ncid)
{
    static const char *const dims[] = {"nCells", "nVertLevelsP1"};
    size_t count = require_shape(ncid, "zgrid", LEN(dims), dims), loaded;
    double *z = load_var(ncid, "zgrid", &loaded);
    double min_dz = INFINITY, max_dz = -INFINITY;
    double min_top = INFINITY, max_top = -INFINITY;
    if (loaded != count) fail("zgrid count mismatch");
    for (size_t cell = 0; cell < 10242; ++cell) {
        for (size_t level = 1; level < 56; ++level) {
            double dz = z[cell * 56 + level] - z[cell * 56 + level - 1];
            if (!isfinite(dz) || dz <= 0.0) fail("non-positive vertical thickness");
            if (dz < min_dz) min_dz = dz;
            if (dz > max_dz) max_dz = dz;
        }
        double top = z[cell * 56 + 55];
        if (!isfinite(top) || top < 29000.0 || top > 31000.0)
            fail("vertical top is inconsistent with 30 km");
        if (top < min_top) min_top = top;
        if (top > max_top) max_top = top;
    }
    free(z);
    printf("vertical_grid=monotonic_positive\nvertical_thickness_m=%.9g..%.9g\n",
           min_dz, max_dz);
    printf("vertical_top_m=%.9g..%.9g\n", min_top, max_top);
}

static void validate_eos(int ncid)
{
    size_t nr, nt, nq;
    double *rho = load_var(ncid, "rho", &nr);
    double *theta = load_var(ncid, "theta", &nt);
    double *qv = load_var(ncid, "qv", &nq);
    double pmin = INFINITY, pmax = -INFINITY, tmin = INFINITY, tmax = -INFINITY;
    const double rd = 287.0, cp = 1004.5, cv = cp - rd, p0 = 100000.0;
    if (nr != nt || nr != nq) fail("rho/theta/qv count mismatch");
    for (size_t i = 0; i < nr; ++i) {
        double base = rho[i] * rd * theta[i] * (1.0 + 1.61 * qv[i]) / p0;
        double pressure, temperature;
        if (!isfinite(base) || base <= 0.0) fail("invalid equation-of-state base");
        pressure = p0 * pow(base, cp / cv);
        temperature = theta[i] * pow(pressure / p0, rd / cp);
        if (!isfinite(pressure) || pressure < 100.0 || pressure > 130000.0)
            fail("derived pressure outside corruption-detection range");
        if (!isfinite(temperature) || temperature < 100.0 || temperature > 400.0)
            fail("derived temperature outside corruption-detection range");
        if (pressure < pmin) pmin = pressure;
        if (pressure > pmax) pmax = pressure;
        if (temperature < tmin) tmin = temperature;
        if (temperature > tmax) tmax = temperature;
    }
    free(rho); free(theta); free(qv);
    printf("range_pressure_derived_Pa=%.9g..%.9g\n", pmin, pmax);
    printf("range_temperature_derived_K=%.9g..%.9g\n", tmin, tmax);
}

static void require_absent(int ncid, const char *name)
{
    int varid;
    int status = nc_inq_varid(ncid, name, &varid);
    if (status == NC_NOERR) fail("Noah-MP-only variable unexpectedly present");
    if (status != NC_ENOTVAR) check(status, name);
    printf("absent_%s=true\n", name);
}

int main(int argc, char **argv)
{
    int ncid, format;
    static const char *const cell3d[] = {"Time", "nCells", "nVertLevels"};
    static const char *const edge3d[] = {"Time", "nEdges", "nVertLevels"};
    static const char *const cell3dp1[] = {"Time", "nCells", "nVertLevelsP1"};
    static const char *const soil3d[] = {"Time", "nCells", "nSoilLevels"};
    static const char *const cell2d[] = {"Time", "nCells"};
    if (argc != 2) { fprintf(stderr, "usage: %s INIT_NC\n", argv[0]); return 2; }
    check(nc_open(argv[1], NC_NOWRITE, &ncid), "open init.nc");
    check(nc_inq_format(ncid, &format), "format");
    if (format != NC_FORMAT_64BIT_OFFSET) fail("expected CDF-2");
    puts("netcdf_format=64-bit-offset");
    require_dim(ncid, "nCells", 10242); require_dim(ncid, "nEdges", 30720);
    require_dim(ncid, "nVertices", 20480); require_dim(ncid, "nVertLevels", 55);
    require_dim(ncid, "nVertLevelsP1", 56); require_dim(ncid, "nSoilLevels", 4);
    require_dim(ncid, "Time", 1);
    require_timestamp(ncid, "xtime"); require_timestamp(ncid, "initial_time");
    validate_configuration(ncid);
    require_shape(ncid, "rho", LEN(cell3d), cell3d);
    require_shape(ncid, "theta", LEN(cell3d), cell3d);
    require_shape(ncid, "qv", LEN(cell3d), cell3d);
    require_shape(ncid, "relhum", LEN(cell3d), cell3d);
    require_shape(ncid, "u", LEN(edge3d), edge3d);
    require_shape(ncid, "w", LEN(cell3dp1), cell3dp1);
    require_shape(ncid, "tslb", LEN(soil3d), soil3d);
    require_shape(ncid, "smois", LEN(soil3d), soil3d);
    require_shape(ncid, "sh2o", LEN(soil3d), soil3d);
    require_shape(ncid, "dz", LEN(soil3d), soil3d);
    require_shape(ncid, "dzs", LEN(soil3d), soil3d);
    require_shape(ncid, "zs", LEN(soil3d), soil3d);
    require_shape(ncid, "surface_pressure", LEN(cell2d), cell2d);
    validate_zgrid(ncid);
    scan(ncid, "rho", 1e-6, 2.0); scan(ncid, "theta", 100.0, 5000.0);
    /* v8.4.1 converts interpolated RH without a lower clamp; tolerate only the observed tiny overshoot. */
    scan(ncid, "qv", -2e-5, 0.2); scan(ncid, "relhum", -0.2, 300.0);
    scan(ncid, "u", -300.0, 300.0); scan(ncid, "w", -100.0, 100.0);
    scan(ncid, "surface_pressure", 1000.0, 130000.0);
    scan(ncid, "skintemp", 150.0, 350.0); scan(ncid, "sst", 150.0, 350.0);
    scan(ncid, "t2m", 150.0, 350.0); scan(ncid, "q2", 0.0, 0.2);
    scan(ncid, "rh2", 0.0, 300.0); scan(ncid, "u10", -200.0, 200.0);
    scan(ncid, "v10", -200.0, 200.0); scan(ncid, "xice", 0.0, 1.0);
    scan(ncid, "seaice", 0.0, 1.0); scan(ncid, "snow", 0.0, 10000.0);
    scan(ncid, "snowc", 0.0, 1.0); scan(ncid, "snowh", 0.0, 100.0);
    scan(ncid, "tslb", 150.0, 350.0); scan(ncid, "smois", 0.0, 1.5);
    scan(ncid, "sh2o", 0.0, 1.5); scan(ncid, "tmn", 150.0, 350.0);
    scan(ncid, "dz", 0.0, 10.0); scan(ncid, "dzs", 1e-6, 10.0);
    scan(ncid, "zs", 0.0, 10.0); validate_eos(ncid);
    require_absent(ncid, "soilcomp"); require_absent(ncid, "soilcl1");
    require_absent(ncid, "soilcl2"); require_absent(ncid, "soilcl3");
    require_absent(ncid, "soilcl4");
    check(nc_close(ncid), "close"); puts("init_netcdf_validation=PASS");
    return 0;
}
