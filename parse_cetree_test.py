#!/usr/bin/env python

import sys
import pprint
from datetime import datetime
from parse_cetree import parse_file


if __name__ == "__main__":
    if len(sys.argv) < 2:
        f_name = "LSCF.xml"
    else:
        f_name = sys.argv[1]

    start = datetime.now()
    d = parse_file(f_name)
    finish = datetime.now()
    print "Time elapsed: {}".format(finish - start)
    #pprint.pprint(d)
