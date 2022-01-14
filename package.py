import os
from inspect import cleandoc

import yaml
import shutil

util_dir = os.path.dirname(__file__) + '/util'
build_dir = os.path.dirname(__file__) + '/build'
plugins_dir = os.path.dirname(__file__) + '/plugins'

shutil.rmtree(build_dir)
os.mkdir(build_dir)

plugins = os.listdir(plugins_dir)

plugins_config = {}
for name in plugins:
    yaml_path = plugins_dir + '/' + name + '/plugin.yaml'
    if os.path.isfile(yaml_path):
        with open(yaml_path, 'r') as yaml_f:
            config = yaml.load(yaml_f, Loader=yaml.FullLoader)
            plugins_config[name] = config
    else:
        plugins.remove(name)

# Create the PostgreSQL extension script/SQL file
# See also: https://www.postgresql.org/docs/current/extend-extensions.html
with open(build_dir + '/lenticular_lens--1.0.sql', 'w') as f:
    f.write(cleandoc('''
    -- Complain if script is sourced in psql, rather than via CREATE EXTENSION
    \echo Use "CREATE EXTENSION lenticular_lens" to load this file. \quit
    '''))
    f.write('\n\n')

    with open(util_dir + '/util.sql', 'r') as util_f:
        f.write(util_f.read())
        f.write('\n')

    for name in plugins:
        sql_path = plugins_dir + '/' + name + '/plugin.sql'
        if os.path.isfile(sql_path):
            with open(sql_path, 'r') as sql_f:
                f.write(sql_f.read())
                f.write('\n')

# Create the PostgreSQL extension control file
# See also: https://www.postgresql.org/docs/current/extend-extensions.html
with open(build_dir + '/lenticular_lens.control', 'w') as f:
    requires = {requires
                for config in plugins_config.values()
                for requires in config.get('requires', {}).get('postgresql', [])}

    f.write(cleandoc(f'''
    # lenticular_lens extension
    comment = 'similarity functions for lenticular lens'
    default_version = '1.0'
    module_pathname = '$libdir/lenticular_lens'
    requires = '{", ".join(requires)}'
    relocatable = true
    trusted = true
    '''))

# Prepare Python code
python_dir = build_dir + '/python'
os.mkdir(python_dir)

python_package_dir = python_dir + '/lenticular_lens'
os.mkdir(python_package_dir)

open(python_package_dir + '/__init__.py', 'a').close()

for name in plugins:
    python_path = plugins_dir + '/' + name + '/plugin.py'
    if os.path.isfile(python_path):
        shutil.copyfile(python_path, python_package_dir + '/' + name + '.py')

# Create setup.py for packaging Python code
with open(python_dir + '/setup.py', 'w') as f:
    requires = {requires
                for config in plugins_config.values()
                for requires in config.get('requires', {}).get('python', [])}

    f.write(cleandoc(f'''
    import setuptools
    
    setuptools.setup(
        name='lenticular_lens',
        version='1.0',
        packages=setuptools.find_packages(),
        install_requires=[{", ".join(["'" + req + "'" for req in requires])}]
    )
    '''))

# Prepare C code
c_dir = build_dir + '/c'
os.mkdir(c_dir)

shutil.copyfile(util_dir + '/util.c', c_dir + '/util.c')
shutil.copyfile(util_dir + '/util.h', c_dir + '/util.h')

for name in plugins:
    c_path = plugins_dir + '/' + name + '/plugin.c'
    if os.path.isfile(c_path):
        shutil.copyfile(c_path, c_dir + '/' + name + '.c')

# Create Makefile for compiling C code and packaging PostgreSQL extension
with open(build_dir + '/Makefile', 'w') as f:
    f.write(cleandoc('''
    # lenticular_lens extension
    
    EXTENSION = lenticular_lens
    MODULE_big = lenticular_lens
    PGFILEDESC = "lenticular_lens - similarity functions for lenticular lens"
    SRCS=$(wildcard *.c)
    OBJS=$(SRCS:.c=.o)
    PG_CONFIG = pg_config
    
    DATA = lenticular_lens--1.0.sql
    EXTRA_CLEAN = lenticular_lens--1.0.sql
    
    PGXS := $(shell $(PG_CONFIG) --pgxs)
    include $(PGXS)
    '''))

# Create build script
with open(build_dir + '/build.sh', 'w') as f:
    br = '\n'
    cmds = [config['cmd']
            for config in plugins_config.values()
            if 'cmd' in config]

    f.write(cleandoc(f'''
    # Build Python distribution
    python3 ./python/setup.py bdist_wheel
    
    # Install Python distribution
    pip3 install ./dist/lenticular_lens-1.0-py3-none-any.whl
    
    # Compile C code
    make
    
    # Install PostgreSQL extension
    make install
    
    # Additional commands
    {br.join(cmds)}
    '''))

# Create LL config files
ll_config_dir = build_dir + '/ll_config'
os.mkdir(ll_config_dir)

with open(ll_config_dir + '/filter_functions.yaml', 'w') as f:
    yaml.dump({method_name: method_config
               for config in plugins_config.values()
               for (method_name, method_config) in config['methods'].items()
               if config['type'] == 'filter_function'}, f)

with open(ll_config_dir + '/matching_methods.yaml', 'w') as f:
    yaml.dump({method_name: method_config
               for config in plugins_config.values()
               for (method_name, method_config) in config['methods'].items()
               if config['type'] == 'matching_method'}, f)

with open(ll_config_dir + '/transformers.yaml', 'w') as f:
    yaml.dump({method_name: method_config
               for config in plugins_config.values()
               for (method_name, method_config) in config['methods'].items()
               if config['type'] == 'transformer'}, f)
