#include <errno.h>
#include <math.h>
#include <netcdf.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define EXPECTED_CELLS 10242
#define EXPECTED_EDGES 30720
#define EXPECTED_VERTICES 20480
#define EXPECTED_MONTHS 12

struct field_check {
    const char *name;
    size_t multiplier;
    double lower;
    double upper;
    int integral;
    int require_variation;
};

static void nc_fail(const char *operation, int status)
{
    fprintf(stderr, "error: %s: %s\n", operation, nc_strerror(status));
    exit(EXIT_FAILURE);
}

static size_t dimension_length(int ncid, const char *name)
{
    int dimid;
    size_t length;
    int status = nc_inq_dimid(ncid, name, &dimid);

    if (status != NC_NOERR)
        nc_fail(name, status);
    status = nc_inq_dimlen(ncid, dimid, &length);
    if (status != NC_NOERR)
        nc_fail(name, status);
    printf("dimension=%s length=%zu\n", name, length);
    return length;
}

static size_t variable_size(int ncid, int varid)
{
    int ndims;
    int dimids[NC_MAX_VAR_DIMS];
    size_t total = 1;
    int status = nc_inq_var(ncid, varid, NULL, NULL, &ndims, dimids, NULL);

    if (status != NC_NOERR)
        nc_fail("nc_inq_var", status);
    for (int i = 0; i < ndims; ++i) {
        size_t length;
        status = nc_inq_dimlen(ncid, dimids[i], &length);
        if (status != NC_NOERR)
            nc_fail("nc_inq_dimlen", status);
        if (length != 0 && total > SIZE_MAX / length) {
            fprintf(stderr, "error: variable size overflow\n");
            exit(EXIT_FAILURE);
        }
        total *= length;
    }
    return total;
}

static double *read_numeric_variable(int ncid, const char *name, size_t *count)
{
    int varid;
    nc_type type;
    int status = nc_inq_varid(ncid, name, &varid);

    if (status != NC_NOERR)
        nc_fail(name, status);
    status = nc_inq_vartype(ncid, varid, &type);
    if (status != NC_NOERR)
        nc_fail(name, status);
    if (type == NC_CHAR || type == NC_STRING) {
        fprintf(stderr, "error: expected numeric variable: %s\n", name);
        exit(EXIT_FAILURE);
    }

    *count = variable_size(ncid, varid);
    double *values = malloc(*count * sizeof(*values));
    if (values == NULL) {
        fprintf(stderr, "error: allocation failed for %s\n", name);
        exit(EXIT_FAILURE);
    }
    status = nc_get_var_double(ncid, varid, values);
    if (status != NC_NOERR)
        nc_fail(name, status);
    return values;
}

static void check_field(int ncid, size_t n_cells, const struct field_check *check)
{
    int varid;
    int status = nc_inq_varid(ncid, check->name, &varid);
    size_t count;
    double *values;
    double minimum = HUGE_VAL;
    double maximum = -HUGE_VAL;
    double fill_value = 0.0;
    double missing_value = 0.0;
    int has_fill;
    int has_missing;
    size_t invalid = 0;
    size_t non_finite = 0;
    size_t non_integral = 0;

    if (status != NC_NOERR)
        nc_fail(check->name, status);
    count = variable_size(ncid, varid);
    if (count != n_cells * check->multiplier) {
        fprintf(stderr, "error: %s has %zu values; expected %zu\n",
                check->name, count, n_cells * check->multiplier);
        exit(EXIT_FAILURE);
    }

    values = read_numeric_variable(ncid, check->name, &count);
    has_fill = nc_get_att_double(ncid, varid, "_FillValue", &fill_value) == NC_NOERR;
    has_missing = nc_get_att_double(ncid, varid, "missing_value", &missing_value) == NC_NOERR;

    for (size_t i = 0; i < count; ++i) {
        double value = values[i];

        if (!isfinite(value)) {
            ++non_finite;
            continue;
        }
        if ((has_fill && value == fill_value) ||
            (has_missing && value == missing_value)) {
            ++invalid;
            continue;
        }
        if (value < minimum)
            minimum = value;
        if (value > maximum)
            maximum = value;
        if (check->integral && fabs(value - nearbyint(value)) > 1.0e-6)
            ++non_integral;
    }

    printf("field=%s count=%zu min=%.9g max=%.9g missing=%zu nan_inf=%zu",
           check->name, count, minimum, maximum, invalid, non_finite);
    if (check->integral)
        printf(" non_integral=%zu", non_integral);
    putchar('\n');

    if (invalid != 0 || non_finite != 0 || non_integral != 0 ||
        minimum < check->lower || maximum > check->upper ||
        (check->require_variation && minimum == maximum)) {
        fprintf(stderr, "error: validation failed for field %s\n", check->name);
        free(values);
        exit(EXIT_FAILURE);
    }
    free(values);
}

static void check_global_int(int ncid, const char *name, int expected)
{
    int value;
    int status = nc_get_att_int(ncid, NC_GLOBAL, name, &value);

    if (status != NC_NOERR)
        nc_fail(name, status);
    printf("global_attribute=%s value=%d\n", name, value);
    if (value != expected) {
        fprintf(stderr, "error: %s is %d; expected %d\n", name, value, expected);
        exit(EXIT_FAILURE);
    }
}

static void check_global_text(int ncid, const char *name, const char *expected)
{
    size_t length;
    int status = nc_inq_attlen(ncid, NC_GLOBAL, name, &length);

    if (status != NC_NOERR)
        nc_fail(name, status);
    char *value = calloc(length + 1, 1);
    if (value == NULL) {
        fprintf(stderr, "error: allocation failed for attribute %s\n", name);
        exit(EXIT_FAILURE);
    }
    status = nc_get_att_text(ncid, NC_GLOBAL, name, value);
    if (status != NC_NOERR)
        nc_fail(name, status);
    printf("global_attribute=%s value=%s\n", name, value);
    if (strcmp(value, expected) != 0) {
        fprintf(stderr, "error: %s is %s; expected %s\n",
                name, value, expected);
        free(value);
        exit(EXIT_FAILURE);
    }
    free(value);
}

static void check_scalar_int(int ncid, const char *name, int expected)
{
    int varid;
    int value;
    int status = nc_inq_varid(ncid, name, &varid);

    if (status != NC_NOERR)
        nc_fail(name, status);
    status = nc_get_var_int(ncid, varid, &value);
    if (status != NC_NOERR)
        nc_fail(name, status);
    printf("scalar=%s value=%d\n", name, value);
    if (value != expected) {
        fprintf(stderr, "error: %s is %d; expected %d\n", name, value, expected);
        exit(EXIT_FAILURE);
    }
}

static void check_landuse_name(int ncid)
{
    int varid;
    size_t count;
    int status = nc_inq_varid(ncid, "mminlu", &varid);

    if (status != NC_NOERR)
        nc_fail("mminlu", status);
    count = variable_size(ncid, varid);
    char *value = calloc(count + 1, 1);
    if (value == NULL) {
        fprintf(stderr, "error: allocation failed for mminlu\n");
        exit(EXIT_FAILURE);
    }
    status = nc_get_var_text(ncid, varid, value);
    if (status != NC_NOERR)
        nc_fail("mminlu", status);
    for (size_t i = count; i > 0; --i) {
        if (value[i - 1] == ' ' || value[i - 1] == '\0')
            value[i - 1] = '\0';
        else
            break;
    }
    printf("landuse_classification=%s\n", value);
    if (strcmp(value, "MODIFIED_IGBP_MODIS_NOAH") != 0) {
        fprintf(stderr, "error: unexpected mminlu: %s\n", value);
        free(value);
        exit(EXIT_FAILURE);
    }
    free(value);
}

static void check_noahmp_absent(int ncid)
{
    static const char *const names[] = {
        "soilcomp", "soilcl1", "soilcl2", "soilcl3", "soilcl4"
    };

    for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); ++i) {
        int varid;
        int status = nc_inq_varid(ncid, names[i], &varid);
        if (status != NC_ENOTVAR) {
            fprintf(stderr, "error: Noah-MP-only variable unexpectedly present: %s\n",
                    names[i]);
            exit(EXIT_FAILURE);
        }
        printf("noahmp_variable_absent=%s\n", names[i]);
    }
}

static void check_shade_order(int ncid, size_t n_cells)
{
    size_t min_count;
    size_t max_count;
    double *minimum = read_numeric_variable(ncid, "shdmin", &min_count);
    double *maximum = read_numeric_variable(ncid, "shdmax", &max_count);
    size_t violations = 0;

    if (min_count != n_cells || max_count != n_cells) {
        fprintf(stderr, "error: shade field dimensions are inconsistent\n");
        exit(EXIT_FAILURE);
    }
    for (size_t i = 0; i < n_cells; ++i) {
        if (minimum[i] > maximum[i])
            ++violations;
    }
    printf("shade_min_le_max_violations=%zu\n", violations);
    free(minimum);
    free(maximum);
    if (violations != 0)
        exit(EXIT_FAILURE);
}

int main(int argc, char **argv)
{
    static const struct field_check checks[] = {
        {"ter", 1, -500.0, 9000.0, 0, 1},
        {"landmask", 1, 0.0, 1.0, 1, 1},
        {"ivgtyp", 1, 1.0, 20.0, 1, 1},
        {"isltyp", 1, 1.0, 16.0, 1, 1},
        {"snoalb", 1, 0.0, 1.01, 0, 1},
        {"soiltemp", 1, 0.0, 350.0, 0, 1},
        {"greenfrac", EXPECTED_MONTHS, 0.0, 100.0, 0, 1},
        {"shdmin", 1, 0.0, 100.0, 0, 1},
        {"shdmax", 1, 0.0, 100.0, 0, 1},
        {"albedo12m", EXPECTED_MONTHS, 0.0, 100.0, 0, 1},
        {"var2d", 1, 0.0, 10000.0, 0, 1},
        {"con", 1, 0.0, 1000.0, 0, 1},
        {"oa1", 1, -1.01, 1.01, 0, 1},
        {"oa2", 1, -1.01, 1.01, 0, 1},
        {"oa3", 1, -1.01, 1.01, 0, 1},
        {"oa4", 1, -1.01, 1.01, 0, 1},
        {"ol1", 1, 0.0, 1.01, 0, 1},
        {"ol2", 1, 0.0, 1.01, 0, 1},
        {"ol3", 1, 0.0, 1.01, 0, 1},
        {"ol4", 1, 0.0, 1.01, 0, 1}
    };
    int ncid;
    int format;
    int status;
    size_t n_cells;
    size_t n_edges;
    size_t n_vertices;
    size_t n_months;
    size_t time_length;

    if (argc != 2) {
        fprintf(stderr, "usage: %s static.nc\n", argv[0]);
        return EXIT_FAILURE;
    }

    status = nc_open(argv[1], NC_NOWRITE, &ncid);
    if (status != NC_NOERR)
        nc_fail("nc_open", status);
    status = nc_inq_format(ncid, &format);
    if (status != NC_NOERR)
        nc_fail("nc_inq_format", status);
    printf("netcdf_format_code=%d\n", format);
    if (format != NC_FORMAT_64BIT_OFFSET) {
        fprintf(stderr, "error: expected CDF-2/64-bit-offset format\n");
        return EXIT_FAILURE;
    }

    n_cells = dimension_length(ncid, "nCells");
    n_edges = dimension_length(ncid, "nEdges");
    n_vertices = dimension_length(ncid, "nVertices");
    n_months = dimension_length(ncid, "nMonths");
    time_length = dimension_length(ncid, "Time");
    if (n_cells != EXPECTED_CELLS || n_edges != EXPECTED_EDGES ||
        n_vertices != EXPECTED_VERTICES || n_months != EXPECTED_MONTHS ||
        time_length != 1) {
        fprintf(stderr, "error: core dimensions are inconsistent\n");
        return EXIT_FAILURE;
    }

    check_global_text(ncid, "core_name", "init_atmosphere");
    check_global_text(ncid, "version", "8.4.1");
    check_global_int(ncid, "config_init_case", 7);
    check_global_int(ncid, "config_supersample_factor", 1);
    check_global_int(ncid, "config_lu_supersample_factor", 1);
    check_global_int(ncid, "config_30s_supersample_factor", 1);
    check_global_text(ncid, "config_noahmp_static", "NO");
    check_global_text(ncid, "config_static_interp", "YES");
    check_global_text(ncid, "config_native_gwd_static", "YES");
    check_global_text(ncid, "config_native_gwd_gsl_static", "NO");
    check_global_text(ncid, "config_vertical_grid", "NO");
    check_global_text(ncid, "config_met_interp", "NO");
    check_global_text(ncid, "config_input_sst", "NO");
    check_global_text(ncid, "config_frac_seaice", "NO");

    check_landuse_name(ncid);
    check_scalar_int(ncid, "isice_lu", 15);
    check_scalar_int(ncid, "iswater_lu", 17);
    check_noahmp_absent(ncid);

    for (size_t i = 0; i < sizeof(checks) / sizeof(checks[0]); ++i)
        check_field(ncid, n_cells, &checks[i]);
    check_shade_order(ncid, n_cells);

    status = nc_close(ncid);
    if (status != NC_NOERR)
        nc_fail("nc_close", status);
    puts("static_netcdf_validation=PASS");
    return EXIT_SUCCESS;
}
