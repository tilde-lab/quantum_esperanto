"""
A pure pythonic reference version of vasp xml output parser. Pretty slow.
"""

from collections import Counter
from xml.etree import cElementTree as eTree


to_type = {
    "string": lambda x: x.strip() if x is not None else "",
    "int": int,
    None: float,
    "": float,
    "logical": lambda x: x.strip() in ["T"]
}


def get_name(el):
    """
    Finds the name of an ElementTree element (name for i,v,varray tags; tag:name for other tags)
    :param el: an Element instance
    :return: name string
    """
    if el.tag in ["i", "v", "varray"]:
        return el.attrib.get("name", None)
    else:
        return el.tag + ("" if "name" not in el.attrib else ":" + el.attrib["name"])


def parse_i(el):
    """
    i Element parser
    :param el: Element with i tag
    :return: name to value dictionary
    """
    name = get_name(el)
    e_type = el.attrib.get("type", None)
    value = to_type[e_type](el.text)
    return {name: value}


def parse_v(el):
    """
    v Element parser
    :param el: Element with v tag
    :return: name to value dictionary
    """
    name = get_name(el)
    e_type = el.attrib.get("type", None)
    value = [to_type[e_type](v_i) for v_i in el.text.split()]
    return {name: value}


def parse_varray(el):
    name = get_name(el)
    # varrays are float
    value = []
    for kid in el:
        if kid.tag == "v":
            parsed_kid = parse_v(kid)
            value.append(parsed_kid[None])
    return {name: value}


def parse_array(el):
    # array has dimensions, field names and sets of values
    name = get_name(el)
    dims = []
    fields = []
    vals = []
    for kid in el:
        if kid.tag == "dimension":
            dims.append(kid.text)
        if kid.tag == "field":
            fields.append({"name": kid.text, "type": kid.attrib.get("type", None)})
        if kid.tag == "set":
            vals = parse_set(kid, dims, fields)
    return {name: {"dimensions": dims, "fields": fields, "values": vals}}


def parse_set(el, dims, fields):
    value = []
    for kid in el:
        if kid.tag == "set":  # another set dimension
            value.append(parse_set(kid, dims, fields))
        if kid.tag == "rc":   # row and column
            # split by columns
            value.append([to_type[f["type"]](c.text) for (f, c) 
                          in zip(fields, kid) if c.tag == "c"])
        if kid.tag == "r":    # just row
            value.append([to_type[f["type"]](c) for (f, c) in zip(fields, kid.text.split())])
    return value


def parse_time(el):
    name = get_name(el)
    value = [float(t) for t in [el.text[:8], el.text[8:]]]
    return {name: value}


def parse_entry(e_type):
    def _parse(el):
        return {el.tag: to_type[e_type](el.text)}
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
    parsed = base_cases.get(dom.tag, lambda _: None)(dom)
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
    tree = eTree.parse(f_name)
    return parse_etree(tree.getroot())
