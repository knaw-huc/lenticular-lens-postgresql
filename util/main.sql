-- Complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION lenticular_lens" to load this file. \quit

CREATE TABLE filter_functions
(
    key    text  not null primary key,
    config jsonb not null
);

CREATE TABLE matching_methods
(
    key    text  not null primary key,
    config jsonb not null
);

CREATE TABLE transformers
(
    key    text  not null primary key,
    config jsonb not null
);
