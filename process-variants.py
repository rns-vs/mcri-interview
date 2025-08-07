#!/usr/bin/env python3

"""

   Process input file according to this specification:

   2.  After that we would like to dive into some Python coding. I
   attached a TSV file named “variants.tsv” with the following
   columns: 

   #CHROM            POS       ID           REF        ALT        QUAL    FILTER

   Could you write a Python script to discard rows with QUAL < 40
   OR FILTER != PASS and write the remaining rows to a new TSV file.
   All columns and headers should remain the same.

"""

import csv

INPUT_FILE = 'variants.tsv'
OUTPUT_FILE = 'variants-filtered.tsv'

# def main():
#     with open(INPUT_FILE, 'r') as f:
#         while line in f:
#             print(line)

# if __name__ == '__main__':

fieldnames = ['#CHROM', 'POS', 'ID', 'REF', 'ALT', 'QUAL', 'FILTER']

with open(INPUT_FILE, 'r') as f, open(OUTPUT_FILE, 'w') as filtered:
    reader = csv.DictReader(f, delimiter='\t')
    writer = csv.DictWriter(filtered, fieldnames, delimiter='\t')
    writer.writerow(['#CHROM', 'POS', 'ID', 'REF', 'ALT', 'QUAL', 'FILTER'])
    for row in reader:
        if int(row['QUAL']) < 40:
            continue
        elif row['FILTER'] != 'PASS':
            continue
        else:
            writer.writerow(row)
