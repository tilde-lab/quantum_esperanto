# Copyright 2017 Andrey Sobolev, Tilde Materials Informatics (Berlin)

# This file is a part of DFTXMLParser project. The project is licensed under the MIT license.
# See the LICENSE file in the project root for license terms.

from setuptools import setup, Extension
from DFTXMLParser import __version__

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

with open("README.rst", "r") as f:
    long_description = f.read()

setup(
    name='DFTXMLParser',
    version=__version__,
    author='Andrey Sobolev',
    author_email="andrey.n.sobolev@gmail.com",
    url="https://github.com/tilde-lab/DFTXMLParser",
    license='MIT',
    description="A fast parser of XML files output by VASP DFT code written in Cython.",
    long_description=long_description,
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Science/Research',
        'Topic :: Scientific/Engineering :: Chemistry',
        'Topic :: Scientific/Engineering :: Physics',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.3',
        'Programming Language :: Python :: 3.4',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6'
    ],
    ext_modules=exts,
    packages=['DFTXMLParser'],
    install_requires=['numpy>=1.10', 'lxml'],
    extras_require={'dev': ['Cython', 'nose']},
    tests_require=['nose'],
    test_suite='nose.collector'
)
