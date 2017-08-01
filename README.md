DFTXMLParser
============

DFTXMLParser is a fast parser of XML files output by DFT codes (vasp as of now) written in Cython.
It takes advantage of xml.etree.cElementTree, a C implementation of ElementTree present in
Python standard library. XML files are parsed in a Python dictionary in a transparent way.