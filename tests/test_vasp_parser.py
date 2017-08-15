
"""
A test suite for VASP parser. Tests take every xml file in tests/xml and check if parsing
results coincide with reference
"""
import os
import tarfile
import numpy as np
from numpy.testing import assert_array_almost_equal
from nose.tools import ok_, eq_
from reference.vasp_parser_py import parse_file as parse_file_ref
from DFTXMLParser.vasp import parse_file


def test_parser():
    tar = tarfile.open("xml.tar.gz", "r:gz")
    for member in tar.getmembers():
        tar.extract(member)
        f = member.name
        yield check_parsing_results, f
        os.remove(f)


def check_parsing_results(f_name):
    # get our result and reference
    ref_result = parse_file_ref(f_name)
    result = parse_file(f_name)
    # recursive function where all comparison takes place
    compare_dicts(result, ref_result)


def compare_dicts(res, ref):
    for key in ref.keys():
        # check if key exists in res
        ok_(key in res, '{} not in result!'.format(key))
        if isinstance(res[key], dict):
            compare_dicts(res[key], ref[key])
        elif isinstance(res[key], np.ndarray):
            assert_array_almost_equal(res[key], np.array(ref[key]))
        else:
            eq_(res[key], ref[key], '{}: {} != {}'.format(key, res[key], ref[key]))
