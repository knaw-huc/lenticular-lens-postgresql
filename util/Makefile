# lenticular_lens extension

EXTENSION = lenticular_lens
MODULE_big = lenticular_lens
PGFILEDESC = "lenticular_lens - similarity functions for lenticular lens"
SRCS = $(wildcard c/*.c)
OBJS = $(SRCS:%.c=%.o)
PG_CONFIG = pg_config

DATA = lenticular_lens--1.0.sql
EXTRA_CLEAN = lenticular_lens--1.0.sql

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
