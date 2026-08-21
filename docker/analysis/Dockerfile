FROM python:3.12.13-slim-bookworm@sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b

LABEL org.opencontainers.image.title="MPAS-ERA5 analysis environment" \
      org.opencontainers.image.description="Read-only scientific diagnostics and deterministic figures for cycle 0014" \
      org.opencontainers.image.version="0014"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    MPLBACKEND=Agg \
    MPLCONFIGDIR=/tmp/matplotlib

WORKDIR /analysis

COPY docker/analysis/requirements.lock /tmp/requirements.lock

RUN python -m pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --only-binary=:all: \
        --require-hashes \
        --requirement /tmp/requirements.lock \
    && python -m pip check \
    && python -c "import matplotlib, netCDF4, numpy, xarray; assert matplotlib.__version__ == '3.11.1'; assert netCDF4.__version__ == '1.7.4'; assert numpy.__version__ == '2.5.2'; assert xarray.__version__ == '2026.7.0'" \
    && rm /tmp/requirements.lock

COPY scripts/analyze/first-atmosphere-run.py /usr/local/bin/first-atmosphere-run.py

ENTRYPOINT ["python", "/usr/local/bin/first-atmosphere-run.py"]
