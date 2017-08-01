from distutils.core import setup, Extension
from Cython.Build import cythonize

# vasp extension
vasp = Extension("DFTXMLParser.vasp",
                include_dirs=['include'],
                sources=["src/vasp.pyx", 
                         "src/fast_atoi.c", 
                         "src/fast_atof.c"])

setup(
    name='DFTXMLParser',
    version='0.1',
    author='Andrey Sobolev',
    ext_modules=cythonize([vasp]),
    packages=['DFTXMLParser'],
)
