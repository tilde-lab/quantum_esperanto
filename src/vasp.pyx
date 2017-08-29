# cython: c_string_type=str, c_string_encoding=ascii, profile=True

import numpy as np
from collections import Counter
#from lxml import etree
from xml.etree import cElementTree as etree


cdef extern from "fast_atoi.h":
    int fast_atoi(char *s)


cdef extern from "fast_atof.h":
    double fast_atof(char *s)


cdef double to_float(s):
    cdef char* f = s
    return fast_atof(f) 


cdef int to_int(s):
    cdef char* i = s
    return fast_atoi(i)


cdef long prod(long[:] mv):
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
    if el.tag in ["i", "v", "varray"]:
        return el.attrib.get("name", None)
    else:
        return el.tag + ("" if not "name" in el.attrib else ":" + el.attrib["name"])


def parse_i(el, name):
    e_type = el.attrib.get("type", None)
    value = to_type[e_type](el.text)
    return {name: value}


def parse_v(el, name):
    e_type = el.attrib.get("type", None)
    value = [to_type[e_type](v_i) for v_i in el.text.split()]
    return {name: value}


def parse_varray(el, name):
    e_type = el.attrib.get("type", None)
    if e_type is not None:
        return parse_general_varray(el, name)
    else:
        # fast parsing of float varray
        dims = np.array([len(el), len(el[0].text.split())])
        # allocate memory
        value = np.zeros(dims, dtype=float).reshape(-1)
        cols = np.array(get_cols(el))
        parse_float_varray(el, value, dims, cols)
        return {name: value.reshape(dims)}


def parse_general_varray(el, name):
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
    value = [float(t) for t in [el.text[:8], el.text[8:]]]
    return {name: value}


def parse_entry(e_type):
    def _parse(el, name):
        return {name: to_type[e_type](el.text)}
    return _parse


base_cases = {
    "i": parse_i,
    "v": parse_v,
    "varray": parse_varray,
    "array": parse_array,
    "time": parse_time,
    "atoms": parse_entry("int"),
    "types": parse_entry("int"),
}



class VaspParser(object):
    def __init__(self,
                 recover=True,
                 whitelist=None):
        self.recover = recover
        self.is_whitelist = False
        self.whitelist = set()
        if whitelist is not None:
            self.is_whitelist = True
            self.whitelist = set(whitelist)

    def parse_file(self, f_name):
        flag = not self.whitelist
        tree = etree.parse(f_name)
        return self._parse_etree(tree.getroot(), flag)

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

