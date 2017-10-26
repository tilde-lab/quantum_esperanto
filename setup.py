# Copyright 2017 Andrey Sobolev, Tilde Materials Informatics (Berlin)

# This file is a part of DFTXMLParser project. The project is licensed under the MIT license.
# See the LICENSE file in the project root for license terms.

from setuptools import setup, Extension

# check if we have Cython available
try:
    from Cython.Build import cythonize
    use_cython = True
except ImportError:
    use_cython = False

# vasp extension
sources = [
    "src/fast_atoi.c",
    "src/fast_atof.c"]
if use_cython:
    sources.append("src/vasp.pyx")
else:
    sources.append("src/vasp.c")

vasp_ext = Extension("DFTXMLParser.vasp",
                include_dirs=['include'],
                sources=sources)

if use_cython:
    exts = cythonize([vasp_ext])
else:
    exts = [vasp_ext]

setup(
    name='DFTXMLParser',
    version='0.1',
    author='Andrey Sobolev',
    license='MIT',
    description="A fast parser of XML files output by VASP DFT code written in Cython.",
    ext_modules=exts,
    packages=['DFTXMLParser'],
    install_requires=['numpy>=1.10', 'lxml'],
    extras_require={'dev': ['Cython', 'nose']},
    tests_require=['nose'],
    test_suite='nose.collector'
)
