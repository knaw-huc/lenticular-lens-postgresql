# Lenticular Lens PostgreSQL extension

This PostgreSQL extension contains various similarity functions
(written in C, Python, PL/SQL and SQL)
that are being used in Lenticular Lens.

1. [Prerequisites](#prerequisites)
2. [Plugin structure](#plugin-structure)
   1. [Plugin configuration](#plugin-configuration)
      1. [Filter function plugin configuration](#filter-function-plugin-configuration)
      2. [Matching method plugin configuration](#matching-method-plugin-configuration)
      3. [Transformer plugin configuration](#transformer-plugin-configuration)
      4. [Configuration items plugin configuration](#configuration-items-plugin-configuration)
   2. [Python code](#python-code)
   3. [C code](#c-code)
3. [Packaging, building and installing](#packaging-building-and-installing)

## Prerequisites

- A C compiler and Make support
- [Python 3](https://www.python.org) with [pip](https://pypi.org/project/pip)
- [PostgreSQL](https://www.postgresql.org) with
  the [PL/Python extension](https://www.postgresql.org/docs/current/plpython.html)
  ```sql 
  CREATE EXTENSION plpythonu3;
  ```

## Plugin structure

The folder `plugins` contains all the plugins. To add a new plugin:

1. Add a new folder with the name of the new plugin
2. Add a file named `plugin.yaml`, this YAML file contains the configuration of the plugin
3. Add a SQL file named `plugin.sql`, this contains the SQL or PL/SQL function definition
4. Optionally add the Python code `plugin.py` or the C code `plugin.c`

### Plugin configuration

The plugin configuration file `plugin.yaml` should look as follows:

```yaml
# The type of plugin: 'filter_function', 'matching_method' or 'transformer'
type: filter_function

# Optionally, if there are dependencies, they are listed here
requires:
  # A list of PostgreSQL dependencies (this example requires the 'plpython3u' extension)
  postgresql:
    - plpython3u
  # A list of Python dependencies (this example requires the 'unicode' extension)
  python:
    - unicode

# Optionally, if there is a command to run post-install, the shell command is given here:
cmd: su postgres -c "python3 print('Hello!')"

# The various methods this plugin provides are defined here
methods:
  filter_function_1:
  # ...

  filter_function_2:
  # ...
```

#### Filter function plugin configuration

A filter function is a method that obtains the property value and optionally a value that it should match. The method
should return a boolean result.

There are two properties that can be used in the SQL template:

* `property`: The value of the property that is matched
* `value`: The value to compare against the property (optional)

The YAML configuration looks as follows:

```yaml
# Ordering among the other filter functions
order: 10

# A human readable label
label: My filter function

# The SQL template to call the filter function from a SQL query
sql_template: "my_filter_function({property}, {value})"

# If a value to compare against is required, the data type of the value (string, numeric, date)
type: string

# Optionally, a help text for the user
help_text: Please specify a meanigful value for my filter function
```

#### Matching method plugin configuration

A matching method is a method that can come as three different types:

* `filter`: A method that expects a source value and a target value and returns a boolean value
* `similarity`: A method that expects a source value and a target value and returns the similarity between 0 and 1,
  where 1 equals an exact match and 0 no match at all
* `normalizer`: A method that expects a single value and normalizes it to a new value (often used in combination with
  another similarity method)

Both the `filter` adn the `normalizer` expect a single SQL template. The `similarity` type however expects two SQL
templates. The `similarity` template which contains the SQL template that returns the similarity score. And
the `condition` template which returns a boolean value whether there is a match found. The `similarity` type may have
two more SQL templates to help with indexing: `before_index` and `index`. There are a couple of properties that can be
used in the SQL templates:

* `property`: The value of the property that is matched (Only available for the `normalizer` type)
* `source`: The value of the source property that is matched (Not available for the `normalizer` type)
* `target`: The value of the target property that is matched (Not available for the `normalizer` type)
* `similarity`: The result of the `similarity` template of the `similarity` type (Only available for the `condition`
  template of the `similarity` type)

The YAML configuration looks as follows:

```yaml
# An ordering among the other matching methods; a human-readable label, description and reference URLs
order: 10
label: My matching method
description: My awesome matching method.
see_also:
  - https://lenticularlens.org/matching-method/my-matching-method

# The type of matching method 
type: filter

# If the value is not a string, the data type of the value ('numeric', 'date')
# In case of 'date', a configuration option 'format' is expected
field_type: date

# The threshold range, usually either 'ℕ' or ']0, 1]' or '{0, 1}'
threshold_range: ℕ

# The SQL template to call the matching method from a SQL query (only for the filter and normalizer types)
sql_template: "my_matching_method({property})"

# The SQL templates to call the matching method from a SQL query (only for the similarity type)
sql_templates:
  similarity: "similarity({source}, {target})"
  condition: "{similarity} >= {threshold}"
  before_index: "SELECT set_config('my_matching_method.threshold', {threshold});"
  index: "index ({target})"

# A matching method may come with a number of configuration options, these are all defined under 'items'
items:
  # The key of the matching method (the key is then available for use in the SQL templates)
  threshold:
  # ...

  size:
  # ...
```

#### Transformer plugin configuration

A transformer is a method that obtains the property value and transforms it. It comes with a single property that can be
used in the SQL template:

* `property`: The value of the property that is matched

The YAML configuration looks as follows:

```yaml
# An ordering among the other transformers
order: 10

# A human readable label
label: My transformer

# The SQL template to call the filter function from a SQL query
sql_template: "my_transformer({property}, {my_config})"

# A transformer may come with a number of configuration options, these are all defined under 'items'
items:
  # The key of the transformer (the key is then available for use in the SQL templates)
  my_config_1:
  # ...

  my_config_2:
  # ...
```

#### Configuration items plugin configuration

Both matching methods and transformers allow for configuration options. The YAML configuration for a configuration
option looks as follows:

```yaml
# A human-readable label
label: Similarity threshold

# The data type of the configuration option 
# 'string', 'boolean', 'number', 'range', 'tags', 'choices', 'entity_type_selection', 'property'
type: range

# An optional hint if you need a larger ('large') or smaller ('small') input box than the default size
size: large

# The default value
default_value: 0.7

# By how much will the value increase or decrease? (only for 'number' and 'range')
step: 0.05

# The (inclusive and exclusive) minimum and maximum values (only for 'number' and 'range')
min_excl_value: 0
max_excl_value: 1
min_incl_value: 0
max_incl_value: 1

# The choices available, the key is the value, the value is the human-readable label (only for 'choices')
choices:
  choice_1: Awesome choice
  choice_2: Another awesome choice

# The key of the configuration option of type 'entity_type_selection' (only for 'property')
entity_type_selection_key: entity_type_selection

# RDF information, how is this expressed in the RDF export?
rdf:
  # The predicate to use and namespace data
  predicate: https://lenticularlens.org/voidPlus/similarityThreshold
  prefix: voidPlus
  uri: https://lenticularlens.org/voidPlus/

  # If the value has to be converted to a URI (or multiple URIs), specify the predicate to use and namespace data per value
  values:
    choice_1:
      - predicate: https://lenticularlens.org/choice#1
        prefix: choice
        uri: https://lenticularlens.org/choice#

    choice_2:
      - predicate: https://lenticularlens.org/choice#2
        prefix: choice
        uri: https://lenticularlens.org/choice#
```

### Python code

_Also see the [PL/Python documentation](https://www.postgresql.org/docs/10/plpython.html) in the PostgreSQL
documentation._

Add the Python code to a file named `plugin.py`. From the SQL definition, this Python file can be referenced by
importing the package `lenticular_lens.<plugin_name>`.

Let's say you have a plugin named `python_test` which contains a Python plugin file `plugin.py` with a single
function `hello` in there:

```python
def hello():
    return "Hello all!"
```

Then you can create a SQL function in `plugin.sql` that uses this Python function as follows:

```sql
CREATE FUNCTION hello() RETURNS text AS $$
from lenticular_lens.python_test import hello
return hello()
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;
```

Although an alternative could have been to get rid of the `plugin.py` and have the Python code directly in `plugin.sql`:

```sql
CREATE FUNCTION hello() RETURNS text AS $$
return "Hello all!"
$$ LANGUAGE plpython3u IMMUTABLE STRICT PARALLEL SAFE;
```

### C code

_Also see the [C-Language Functions documentation](https://www.postgresql.org/docs/10/xfunc-c.html) in the PostgreSQL
documentation._

Add the C code to a file named `plugin.c`. The magic block `PG_MODULE_MAGIC` does **NOT** have to be defined, as this is
done already. You just have to use the calling convention by writing a `PG_FUNCTION_INFO_V1` macro call for the function
as explained in the PostgreSQL documentation and writing the SQL definition in the `plugin.sql` file.

There are a couple of utility functions in the `util/util.c` file for comparing multibyte characters and working with
multibyte strings using optimized PostgreSQL functions.

## Packaging, building and installing

There is a Python script `package.py` which goes over all the plugins to combine them in the `build` folder and prepare
for building:

* All C code is combined in a folder `c`
* All Python code is combined in a folder `python` together with a `setup.py` file to create a Python package
* All SQL code is combined in a single SQL file together with all plugin configuration which will end up in the database
  as well
* A PostgreSQL extension control file is created

Then everything is ready to be build and installed:

```shell
# Build Python distribution
python3 -m build python

# Install Python distribution
pip3 install ./dist/lenticular_lens-1.0-py3-none-any.whl

# Compile C code
make

# Install PostgreSQL extension
make install
```

These commands can also be found in the `build/build.sh` file.

Then from PostgreSQL the extension can be installed using:

```sql 
CREATE EXTENSION lenticular_lens CASCADE;
```

If you want to remove the extension, just run:

```sql 
DROP EXTENSION lenticular_lens;
```
