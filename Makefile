# lenticular_lenses extension

EXTENSION = lenticular_lenses
MODULE_big = lenticular_lenses
PGFILEDESC = "lenticular_lenses - similarity functions for lenticular lenses"
OBJS = c/main.o c/util.o c/levenshtein.o c/jaro.o
DATA = lenticular_lenses--1.0.sql

PG_CONFIG = pg_config
PGXS = $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
