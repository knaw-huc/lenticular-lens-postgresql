ARG PG_VERSION=17
ARG POSTGIS_VERSION=3.5

# ARG PG_BASE_IMAGE="postgres:${PG_VERSION}"
ARG PG_BASE_IMAGE="postgis/postgis:${PG_VERSION}-${POSTGIS_VERSION}"

FROM $PG_BASE_IMAGE AS builder

ARG PG_VERSION

RUN apt update && \
    apt install -y wget unzip build-essential python3-venv postgresql-server-dev-${PG_VERSION} postgresql-plpython3-${PG_VERSION}

RUN python3 -m venv /opt/venv
ENV PATH "/opt/venv/bin:$PATH"

RUN pip3 install build pyyaml toml

COPY ./ /opt

WORKDIR /opt
RUN python3 package.py

WORKDIR /opt/build
RUN ./build.sh && ./post-install.sh

FROM $PG_BASE_IMAGE

ARG PG_VERSION

COPY --from=builder /opt/build/python/dist/lenticular_lens-1.0-py3-none-any.whl /app/
COPY --from=builder /opt/build/post-install.sh /app/
COPY --from=builder /usr/lib/postgresql/${PG_VERSION}/lib/lenticular_lens.so /usr/lib/postgresql/${PG_VERSION}/lib/
COPY --from=builder /usr/lib/postgresql/${PG_VERSION}/lib/bitcode/lenticular_lens/ /usr/lib/postgresql/${PG_VERSION}/lib/bitcode/lenticular_lens/
COPY --from=builder /usr/lib/postgresql/${PG_VERSION}/lib/bitcode/lenticular_lens* /usr/lib/postgresql/${PG_VERSION}/lib/bitcode/
COPY --from=builder /usr/share/postgresql/${PG_VERSION}/extension/lenticular_lens* /usr/share/postgresql/${PG_VERSION}/extension/

RUN apt update && \
    apt install -y python3-venv postgresql-plpython3-${PG_VERSION} && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /app/venv
ENV PATH "/app/venv/bin:$PATH"

RUN pip3 install /app/lenticular_lens-1.0-py3-none-any.whl && \
    /app/post-install.sh

RUN rm /app/lenticular_lens-1.0-py3-none-any.whl && \
    rm /app/post-install.sh
