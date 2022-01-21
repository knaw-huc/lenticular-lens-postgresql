import os
from inspect import cleandoc

import yaml
import json
import shutil

util_dir = os.path.dirname(__file__) + '/util'
build_dir = os.path.dirname(__file__) + '/build'
plugins_dir = os.path.dirname(__file__) + '/plugins'

shutil.rmtree(build_dir, ignore_errors=True)
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
    with open(util_dir + '/main.sql', 'r') as main_f:
        f.write(main_f.read())
        f.write('\n')

    for config in plugins_config.values():
        for (method_name, method_config) in config['methods'].items():
            if config['type'] == 'filter_function' or \
                    config['type'] == 'matching_method' or \
                    config['type'] == 'transformer':
                config_json = json.dumps(method_config).replace("'", "''")
                f.write(f"INSERT INTO {config['type']}s "
                        f"VALUES ('{method_name}', '{config_json}');\n")
    f.write('\n')

    with open(util_dir + '/util.sql', 'r') as util_f:
        f.write(util_f.read())
        f.write('\n')

    for name in plugins:
        sql_path = plugins_dir + '/' + name + '/plugin.sql'
        if os.path.isfile(sql_path):
            with open(sql_path, 'r') as sql_f:
                f.write(sql_f.read())
                f.write('\n')

    f.write("NOTIFY extension_update, 'Update of the Lenticular Lens extensions';\n")

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
shutil.copyfile(util_dir + '/Makefile', build_dir + '/Makefile')

for name in plugins:
    c_path = plugins_dir + '/' + name + '/plugin.c'
    if os.path.isfile(c_path):
        shutil.copyfile(c_path, c_dir + '/' + name + '.c')

# Prepare build and post-install script
shutil.copyfile(util_dir + '/build.sh', build_dir + '/build.sh')

with open(build_dir + '/post-install.sh', 'w') as f:
    cmds = [config['cmd']
            for config in plugins_config.values()
            if 'cmd' in config]

    f.write('\n'.join(cmds))

os.chmod(build_dir + '/build.sh', 0o775)
os.chmod(build_dir + '/post-install.sh', 0o775)
