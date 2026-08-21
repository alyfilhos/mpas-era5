#include <inttypes.h>
#include <math.h>
#include <netcdf.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    size_t count;
    size_t negative;
    double minimum;
    double maximum;
    long double sum;
    uint64_t checksum;
} stats_t;

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

static int open_cdf2(const char *path)
{
    int ncid, format;
    check(nc_open(path, NC_NOWRITE, &ncid), path);
    check(nc_inq_format(ncid, &format), path);
    if (format != NC_FORMAT_64BIT_OFFSET) fail("expected CDF-2 / 64-bit offset");
    return ncid;
}

static void require_dim(int ncid, const char *name, size_t expected)
{
    int dimid;
    size_t actual;
    check(nc_inq_dimid(ncid, name, &dimid), name);
    check(nc_inq_dimlen(ncid, dimid, &actual), name);
    if (actual != expected) {
        fprintf(stderr, "error: dimension %s=%zu, expected %zu\n", name, actual, expected);
        exit(EXIT_FAILURE);
    }
}

static size_t var_count(int ncid, int varid, const char *name)
{
    int ndims, dimids[NC_MAX_VAR_DIMS];
    size_t count = 1;
    check(nc_inq_varndims(ncid, varid, &ndims), name);
    check(nc_inq_vardimid(ncid, varid, dimids), name);
    for (int i = 0; i < ndims; ++i) {
        size_t length;
        check(nc_inq_dimlen(ncid, dimids[i], &length), name);
        count *= length;
    }
    return count;
}

static double *load_var(int ncid, const char *name, size_t *count_out)
{
    int varid;
    size_t count;
    double *values;
    check(nc_inq_varid(ncid, name, &varid), name);
    count = var_count(ncid, varid, name);
    if (count == 0) fail("zero-length required variable");
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

static uint64_t hash_double(uint64_t hash, double value)
{
    unsigned char bytes[sizeof(value)];
    memcpy(bytes, &value, sizeof(value));
    for (size_t i = 0; i < sizeof(value); ++i) {
        hash ^= bytes[i];
        hash *= UINT64_C(1099511628211);
    }
    return hash;
}

static stats_t compute_stats(int ncid, const char *name, double low, double high,
                             bool reject_missing)
{
    int varid;
    size_t count;
    double *values = load_var(ncid, name, &count);
    double fill = 0.0, missing = 0.0;
    bool has_fill, has_missing;
    stats_t stats = {
        .count = count,
        .negative = 0,
        .minimum = INFINITY,
        .maximum = -INFINITY,
        .sum = 0.0L,
        .checksum = UINT64_C(1469598103934665603),
    };
    check(nc_inq_varid(ncid, name, &varid), name);
    has_fill = marker(ncid, varid, "_FillValue", &fill);
    has_missing = marker(ncid, varid, "missing_value", &missing);
    for (size_t i = 0; i < count; ++i) {
        double value = values[i];
        if (!isfinite(value)) {
            fprintf(stderr, "error: %s[%zu] is NaN or Inf\n", name, i);
            exit(EXIT_FAILURE);
        }
        if (reject_missing && ((has_fill && value == fill) || (has_missing && value == missing))) {
            fprintf(stderr, "error: %s[%zu] is fill/missing\n", name, i);
            exit(EXIT_FAILURE);
        }
        if (value < low || value > high) {
            fprintf(stderr, "error: %s[%zu]=%.17g outside [%.17g, %.17g]\n",
                    name, i, value, low, high);
            exit(EXIT_FAILURE);
        }
        if (value < 0.0) ++stats.negative;
        if (value < stats.minimum) stats.minimum = value;
        if (value > stats.maximum) stats.maximum = value;
        stats.sum += value;
        stats.checksum = hash_double(stats.checksum, value);
    }
    free(values);
    return stats;
}

static void print_stats(const char *prefix, const char *name, stats_t stats)
{
    printf("%s_%s=min:%.9g max:%.9g mean:%.9Lg count:%zu negative:%zu checksum_fnv1a64:%016" PRIx64 "\n",
           prefix, name, stats.minimum, stats.maximum, stats.sum / stats.count,
           stats.count, stats.negative, stats.checksum);
}

static stats_t scan_field(int ncid, const char *prefix, const char *name,
                          double low, double high)
{
    stats_t stats = compute_stats(ncid, name, low, high, true);
    print_stats(prefix, name, stats);
    return stats;
}

static void require_timestamp(int ncid, const char *name, const char *expected)
{
    int varid;
    nc_type type;
    size_t count;
    char *value;
    check(nc_inq_varid(ncid, name, &varid), name);
    check(nc_inq_vartype(ncid, varid, &type), name);
    if (type != NC_CHAR) fail("timestamp is not NC_CHAR");
    count = var_count(ncid, varid, name);
    if (count < strlen(expected)) fail("timestamp is too short");
    value = malloc(count);
    if (value == NULL) fail("memory allocation failed");
    check(nc_get_var_text(ncid, varid, value), name);
    if (memcmp(value, expected, strlen(expected)) != 0) {
        fprintf(stderr, "error: %s timestamp mismatch, expected %s\n", name, expected);
        exit(EXIT_FAILURE);
    }
    free(value);
}

static size_t scan_all_numeric(int ncid, const char *label)
{
    int nvars;
    size_t total = 0;
    check(nc_inq_nvars(ncid, &nvars), label);
    for (int varid = 0; varid < nvars; ++varid) {
        char name[NC_MAX_NAME + 1];
        nc_type type;
        size_t count;
        double *values;
        check(nc_inq_varname(ncid, varid, name), label);
        check(nc_inq_vartype(ncid, varid, &type), name);
        if (type == NC_CHAR || type == NC_STRING) continue;
        count = var_count(ncid, varid, name);
        if (count == 0) continue;
        values = malloc(count * sizeof(*values));
        if (values == NULL) fail("memory allocation failed");
        check(nc_get_var_double(ncid, varid, values), name);
        for (size_t i = 0; i < count; ++i) {
            if (!isfinite(values[i])) {
                fprintf(stderr, "error: %s:%s[%zu] is NaN or Inf\n", label, name, i);
                exit(EXIT_FAILURE);
            }
        }
        total += count;
        free(values);
    }
    printf("all_numeric_nonfinite_%s=0 values_scanned=%zu\n", label, total);
    return total;
}

static size_t compare_field(int ncid0, int ncid1, const char *name,
                            double low, double high, bool require_changed)
{
    size_t count0, count1, changed = 0;
    double *before = load_var(ncid0, name, &count0);
    double *after = load_var(ncid1, name, &count1);
    double max_abs_diff = 0.0;
    long double sum_abs_diff = 0.0L;
    stats_t stats0 = compute_stats(ncid0, name, low, high, true);
    stats_t stats1 = compute_stats(ncid1, name, low, high, true);
    if (count0 != count1) fail("temporal variable count mismatch");
    for (size_t i = 0; i < count0; ++i) {
        double difference = fabs(after[i] - before[i]);
        if (after[i] != before[i]) ++changed;
        if (difference > max_abs_diff) max_abs_diff = difference;
        sum_abs_diff += difference;
    }
    print_stats("t0", name, stats0);
    print_stats("t1h", name, stats1);
    printf("evolution_%s=changed:%zu/%zu max_abs_diff:%.9g mean_abs_diff:%.9Lg\n",
           name, changed, count0, max_abs_diff, sum_abs_diff / count0);
    free(before);
    free(after);
    if (require_changed && changed == 0) fail("required prognostic field did not evolve");
    return changed;
}

static void validate_temperature(int ncid)
{
    size_t np, nt;
    double *pressure = load_var(ncid, "pressure", &np);
    double *theta = load_var(ncid, "theta", &nt);
    double minimum = INFINITY, maximum = -INFINITY;
    const double rd = 287.0, cp = 1004.5, p0 = 100000.0;
    if (np != nt) fail("pressure/theta count mismatch");
    for (size_t i = 0; i < np; ++i) {
        double temperature;
        if (!isfinite(pressure[i]) || pressure[i] <= 0.0) fail("invalid pressure");
        temperature = theta[i] * pow(pressure[i] / p0, rd / cp);
        if (!isfinite(temperature) || temperature < 100.0 || temperature > 400.0)
            fail("derived temperature outside corruption-detection range");
        if (temperature < minimum) minimum = temperature;
        if (temperature > maximum) maximum = temperature;
    }
    free(pressure);
    free(theta);
    printf("derived_temperature_K=%.9g..%.9g nonfinite=0\n", minimum, maximum);
}

static void validate_history_layout(int ncid, const char *time)
{
    require_dim(ncid, "nCells", 10242);
    require_dim(ncid, "nEdges", 30720);
    require_dim(ncid, "nVertices", 20480);
    require_dim(ncid, "nVertLevels", 55);
    require_dim(ncid, "nVertLevelsP1", 56);
    require_dim(ncid, "nSoilLevels", 4);
    require_dim(ncid, "Time", 1);
    require_timestamp(ncid, "xtime", time);
    require_timestamp(ncid, "initial_time", "2014-09-10_00:00:00");
}

static void validate_diag_layout(int ncid, const char *time)
{
    require_dim(ncid, "nCells", 10242);
    require_dim(ncid, "Time", 1);
    require_timestamp(ncid, "xtime", time);
    require_timestamp(ncid, "initial_time", "2014-09-10_00:00:00");
}

int main(int argc, char **argv)
{
    int init, history0, history1, diag0, diag1;
    stats_t qv_init, qv_final;
    size_t changed_required = 0;
    const double q2_diagnostic_floor = -1e-3;
    if (argc != 6) {
        fprintf(stderr, "usage: %s INIT_NC HISTORY_T0 HISTORY_T1 DIAG_T0 DIAG_T1\n", argv[0]);
        return 2;
    }

    init = open_cdf2(argv[1]);
    history0 = open_cdf2(argv[2]);
    history1 = open_cdf2(argv[3]);
    diag0 = open_cdf2(argv[4]);
    diag1 = open_cdf2(argv[5]);
    puts("netcdf_format_all=64-bit-offset");

    validate_history_layout(history0, "2014-09-10_00:00:00");
    validate_history_layout(history1, "2014-09-10_01:00:00");
    validate_diag_layout(diag0, "2014-09-10_00:00:00");
    validate_diag_layout(diag1, "2014-09-10_01:00:00");
    puts("dimensions_and_timestamps=PASS");

    scan_all_numeric(history0, "history_t0");
    scan_all_numeric(history1, "history_t1h");
    scan_all_numeric(diag0, "diag_t0");
    scan_all_numeric(diag1, "diag_t1h");

    scan_field(history1, "final", "rho", 1e-6, 2.0);
    scan_field(history1, "final", "pressure", 100.0, 130000.0);
    scan_field(history1, "final", "theta", 100.0, 5000.0);
    qv_final = scan_field(history1, "final", "qv", -2e-5, 0.2);
    scan_field(history1, "final", "qc", -2e-5, 0.2);
    scan_field(history1, "final", "qr", -2e-5, 0.2);
    scan_field(history1, "final", "qi", -2e-5, 0.2);
    scan_field(history1, "final", "qs", -2e-5, 0.2);
    scan_field(history1, "final", "qg", -2e-5, 0.2);
    scan_field(history1, "final", "relhum", -0.2, 300.0);
    scan_field(history1, "final", "u", -300.0, 300.0);
    scan_field(history1, "final", "w", -100.0, 100.0);
    scan_field(history1, "final", "surface_pressure", 1000.0, 130000.0);
    scan_field(history1, "final", "skintemp", 150.0, 350.0);
    scan_field(history1, "final", "sst", 150.0, 350.0);
    scan_field(history1, "final", "tslb", 150.0, 350.0);
    scan_field(history1, "final", "smois", 0.0, 1.5);
    scan_field(history1, "final", "sh2o", 0.0, 1.5);
    scan_field(diag1, "final_diag", "t2m", 150.0, 350.0);
    /* The v8.4.1 revised surface-layer scheme extrapolates q2 without a clamp.
     * Keep a finite corruption guard and report every negative value separately. */
    scan_field(diag1, "final_diag", "q2", q2_diagnostic_floor, 0.2);
    scan_field(diag1, "final_diag", "u10", -200.0, 200.0);
    scan_field(diag1, "final_diag", "v10", -200.0, 200.0);
    validate_temperature(history1);

    qv_init = scan_field(init, "init", "qv", -2e-5, 0.2);
    printf("qv_minimum_change=init:%.9g final:%.9g delta:%.9g\n",
           qv_init.minimum, qv_final.minimum, qv_final.minimum - qv_init.minimum);

    changed_required += compare_field(history0, history1, "rho", 1e-6, 2.0, true) > 0;
    changed_required += compare_field(history0, history1, "theta", 100.0, 5000.0, true) > 0;
    changed_required += compare_field(history0, history1, "u", -300.0, 300.0, true) > 0;
    compare_field(history0, history1, "qv", -2e-5, 0.2, false);
    compare_field(history0, history1, "skintemp", 150.0, 350.0, false);
    if (compare_field(history0, history1, "sst", 150.0, 350.0, false) != 0)
        fail("SST changed even though config_sst_update is false");
    compare_field(diag0, diag1, "q2", q2_diagnostic_floor, 0.2, false);
    if (changed_required != 3) fail("not all required prognostic fields evolved");
    printf("required_prognostic_fields_evolved=%zu/3\n", changed_required);

    check(nc_close(init), "close init");
    check(nc_close(history0), "close history t0");
    check(nc_close(history1), "close history t1h");
    check(nc_close(diag0), "close diag t0");
    check(nc_close(diag1), "close diag t1h");
    puts("atmosphere_netcdf_validation=PASS");
    return 0;
}
