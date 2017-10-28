# cython: c_string_type=str, c_string_encoding=ascii, profile=True

# Copyright 2017 Andrey Sobolev, Tilde Materials Informatics (Berlin)

# This file is a part of DFTXMLParser project. The project is licensed under the MIT license.
# See the LICENSE file in the project root for license terms.

from __future__ import print_function
import sys
import numpy as np
from collections import Counter
from lxml import etree as letree


__all__ = ['VaspParser', ]


cdef extern from "fast_atoi.h":
    int fast_atoi(char *s)


cdef extern from "fast_atof.h":
    double fast_atof(char *s)


cdef double to_float(s):
    """Fast string-to-float conversion"""
    cdef char* f = s
    return fast_atof(f) 


cdef int to_int(s):
    """Fast string-to-int conversion"""
    cdef char* i = s
    return fast_atoi(i)


cdef long prod(long[:] mv):
    """Fast product of array elements"""
    cdef int i, n
    cdef long res = 1
    n = mv.shape[0]
    for i in range(n):
        res *= mv[i]
    return res

to_type = {
    "string" : lambda x: x.strip() if x is not None else "",
    "int" : to_int,
    None: to_float,
    "": to_float,
    "logical": lambda x: x.strip() == "T"
}


def get_name(el):
    """
    Finds a name of a given XML element according to the rules

    :param el: An ElementTree.Element instance
    :return: A name of the Element
    """
    if el.tag in ["i", "v", "varray"]:
        return el.attrib.get("name", None)
    else:
        return el.tag + ("" if not "name" in el.attrib else ":" + el.attrib["name"])


def parse_i(el, name):
    """
    Parses the single value Element (i tag)

    :param el: An ElementTree.Element instance
    :param name: A name of the Element
    :return: A dictionary with parsing results
    """
    e_type = el.attrib.get("type", None)
    value = to_type[e_type](el.text)
    return {name: value}


def parse_v(el, name):
    """
    Parses the vector Element (v tag)

    :param el: An ElementTree.Element instance
    :param name: A name of the Element
    :return: A dictionary with parsing results
    """
    e_type = el.attrib.get("type", None)
    value = [to_type[e_type](v_i) for v_i in el.text.split()]
    return {name: value}


def parse_varray(el, name):
    """
    Parses the 2D array Element (varray tag)

    :param el: An ElementTree.Element instance
    :param name: A name of the Element
    :return: A dictionary with parsing results
    """

    e_type = el.attrib.get("type", None)
    if e_type is not None:
        return _parse_general_varray(el, name)
    else:
        # fast parsing of float varray
        dims = np.array([len(el), len(el[0].text.split())])
        # allocate memory
        value = np.zeros(dims, dtype=float).reshape(-1)
        cols = np.array(get_cols(el))
        parse_float_varray(el, value, dims, cols)
        return {name: value.reshape(dims)}


def _parse_general_varray(el, name):
    value = []
    for kid in el:
        parsed_kid = parse_v(kid, None)
        value.append(parsed_kid[None])
    return {name: value}


cdef void parse_float_varray(el, double[:] value, long[:] dims, long[:] cols):
    cdef:
        int i, j, pos = 0
    for i in range(dims[0]):
        text = el[i].text
        for j in range(dims[1]):
            value[pos] = fast_atof(text[cols[j]:cols[j+1]])
            pos += 1


def parse_array(el, name):
    """
    Parses the array Element with fields and sets of values (array tag)

    :param el: An ElementTree.Element instance
    :param name: A name of the Element
    :return: A dictionary containing dimensions, field names and sets od values in Numpy arrsya
    """

    # array has dimensions, field names and sets of values
    dims = []
    fields = []
    vals = []
    for kid in el:
        if kid.tag == "dimension":
            dims.append(kid.text)
        if kid.tag == "field":
            fields.append({"name": kid.text, "type": kid.attrib.get("type", None)})
        if kid.tag == "set":
            is_float_set = all([f["type"] is None for f in fields])
            if not is_float_set:
                types = [to_type[f["type"]] for f in fields]
                ifields = range(len(fields))
                vals = parse_general_set(kid, types, ifields)
            else:
                nfields = len(fields)
                # get set dimensions
                set_dims = get_set_dimension(kid)
                set_dims.append(nfields)
                # allocate memory: make one long 1-d array
                vals = np.zeros(set_dims, dtype=float).reshape(-1)
                cols = get_cols(kid)

                parse_float_set(kid, vals, np.array(set_dims, dtype=int), np.array(cols, dtype=int))
                # reshape values back to their original dimensions
                vals = vals.reshape(set_dims)
    return {name: {"dimensions": dims, "fields": fields, "values": vals}}


def get_set_dimension(el, acc=None):
    """Get dimensions of a float set"""
    if acc is None:
        acc = []
    if len(el) > 0:
        acc.append(len(el))
        get_set_dimension(el[0], acc)
    return acc

def get_cols(el):
    if len(el) > 0:
        return get_cols(el[0])
    else:
        return string_split(el.text)

def string_split(s):
    """Get borders for string split"""
    res = [0]
    for i in range(len(s) - 1):
        if s[i] != " " and s[i+1] == " ":
            res.append(i+1)
    if s[-1] != " ":
        res.append(len(s))
    return res


cdef void parse_float_set(el, double[:] value, long[:] set_dims, long[:] cols, int cur=0):
    cdef:
        int i, i_kid, nelem
    for i_kid in range(set_dims[0]):
        kid = el[i_kid]
        if kid.tag == "set":   # another set dimension
            new_dims = set_dims[1:]
            nelem = prod(new_dims)
            parse_float_set(kid, value, new_dims, cols, cur+i_kid*nelem)
        elif kid.tag == "r":    # just row
            text = kid.text
            for i in range(set_dims[-1]):
                value[cur] = fast_atof(text[cols[i]:cols[i+1]])
                cur += 1


def parse_general_set(el, types, ifields):
    value = []
    for kid in el:
        # split by columns
        value.append([types[i](kid[i].text) for i in ifields])
    return value


def parse_time(el, name):
    """
    Parses time Element

    :param el: An ElementTree.Element instance
    :param name: A name of the Element
    :return: a dictionary with parsing results
    """
    value = [float(t) for t in [el.text[:8], el.text[8:]]]
    return {name: value}


def _parse_entry(e_type):
    def _parse(el, name):
        return {name: to_type[e_type](el.text)}
    return _parse


base_cases = {
    "i": parse_i,
    "v": parse_v,
    "varray": parse_varray,
    "array": parse_array,
    "time": parse_time,
    "atoms": _parse_entry("int"),
    "types": _parse_entry("int"),
}


class VaspParser(object):

    def __init__(self, whitelist=None):
        """
        VaspParser is is a fast parser of XML files output by DFT codes (*vasp* as of now) written in Cython.
        It takes advantage of lxml, a Python wrapper around libxml2 library, and its Cython interface.
        XML files are parsed to a Python dictionary in a transparent way. It is really fast, up to 10 times faster than
        the parser used by pymatgen project.

        The parser can be used in a very simple way. First, the parser has to be instantiated, and then the
        ``parse_file`` method of the parser returns the dictionary of parsed values

        The result of parsing is a dictionary that follows the structure of ``vasprun.xml``. The keys of the dictionary
        are either tag names (for ``i``, ``v``, ``varray`` tags), or ``tag:tag name`` construction (for tags that do
        have name attribute), or just tags themselves. The values are either tag contents converted to the right type
        (specified by ``type`` tag attribute) or (in case of varrays and sets) Numpy arrays.

        Fortran overflows (denoted by `*****`) are converted to NaNs in case of float values and to MAXINT in
        case of integer values.

        :param whitelist: a list of XML tags to parse; default behaviour is to parse all tags in the file
        """
        self.is_whitelist = False
        self.whitelist = set()
        if whitelist is not None:
            self.is_whitelist = True
            self.whitelist = set(whitelist)

    def parse_file(self, f_name):
        """
        The main method of the parser. Parses the file with the given name

        :param f_name: the name of file to parse
        :return: The dictionary od parsed values
        """
        flag = not self.whitelist
        tree = self._get_etree(f_name)
        return self._parse_etree(tree.getroot(), flag)

    def _get_etree(self, f_name):
        try:
            return letree.parse(f_name)
        except letree.XMLSyntaxError as err:
            print('Error in {}: {}; trying to recover'.format(f_name, str(err)), file=sys.stderr)
            parser = letree.XMLParser(recover=True)
            tree = letree.parse(f_name, parser)
            print("VaspParser: File {} needed recovery, please check parsing results!".format(f_name))
        return tree

    def _parse_etree(self, dom, flag):
        d = {}
        # get our name
        name = get_name(dom)
        # check for whitelist and blacklist
        if (self.is_whitelist and name in self.whitelist) and not flag:
           flag = True
        # if flag is raised, then parse
        if flag:
            # check for base cases
            parsed = base_cases.get(dom.tag, lambda _, __: None)(dom, name)
            if parsed is not None:
                # we are in base case
                d.update(parsed)
                return d
        else:
            # check for base cases, but do not parse
            if dom.tag in base_cases:
                return None
        # the rules here are simple: 
        # 1. update d with all the node attributes (except for name)
        for k, v in dom.attrib.items():
            if k != "name": 
                d[k] = v  # TODO: d[dom.nodeName] should be updated

        # 2. then check all child element nodes
        children = [el for el in dom]
        kid_names = [get_name(kid) for kid in children]
        # 3. if some of the names are identical, put parsed data in a list (eg, scstep)
        count_kids = Counter(kid_names)
        d[name] = {}

        for (kid_name, kid) in zip(kid_names, children):
            result = self._parse_etree(kid, flag)
            if not result:
                continue
            else:
                if count_kids[kid_name] > 1:
                    kid_list = d[name].get(kid_name, [])
                    kid_list.append(result[kid_name])
                    d[name][kid_name] = kid_list
                # 4. if not, put them in a dict
                else:
                    d[name].update(result)
        # return something only if we have kids that returned something
        if d[name]:
            return d
        else:
            return None

