import sys
import pprint
import numpy as np
from datetime import datetime
from collections import Counter
#from lxml import etree
from xml.etree import cElementTree as etree

cdef extern from "fast_atoi.h":
    int fast_atoi(char *s)

cdef extern from "fast_atof.h":
    double fast_atof(char *s)

cdef double to_float(bytes s):
    return fast_atof(s) 

cdef int to_int(bytes s):
    return fast_atoi(s)

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

def dummy(el, name):
    return {get_name(el): None}

def  parse_i(el, name):
    e_type = el.attrib.get("type", None)
    value = to_type[e_type](el.text)
    return {name: value}

def parse_v(el, name):
    e_type = el.attrib.get("type", None)
    value = [to_type[e_type](v_i) for v_i in el.text.split()]
    return {name: value}

def parse_varray(el, name):
    e_type = el.attrib.get("type", None)
    value = []
    for kid in el:
        if kid.tag == "v":
            parsed_kid = parse_v(kid, None)
            value.append(parsed_kid[None])
    return {name: value}

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
            types = [to_type[f["type"]] for f in fields]
            ifields = len(fields)
            vals = parse_set(kid, types, ifields)
    return {name: {"dimensions": dims, "fields": fields, "values": vals}}

def parse_set(el, types, int ifields):
    cdef list value, val_i
    cdef int i
    value = []
    
    for kid in el:
        if kid.tag == "set":  # another set dimension
            value.append(parse_set(kid, types, ifields))
        elif kid.tag == "rc":   # row and column
            val_i = []
            # split by columns
            for i in range(ifields):
                val_i.append(types[i](kid[i].text))
            value.append(val_i)
        elif kid.tag == "r":    # just row
            val_i = []
            kid_values = kid.text.split()
            for i in range(ifields):
                val_i.append(types[i](kid_values[i]))
            value.append(val_i)
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

def parse_etree(dom):
    d = {}
    # get our name
    name = get_name(dom)
    # check for base cases
    parsed = base_cases.get(dom.tag, lambda _, __: None)(dom, name)
    if parsed is not None:
        # we are in base case
        d.update(parsed)
        return d
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
    d[name] = {kid_name: [] if count_kids[kid_name] > 1 else {} for kid_name in count_kids}

    for (kid_name, kid) in zip(kid_names, children):
        if count_kids[kid_name] > 1:
            d[name][kid_name].append(parse_etree(kid)[kid_name])
        else:
            # 4. if not, put them in a dict
            d[name].update(parse_etree(kid))
    return d


def parse_file(f_name):
    tree = etree.parse(f_name)
    return parse_etree(tree.getroot())


if __name__ == "__main__":
    if len(sys.argv) < 2:
        f_name = "set.xml"
    else:
        f_name = sys.argv[1]

    start = datetime.now()
    d = parse_file(f_name)
    finish = datetime.now()
    print "Time elapsed: {}".format(finish - start)
    # pprint.pprint(d['modeling']['eigenvalues']['array']['values'], width=150)
    print np.array(d['modeling']['eigenvalues']['array']['values']).shape