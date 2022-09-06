# Build Python distribution
python3 -m build python

# Install Python distribution
pip3 install ./python/dist/lenticular_lens-1.0-py3-none-any.whl

# Compile C code
make

# Install PostgreSQL extension
make install
