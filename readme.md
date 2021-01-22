# Lenticular Lenses PostgreSQL extension

This PostgreSQL extension contains various similarity functions 
(written in C, Python, PL/SQL and SQL) 
that are being used in Lenticular Lenses.

## Prerequisites

- A C compiler and Make support
- [Python 3](https://www.python.org) with [pip](https://pypi.org/project/pip)
- [PostgreSQL](https://www.postgresql.org) with the [PL/Python extension](https://www.postgresql.org/docs/current/plpython.html)
  ```sql 
  CREATE EXTENSION plpythonu3;
  ```

## Install the Python package

The Python code comes as a pip package that has to be installed with pip:
``` 
pip3 install ./python/dist/lenticular_lenses-1.0-py3-none-any.whl 
```

Now the Python functions can be reached by importing the `lenticular_lenses` package:
```python
import lenticular_lenses
```

You will also need to download some NLTK packages:
``` 
python3 -m nltk.downloader stopwords
python3 -m nltk.downloader punkt
```

If you want to update the Python code and rebuild the package, 
you'll need `setuptools` and `wheel` installed and run the `setup.py` script
from the `python` directory:
``` 
pip3 install install setuptools wheel
python3 setup.py sdist bdist_wheel
```

## Compile the C code

The C code can be compiled by running the following command:
``` 
make
```

## Install the PostgreSQL extension

To install the PostgreSQL extension run the install command:
``` 
make install
```

Then in PostgreSQL, run the following command in the database where 
the extension should be available:
```sql 
CREATE EXTENSION lenticular_lenses;
```

If you want to remove the extension from a particular database, just run:
```sql 
DROP EXTENSION lenticular_lenses;
```
