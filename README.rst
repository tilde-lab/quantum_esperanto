=================
Quantum Esperanto
=================

*Quantum Esperanto* is a fast parser of XML files output by DFT codes (*vasp* as of now) written in Cython.
It takes advantage of lxml, a Python wrapper around libxml2 library, and its Cython interface.
XML files are parsed to a Python dictionary in a transparent way. It is really fast, up to 10 times faster than the
parser used by pymatgen_ project.

Installation
------------

As Quantum Esperanto is not yet on PyPI, it can be installed from GitHub_:

::

  $ git clone https://github.com/tilde-lab/quantum_esperanto
  $ cd quantum_esperanto
  $ pip install .

The Python prerequisites for the package are ``numpy`` and ``lxml`` (should be installed automatically with ``pip``).
Also, C compiler such as ``gcc`` must be present in the system.

It is possible to install the package in development mode. This will install ``Cython`` as well as ``nose`` test suite.
To do it issue the following command after cloning the repository and changing the directory:

::

  $ cd quantum_esperanto
  $ pip install -e .[dev]

After install it is possible to run several tests to check if the installation was completed successfully. It can be
done with the following commands in ``quantum_esperanto`` directory:

::

  $ python setup.py test

If everything is OK, you're all set to start using the package.

Usage
-----

The parser can be used in a very simple way. First, the parser has to be instantiated, and then the ``parse_file``
method of the parser returns the dictionary of parsed values:

.. code:: python

  from quantum_esperanto.vasp import VaspParser
  parser = VaspParser()
  d = parser.parse_file('vasprun.xml')

The possible arguments for the parser are:

**recover**
  (boolean, default: *True*) a flag that allows recovering broken XML. It is very useful in case of unfinished
  calculations; however, it exits on the first XML error and the returned dictionary contains parsed values up to the
  first XML error only. When XML recovery is needed, a warning is printed to stderr.

**whitelist**
  (list, default: *None*) the list of parent tag names that are only needed to parsed. If None, then all tags are parsed.

Parsing result
--------------

The result of parsing is a dictionary that follows the structure of ``vasprun.xml``. The keys of the dictionary are
either tag names (for ``i``, ``v``, ``varray`` tags), or ``tag:tag name`` construction (for tags that do have name
attribute), or just tags themselves. The values are either tag contents converted to the right type (specified by ``type``
tag attribute) or (in case of varrays and sets) Numpy arrays. Fortran overflows (denoted by `*****`) are converted to
NaNs in case of float values and to MAXINT in case of integer values.

**Example**:

*xml file*

.. code:: xml

 <structure name="primitive_cell" >
  <crystal>
   <varray name="basis" >
    <v>       1.43300000       1.43300000       1.43300000 </v>
    <v>       1.43300000      -1.43300000      -1.43300000 </v>
    <v>      -1.43300000       1.43300000      -1.43300000 </v>
   </varray>
   <i name="volume">     11.77059895 </i>
   <varray name="rec_basis" >
    <v>       0.34891835       0.34891835       0.00000000 </v>
    <v>       0.34891835      -0.00000000      -0.34891835 </v>
    <v>      -0.00000000       0.34891835      -0.34891835 </v>
   </varray>
  </crystal>
  <varray name="positions" >
   <v>       0.00000000       0.00000000       0.00000000 </v>
  </varray>
 </structure>

*resulting dictionary* (printed with *pprint*):

.. code:: python

  {'structure:primitive_cell': {'crystal': {'basis': array([[ 1.433,  1.433,  1.433],
                                                            [ 1.433, -1.433, -1.433],
                                                            [-1.433,  1.433, -1.433]]),
                                            'rec_basis': array([[ 0.34891835,  0.34891835,  0.        ],
                                                                [ 0.34891835, -0.        , -0.34891835],
                                                                [-0.        ,  0.34891835, -0.34891835]]),
                                            'volume': 11.77059895},
                                'positions': array([[ 0.,  0.,  0.]])}}

License
-------

Quantum Esperanto is licensed under MIT license.

.. _GitHub: http://www.github.com/tilde-lab/quantum_esperanto
.. _pymatgen: https://pymatgen.org
