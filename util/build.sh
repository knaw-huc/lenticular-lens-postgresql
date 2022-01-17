# Build Python distribution
python3 ./python/setup.py bdist_wheel

# Install Python distribution
pip3 install ./dist/lenticular_lens-1.0-py3-none-any.whl

# Compile C code
make

# Install PostgreSQL extension
make install
