# Copyright 2017 Andrey Sobolev, Tilde Materials Informatics (Berlin)

# This file is a part of DFTXMLParser project. The project is licensed under the MIT license.
# See the LICENSE file in the project root for license terms.

"""
A test suite for VASP parser. Tests take every xml file in tests/xml and check if parsing
results coincide with reference
"""
import os
import tarfile
import numpy as np
from numpy.testing import assert_allclose
from nose.tools import ok_, eq_
from reference.vasp_parser_py import parse_file as parse_file_ref
from DFTXMLParser.vasp import VaspParser

# float tolerance
tol = 1e-7


def test_parser():
    tar = tarfile.open(os.path.join(os.path.dirname(__file__), "xml.tar.gz"), "r:gz")
    for member in tar.getmembers():
        tar.extract(member)
        f = member.name
        yield check_parsing_results, f
        os.remove(f)


def check_parsing_results(f_name):
    # get our result and reference
    ref_result = parse_file_ref(f_name)
    result = VaspParser().parse_file(f_name)
    # recursive function where all comparison takes place
    compare_dicts(result, ref_result)


def compare_dicts(res, ref, k=''):
    for key in ref.keys():
        # check if key exists in res
        ok_(key in res, '{} not in result!'.format(key))
        if isinstance(res[key], dict):
            compare_dicts(res[key], ref[key], k+' -> '+key)
        elif isinstance(res[key], np.ndarray):
            assert_allclose(res[key], np.array(ref[key]), rtol=tol)
        elif isinstance(res[key], list):
            compare_lists(res[key], ref[key], k+' -> '+key)
        elif isinstance(res[key], float):
            assert_allclose(res[key], ref[key], rtol=tol)
        else:
            eq_(res[key], ref[key], '{}: {} != {}'.format(k +' -> '+ key, res[key], ref[key]))


def compare_lists(res, ref, k=''):
    eq_(len(res), len(ref), '{}: Lengths do not coincide!'.format(k))
    for i, (res_i, ref_i) in enumerate(zip(res, ref)):
        if isinstance(res_i, dict):
            compare_dicts(res_i, ref_i, k+' -> '+str(i))
        elif isinstance(res_i, list):
            compare_lists(res_i, ref_i, k+' -> '+str(i))
        elif isinstance(res_i, np.ndarray):
            assert_allclose(res_i, np.array(ref_i), rtol=tol)
        elif isinstance(res_i, float):
            assert_allclose(res_i, ref_i, rtol=tol)
        else:
            eq_(res_i, ref_i, '{}: {} != {}'.format(k +' -> '+ str(i), res_i, ref_i))
