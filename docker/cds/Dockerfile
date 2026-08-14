FROM python:3.12.13-slim-bookworm@sha256:d50fb7611f86d04a3b0471b46d7557818d88983fc3136726336b2a4c657aa30b

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /workspace

COPY docker/cds/requirements.txt /tmp/requirements.txt

RUN python -m pip install --no-cache-dir --requirement /tmp/requirements.txt \
    && python -m pip check \
    && test "$(python -c 'import importlib.metadata; print(importlib.metadata.version("cdsapi"))')" = "0.7.7" \
    && rm -f /tmp/requirements.txt

COPY scripts/data/fetch-era5.py /usr/local/bin/fetch-era5.py

LABEL org.opencontainers.image.title="MPAS-ERA5 CDS acquisition client" \
      org.opencontainers.image.description="Isolated ERA5 acquisition client; contains no MPAS/WPS software or CDS credentials" \
      org.opencontainers.image.version="cdsapi-0.7.7"

ENTRYPOINT ["python", "/usr/local/bin/fetch-era5.py"]
