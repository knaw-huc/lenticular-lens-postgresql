FROM postgres:15 AS builder

RUN apt-get update && \
    apt-get install -y wget unzip build-essential python3-venv postgresql-server-dev-15 postgresql-plpython3-15

RUN python3 -m venv /opt/venv
ENV PATH "/opt/venv/bin:$PATH"

RUN pip3 install build pyyaml toml

COPY ./ /opt

WORKDIR /opt
RUN python3 package.py

WORKDIR /opt/build
RUN ./build.sh && ./post-install.sh

FROM postgres:15

COPY --from=builder /opt/build/python/dist/lenticular_lens-1.0-py3-none-any.whl /app/
COPY --from=builder /opt/build/post-install.sh /app/
COPY --from=builder /usr/lib/postgresql/15/lib/lenticular_lens.so /usr/lib/postgresql/15/lib/
COPY --from=builder /usr/lib/postgresql/15/lib/bitcode/lenticular_lens/ /usr/lib/postgresql/15/lib/bitcode/lenticular_lens/
COPY --from=builder /usr/lib/postgresql/15/lib/bitcode/lenticular_lens* /usr/lib/postgresql/15/lib/bitcode/
COPY --from=builder /usr/share/postgresql/15/extension/lenticular_lens* /usr/share/postgresql/15/extension/

RUN apt-get update && \
    apt-get install -y python3-venv postgresql-plpython3-15

RUN python3 -m venv /app/venv
ENV PATH "/app/venv/bin:$PATH"

RUN pip3 install /app/lenticular_lens-1.0-py3-none-any.whl && \
    /app/post-install.sh

RUN rm /app/lenticular_lens-1.0-py3-none-any.whl && \
    rm /app/post-install.sh

RUN echo listen_addresses='0.0.0.0' >> /usr/lib/tmpfiles.d/postgresql.conf
