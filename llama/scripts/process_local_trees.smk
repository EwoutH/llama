
from Bio import Phylo
from Bio import SeqIO
import csv
import collections

config["tree_stems"] = config["local_str"].split(",")

rule all:
    input:
        expand(os.path.join(config["tempdir"], "collapsed_trees","{tree}.newick"), tree = config["tree_stems"]),
        os.path.join(config["outdir"],"local_trees","collapse_report.txt"),
        expand(os.path.join(config["outdir"],"local_trees","{tree}.tree"), tree = config["tree_stems"])


rule annotate:
    input:
        tree = os.path.join(config["tempdir"],"catchment_trees","{tree}.nexus"),
        metadata = config["combined_metadata"]
    params:
        id_column = config["search_field"]
    output:
        tree = os.path.join(config["outdir"],"annotated_trees","{tree}.nexus")
    shell:
        """
        ~/Documents/jclusterfunk/release/jclusterfunk_v0.0.1/jclusterfunk annotate \
        -i {input.tree:q} \
        -o {output.tree} \
        -m {input.metadata:q} \
        -r \
        --id-column closest \
        --tip-attributes lineage \
        -f nexus
        """

rule summarise_polytomies:
    input:
        tree = os.path.join(config["outdir"], "annotated_trees","{tree}.nexus"),
        metadata = config["combined_metadata"]
    params:
        tree_dir = os.path.join(config["outdir"],"catchment_trees"),
        threshold = config["threshold"]
    output:
        collapsed_tree = os.path.join(config["tempdir"],"collapsed_trees","{tree}.newick"),
        collapsed_information = os.path.join(config["outdir"],"local_trees","{tree}.txt")
    shell:
        """
        clusterfunk focus -i {input.tree:q} \
        -o {output.collapsed_tree:q} \
        --metadata {input.metadata:q} \
        --index-column closest \
        --in-format nexus \
        --out-format newick \
        --threshold {params.threshold} \
        --output-tsv {output.collapsed_information:q}
        """

rule get_collapsed_representative:
    input:
        seqs = config["seqs"],
        collapsed_information = rules.summarise_polytomies.output.collapsed_information
    params:
        tree_dir = os.path.join(config["tempdir"],"collapsed_trees")
    output:
        representative_seq = os.path.join(config["tempdir"],"collapsed_trees","{tree}_representatives.fasta"),
    run:
        collapsed = {}
        collapsed_seqs = collections.defaultdict(list)
        
        with open(input.collapsed_information, "r") as f:
            for l in f:
                l = l.rstrip("\n")
                collapsed_name,taxa = l.split('\t')
                collapsed[collapsed_name] = taxa.split(",")
        for record in SeqIO.parse(input.seqs,"fasta"):
            for node in collapsed:
                if record.id in collapsed[node]:
                    collapsed_seqs[node].append(record)

        with open(output.representative_seq, "w") as fw:
            for node in collapsed_seqs:
                records = collapsed_seqs[node]
                sorted_with_amb = []
                for record in records:
                    amb_count = 0
                    for base in record.seq:
                        if base.upper() not in ["A","T","C","G","-"]:
                            amb_count +=1
                    amb_pcent = (100*amb_count) / len(record.seq)
                    sorted_with_amb.append((record.id, amb_pcent, record.seq))
                sorted_with_amb = sorted(sorted_with_amb, key = lambda x : x[1])
                rep = sorted_with_amb[0]
                fw.write(f">{node} representative={rep[0]} ambiguity={rep[1]}\n{rep[2]}\n")
        
rule extract_taxa:
    input:
        collapsed_tree = os.path.join(config["tempdir"],"collapsed_trees","{tree}.nexus")
    output:
        tree_taxa = os.path.join(config["tempdir"], "collapsed_trees","{tree}_taxon_names.txt")
    shell:
        "clusterfunk get_taxa -i {input.collapsed_tree} --in-format newick -o {output.tree_taxa} --out-format newick"

rule gather_fasta_seqs:
    input:
        collapsed_nodes = os.path.join(config["tempdir"],"collapsed_trees","{tree}_representatives.fasta"),
        aligned_query_seqs = config["aligned_query_seqs"],
        seqs = config["seqs"],
        outgroup_fasta = config["outgroup_fasta"],
        combined_metadata = config["combined_metadata"],
        tree_taxa = rules.extract_taxa.output.tree_taxa
    output:
        aln = os.path.join(config["tempdir"], "catchment_aln","{tree}.query.aln.fasta")
    run:
        taxa = []
        with open(input.tree_taxa, "r") as f:
            for l in f:
                l = l.rstrip("\n")
                taxa.append(l)

        queries = []
        with open(input.combined_metadata,newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row["closest"] in taxa:
                    if row["closest"] != row["query"]:
                        queries.append(row["query"])

        added_seqs = []
        with open(output.aln, "w") as fw:
            for record in SeqIO.parse(input.outgroup_fasta, "fasta"):
                fw.write(f">{record.description}\n{record.seq}\n")
                added_seqs.append(record.id)

            for record in SeqIO.parse(input.aligned_query_seqs, "fasta"):
                if record.id in queries:
                    fw.write(f">{record.description}\n{record.seq}\n")
                    added_seqs.append(record.id)

            for record in SeqIO.parse(input.collapsed_nodes, "fasta"):
                fw.write(f">{record.description}\n{record.seq}\n")
                added_seqs.append(record.id)

            for record in SeqIO.parse(input.seqs,"fasta"):
                if record.id in taxa:
                    fw.write(f">{record.description}\n{record.seq}\n")
                    added_seqs.append(record.id)


rule hash_for_iqtree:
    input:
        aln = rules.gather_fasta_seqs.output.aln
    output:
        hash = os.path.join(config["tempdir"], "renamed_trees","{tree}.hash_for_iqtree.csv"),
        hashed_aln = os.path.join(config["tempdir"], "renamed_trees","{tree}.query.aln.fasta")
    run:
        fw = open(output.hash, "w")
        fw.write("taxon,iqtree_hash,cluster_hash\n")
        hash_count = 0
        with open(output.hashed_aln, "w") as fseq:
            for record in SeqIO.parse(input.aln, "fasta"):
                hash_count +=1
                if record.id == "outgroup":
                    fw.write(f"outgroup,outgroup,outgroup\n")
                    fseq.write(f">outgroup\n{record.seq}\n")
                else:
                    without_str = record.id.rstrip("'").lstrip("'")
                    fw.write(f"{without_str},_taxon_{hash_count}_,taxon_{hash_count}\n")
                    fseq.write(f">'taxon_{hash_count}'\n{record.seq}\n")
        fw.close()

rule hash_tax_labels:
    input:
        tree=os.path.join(config["tempdir"],"collapsed_trees","{tree}.nexus"),
        hash = rules.hash_for_iqtree.output.hash
    output:
        tree = os.path.join(config["tempdir"],"renamed_trees","{tree}.nexus")
    shell:
        """
        clusterfunk relabel_tips -i {input.tree:q} \
        -o {output[0]:q} \
        --in-metadata {input.hash:q} \
        --index-column taxon \
        --trait-columns cluster_hash \
        --replace \
        --in-format newick \
        --out-format newick
        """

rule iqtree_catchment:
    input:
        aln = os.path.join(config["tempdir"], "renamed_trees","{tree}.query.aln.fasta")
    output:
        tree = os.path.join(config["tempdir"], "renamed_trees","{tree}.query.aln.fasta.treefile")
    shell:
        "iqtree -s {input.aln:q} -au -m HKY -nt 1 -redo -o outgroup"


rule restore_tip_names:
    input:
        tree = rules.iqtree_catchment.output.tree,
        hash = rules.hash_for_iqtree.output.hash
    output:
        os.path.join(config["tempdir"],"almost_restored_trees","{tree}.newick")
    shell:
        """
        clusterfunk relabel_tips -i {input.tree:q} \
        -o {output[0]:q} \
        --in-metadata {input.hash:q} \
        --index-column iqtree_hash \
        --trait-columns taxon \
        --replace \
        --in-format newick \
        --out-format newick
        """

rule prune_outgroup:
    input:
        tree = os.path.join(config["tempdir"],"almost_restored_trees","{tree}.newick"),
        prune = config["outgroup_fasta"]
    output:
        tree = os.path.join(config["tempdir"],"outgroup_pruned","{tree}.newick")
    shell:
        """
        clusterfunk prune -i {input.tree:q} \
        -o {output.tree:q} \
        --fasta {input.prune:q} \
        --in-format newick \
        --out-format newick
        """

rule remove_str_for_baltic:
    input:
        tree = os.path.join(config["tempdir"],"outgroup_pruned","{tree}.newick")
    output:
        tree = os.path.join(config["tempdir"],"local_trees","{tree}.newick")
    run:
        with open(output.tree,"w") as fw:
            with open(input.tree, "r") as f:
                for l in f:
                    l = l.rstrip("\n")
                    l = l.replace("'","")
                    fw.write(l)


rule summarise_processing:
    input:
        collapse_reports = expand(os.path.join(config["outdir"],"local_trees","{tree}.txt"), tree=config["tree_stems"])
    output:
        report = os.path.join(config["outdir"],"local_trees","collapse_report.txt")
    run:
        with open(output.report, "w") as fw:
            for report in input.collapse_reports:
                fn = os.path.basename(report)
                with open(report, "r") as f:
                    for l in f:
                        l = l.rstrip("\n")
                        new_l = f"{fn}\t{l}\n"
                        fw.write(new_l)
