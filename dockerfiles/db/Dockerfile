ARG PG_VERSION=15
FROM postgres:${PG_VERSION}
RUN apt-get update

ENV build_deps ca-certificates \
  git \
  build-essential \
  libpq-dev \
  postgresql-server-dev-${PG_MAJOR} \
  curl \
  libreadline6-dev \
  zlib1g-dev \
  gnupg


RUN apt-get install -y --no-install-recommends $build_deps pkg-config cmake

WORKDIR /home/pg_graphql

ENV HOME=/home/pg_graphql \
  PATH=/home/pg_graphql/.cargo/bin:$PATH
RUN chown postgres:postgres /home/pg_graphql
USER postgres

RUN \
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal --default-toolchain nightly && \
  rustup --version && \
  rustc --version && \
  cargo --version

# PGRX
RUN cargo install cargo-pgrx --version 0.11.3 --locked

RUN cargo pgrx init --pg${PG_MAJOR} $(which pg_config)

USER root

COPY .cargo .cargo/
COPY .ci .ci/
COPY bin ./bin
COPY sql ./sql
COPY src ./src
COPY test ./test
COPY Cargo.lock Cargo.toml LICENSE pg_graphql.control ./

RUN cargo pgrx install
RUN apt-get install -y lsb-release && \
  curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null && \
  sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
  apt-get update -y && \
  apt-get install -y postgresql-${PG_MAJOR}-postgis-3 postgis

USER postgres
