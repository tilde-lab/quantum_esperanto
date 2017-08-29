#!/usr/bin/env python

import json
import os
import argparse
import sqlite3
import numpy as np
from progressbar import ProgressBar
from DFTXMLParser import VaspParser
from datetime import datetime

# some default values
log_dir = '/mnt/c/Users/Andrey/Workspace/logs'
# log_dir = '/home/user/logs'
f_name = 'vasprun.xml.static'
db_name = 'backup.db'


def jsonify(data):
    """Prepare data to serialize with JSON (especially np.arrays)"""
    json_data = dict()
    for key, value in data.iteritems():
        if isinstance(value, list): # for lists
            value = [ jsonify(item) if isinstance(item, dict) else item for item in value ]
        if isinstance(value, dict): # for nested lists
            value = jsonify(value)
        if isinstance(key, int): # if key is integer: > to string
            key = str(key)
        if isinstance(value, np.ndarray): # if value is numpy.*: > to python list
            value = value.tolist()
        json_data[key] = value
    return json_data


def prepare_db():
    # prepare
    kvconn = sqlite3.connect(':memory:')
    kvconn.isolation_level = None
    kvstore = kvconn.cursor()
    kvstore.execute('PRAGMA temp_store=MEMORY;')
    kvstore.execute('PRAGMA journal_mode=OFF;')
    kvstore.execute('PRAGMA cache_size=16000;')
    kvstore.execute("PRAGMA locking_mode=EXCLUSIVE;")
    kvstore.execute("PRAGMA synchronous=OFF;")
    kvstore.execute("""CREATE TABLE keystore (id INTEGER PRIMARY KEY, value TEXT UNIQUE)""")
    return kvconn, kvstore


def save(kvstore, value):
    # save
    kvstore.execute("INSERT INTO keystore(value) VALUES (?);", (value, ))
    # print(kvstore.lastrowid)


def backup(kvconn, f_name):
    # backup
    out_bk = open(f_name, "w")
    for line in kvconn.iterdump():
        out_bk.write('%s\n' % line)
    out_bk.close()
    kvconn.close()


def restore(kvconn, kvstore, f_name):
    # restore
    with open(f_name, "r") as r:
        kvstore.executescript(r.read())
    kvconn.commit()

# get some command line arguments
parser = argparse.ArgumentParser(description='Batch parse VASP XML files.')
parser.add_argument('--dir', nargs=1, default=log_dir, help='a directory with log files (default: {})'.format(log_dir))
parser.add_argument('--db', nargs=1, default=db_name, help='an SQLite3 file where the result is stored (default: {})'.format(db_name))
parser.parse_args()

xml_files = []
for root, dirs, files in os.walk(log_dir):
    if f_name in files:
        xml_files.append(os.path.join(root, f_name))

conn, store = prepare_db()
bar = ProgressBar()
parser = VaspParser(whitelist=['eigenvalues', 'structure:finalpos'])

start = datetime.now()
for f in bar(xml_files):
    d = parser.parse_file(f)
    save(store, json.dumps(jsonify(d)))
print 'Time elapsed: {}'.format(datetime.now() - start)

if db_name != ':memory:':
    backup(conn, db_name)