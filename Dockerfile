FROM postgres:14 AS builder

RUN apt-get update && \
    apt-get install -y wget unzip python3-pip postgresql-server-dev-14 postgresql-plpython3-14

RUN pip3 install setuptools wheel pyyaml

COPY ./ /opt

WORKDIR /opt
RUN python3 package.py

WORKDIR /opt/build
RUN ./build.sh && ./post-install.sh

FROM postgres:14

COPY --from=builder /opt/build/dist/* /app/
COPY --from=builder /opt/build/post-install.sh /app/
COPY --from=builder /usr/lib/postgresql/14/lib/lenticular_lens.so /usr/lib/postgresql/14/lib/
COPY --from=builder /usr/lib/postgresql/14/lib/bitcode/lenticular_lens/ /usr/lib/postgresql/14/lib/bitcode/lenticular_lens/
COPY --from=builder /usr/lib/postgresql/14/lib/bitcode/lenticular_lens* /usr/lib/postgresql/14/lib/bitcode/
COPY --from=builder /usr/share/postgresql/14/extension/lenticular_lens* /usr/share/postgresql/14/extension/

RUN apt-get update && \
    apt-get install -y python3-pip postgresql-plpython3-14

RUN pip3 install /app/lenticular_lens-1.0-py3-none-any.whl
RUN /app/post-install.sh

RUN echo listen_addresses='0.0.0.0' >> /usr/lib/tmpfiles.d/postgresql.conf
