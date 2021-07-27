FROM postgres:13 AS builder

RUN apt-get update && \
    apt-get install -y wget unzip python3-pip postgresql-server-dev-13 postgresql-plpython3-13

COPY ./ /opt

WORKDIR /opt/python
RUN pip3 install setuptools wheel && \
    python3 setup.py sdist bdist_wheel

WORKDIR /opt
RUN make && make install

FROM postgres:13

COPY --from=builder /opt/python/dist/* /app/
COPY --from=builder /usr/lib/postgresql/13/lib/lenticular_lens.so /usr/lib/postgresql/13/lib/
COPY --from=builder /usr/lib/postgresql/13/lib/bitcode/lenticular_lens* /usr/lib/postgresql/13/lib/bitcode/
COPY --from=builder /usr/share/postgresql/13/extension/lenticular_lens* /usr/share/postgresql/13/extension/

RUN apt-get update && \
    apt-get install -y python3-pip postgresql-plpython3-13

RUN pip3 install /app/lenticular_lens-1.0-py3-none-any.whl

RUN su postgres -c "python3 -m nltk.downloader stopwords" && \
    su postgres -c "python3 -m nltk.downloader punkt"

RUN echo listen_addresses='0.0.0.0' >> /usr/lib/tmpfiles.d/postgresql.conf
