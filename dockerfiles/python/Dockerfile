FROM python:3.12.4-slim-bookworm@sha256:2fba8e70a87bcc9f6edd20dda0a1d4adb32046d2acbca7361bc61da5a106a914 as builder

# renovate: datasource=pypi depName=poetry versioning=semver
ENV POETRY_VERSION=1.8.3

WORKDIR /app

RUN set -ex; pip install --no-cache-dir poetry==$POETRY_VERSION;

ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache

COPY pyproject.toml poetry.lock ./

RUN poetry install --without dev --no-root && rm -rf $POETRY_CACHE_DIR

FROM python:3.12.4-slim-bookworm@sha256:2fba8e70a87bcc9f6edd20dda0a1d4adb32046d2acbca7361bc61da5a106a914 as runner

ENV VIRTUAL_ENV=/app/.venv
ENV PATH="/app/.venv/bin:$PATH"

WORKDIR /app

RUN mkdir -p logs

COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}

COPY service ./service

CMD sh -c 'uvicorn service.main:app --workers 1 --host 0.0.0.0  --port $SERVICE_PORT --reload'
