# lenticular_lenses extension

EXTENSION = lenticular_lenses
MODULE_big = lenticular_lenses
PGFILEDESC = "lenticular_lenses - similarity functions for lenticular lenses"
OBJS = c/main.o c/util.o c/levenshtein.o c/jaro.o
PG_CONFIG = pg_config

all: lenticular_lenses--1.0.sql
lenticular_lenses--1.0.sql: header.sql sql/*.sql
	cat $^ > $@

DATA = lenticular_lenses--1.0.sql
EXTRA_CLEAN = lenticular_lenses--1.0.sql

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
