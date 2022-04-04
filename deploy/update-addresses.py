#!/usr/bin/env python3

# must be run from root folder, not from inside deploy

import sys, json
from os.path import exists

if __name__ == '__main__':
    print(str(sys.argv))
    num_args = len(sys.argv)
    if num_args % 2 == 0 or num_args < 3:
        raise Exception('args must be chainid followed by pairs of contract name, contract address')
    chain_id = sys.argv[0]
    file_path = 'addresses/' + chain_id + '.json'
    file_exists = exists(file_path)
    addrs_dict = {}
    if (file_exists):
        addrs_dict = json.load(file_path)
    for i in list(range(1, num_args, 2)):
        addrs_dict[sys.argv[i]] = sys.argv[i+1]
    with open(file_path, "w") as write_file:
        json.dump(addrs_dict, write_file, indent=4, sort_keys=True)
