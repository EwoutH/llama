#!/usr/bin/env python3
import csv
import argparse
from Bio import SeqIO
import collections
"""
--paf {input.paf:q} 
--metadata {input.metadata:q} 
--csv-out {output.csv:q} 
"""
def parse_args():
    parser = argparse.ArgumentParser(description='Parse minimap paf file')

    parser.add_argument("--paf", action="store", type=str, dest="paf")
    parser.add_argument("--metadata", action="store", type=str, dest="metadata")
    parser.add_argument("--search-field", action="store",type=str, dest="search_field")
    parser.add_argument("--csv-out", action="store", type=str, dest="outfile")
    parser.add_argument("--seqs", action="store", type=str, dest="seqs")
    parser.add_argument("--seqs-out", action="store", type=str, dest="seqs_out")
    return parser.parse_args()


def parse_line(line):
    values = {}
    tokens = line.rstrip('\n').split('\t')
    values["name"], values["read_len"] = tokens[:2]
    values["ref_hit"], values["ref_len"], values["coord_start"], values["coord_end"], values["matches"], values["aln_block_len"] = tokens[5:11]
    return values


def get_closest_sequences(paf):

    closest_sequences = []
    closest_to_query = collections.defaultdict(list)
    with open(paf,"r") as f:
        last_mapping = None
        for line in f:
            mapping = parse_line(line)
            closest_to_query[mapping["ref_hit"]].append(mapping["name"])

    return closest_to_query


def parse_paf_and_get_metadata():
    args = parse_args()

    closest_to_query = get_closest_sequences(args.paf)
    column_to_match = args.search_field
    
    with open(args.metadata, newline="") as f:
        rows_to_write = []
        reader = csv.DictReader(f)
        header_names = reader.fieldnames
        with open(args.outfile, "w") as fw:
            header_names.append("query")
            header_names.append("closest")
            writer = csv.DictWriter(fw, fieldnames=header_names,lineterminator='\n')
            writer.writeheader()
        
            for row in reader:
                if row[column_to_match] in closest_to_query:
                    for query in closest_to_query[row[column_to_match]]:
                        new_row = row
                        new_row["query"]=query
                        new_row["closest"]=row[column_to_match]

                        writer.writerow(new_row)


    with open(args.seqs_out, "w") as fw:
        for record in SeqIO.parse(args.seqs,"fasta"):
            if record.id in closest_to_query:
                closest_queries = ",".join(closest_to_query[record.id])
                fw.write(f">{record.id} query={closest_queries}\n{record.seq}\n")

if __name__ == '__main__':

    parse_paf_and_get_metadata()
    