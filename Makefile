# lenticular_lens extension

EXTENSION = lenticular_lens
MODULE_big = lenticular_lens
PGFILEDESC = "lenticular_lens - similarity functions for lenticular lens"
OBJS = c/main.o c/util.o c/levenshtein.o c/jaro.o
PG_CONFIG = pg_config

all: lenticular_lens--1.0.sql
lenticular_lens--1.0.sql: header.sql sql/*.sql
	cat $^ > $@

DATA = lenticular_lens--1.0.sql
EXTRA_CLEAN = lenticular_lens--1.0.sql

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
