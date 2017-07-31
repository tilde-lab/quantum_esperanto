from distutils.core import setup, Extension
from Cython.Build import cythonize


ext = Extension("parse_cetree",
                sources=["parse_cetree.pyx", "fast_atoi.c", "fast_atof.c"])
setup(ext_modules = cythonize([ext]))
