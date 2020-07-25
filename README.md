# llama

**L**ocal **L**ineage and **M**onophyly **A**ssessment

<img src="./docs/llama_logo.svg" width="450">

## Quick links

  * [Requirements](#requirements)
  * [Install llama](#install-llama)
  * [Check the install worked](#check-the-install-worked)
  * [Updating llama](#updating-llama)
  * [Usage](#usage)
  * [Analysis pipeline](#analysis-pipeline)
  * [Output](#output)
  * [Acknowledgements](#acknowledgements)
  * [References](#references)
  * [Software versions](#software-versions)


### Requirements

<strong>llama</strong> runs on MacOS and Linux. The conda environment recipe may not build on Windows and is not supported but can be run using the Windows subsystem for Linux.

1. Some version of conda, we use Miniconda3. Can be downloaded from [here](https://docs.conda.io/en/latest/miniconda.html)
2. Your input query file with a row for each sequence name you want to analyse/ create local trees for. These can be present in the big tree already or in the fasta file you supply
3. Optional fasta file if there are sequences you want to add into the tree
4. A directory of data containing the following files:
    - <strong>global.tree</strong>: a large tree that you want to place your sequences in
    - <strong>alignment.fasta</strong>: an alignment file with the fasta sequences used to make the tree
    - <strong>metadata.csv</strong>: associated metadata with minimally the name of the sequences in the tree/ alignment and a lineage designation
    The names of the tips of the tree, the sequence ids in the alignment and the column you select as `--data-column` in the metadata must match


### Install llama

1. Clone this repository and ``cd llama``
2. ``conda env create -f environment.yml``
3. ``conda activate llama``
4. ``python setup.py install``

> Note: we recommend using llama in the conda environment specified in the ``environment.yml`` file as per the instructions above. If you can't use conda for some reason, dependency details can be found in the ``environment.yml`` file.


### Check the install worked

Type (in the llama environment):

```
llama
```
and you should see the help menu of llama printed.

### Updating llama

> Note: Even if you have previously installed ``llama``, as it is being worked on intensively, we recommend you check for updates before running.

To update:

1. ``conda activate llama``
2. ``git pull`` \
pulls the latest changes from github
3. ``python setup.py install`` \
re-installs llama
4. ``conda env update -f environment.yml`` \
updates the conda environment

### Usage

1. Activate the environment ``conda activate llama``
2. Run ``llama <query> [options]``

Example usage:
> ``llama llama/tests/test.csv --fasta llama/tests/test.fasta --datadir <path/to/data> ``

Full usage:
```
llama: Local Lineage And Monophyly Assessment

positional arguments:
  query                 Input csv file with minimally `name` as a column
                        header. Alternatively, `--input-column` can specifiy a
                        column name other than `name`

optional arguments:
  -h, --help            show this help message and exit
  -i, --id-string       Indicates the input is a comma-separated id string
                        with one or more query ids. Example:
                        `EDB3588,EDB3589`.
  --fasta FASTA         Optional fasta query. Fasta sequence names must
                        exactly match those in your input query.
  -o OUTDIR, 
  --outdir OUTDIR
                        Output directory. Default: current working directory
  --outgroup OUTGROUP   Optional outgroup sequence to root local subtrees.
                        Default an anonymised sequence that is at the base of
                        the global SARS-CoV-2 phylogeny.
  -d DATADIR, 
  --datadir DATADIR
                        Local directory that contains the data files
  --input-column INPUT_COLUMN
                        Column in input csv file to match with database.
                        Default: name
  --data-column DATA_COLUMN
                        Column in database to match with input csv file.
                        Default: sequence_name
  --distance DISTANCE   Extraction from large tree radius. Default: 2
  -n, --dry-run         Go through the motions but don't actually run
  --tempdir TEMPDIR     Specify where you want the temp stuff to go. Default:
                        $TMPDIR
  --no-temp             Output all intermediate files, for dev purposes.
  --collapse-threshold THRESHOLD
                        Minimum number of nodes to collapse on. Default: 1
  -t THREADS, --threads THREADS
                        Number of threads
  --verbose             Print lots of stuff to screen
  --max-ambig MAXAMBIG  Maximum proportion of Ns allowed to attempt analysis.
                        Default: 0.5
  --min-length MINLEN   Minimum query length allowed to attempt analysis.
                        Default: 10000
  -v, --version         show program's version number and exit
```

### Analysis pipeline


Overview:


- From the input csv (`<query>`), <strong>llama</strong> attempts to match the ids with ids in the metadata.csv.

- If the id matches with a record, the corresponding metadata is pulled out.

- If the id doesn't match with a record and a fasta sequence with that query id has been provided, it's passed into a workflow (`find_closest_in_db.smk`) to identify the closest sequence. In brief, this search consists of quality control steps that maps the sequence against a reference (an early, anonymised sequence from lineage A at the root of the global tree), pads any indels relative to the reference and masks non-coding regions. llama then runs a `minimap2` search against the alignment.fasta file and finds the best hit to the query sequence.

- The metadata for the closest sequences are then also pulled out of the large metadata.csv.

- Combining the metadata from the records of the closest hit and the exact matching records found in the csv, <strong>llama</strong> queries the large global.tree phylogeny. The local trees around the relevant tips are pruned out of the large phylogeny, merging overlapping local phylogenys as needed. By default, <strong>llama</strong> pulls out a local tree two above the query id tips, but this can be customised with the `--distance` argument if larger or smaller trees are desired. 

- If these local trees contain "closest-matching" tips that have been found based on the input fasta file, the sequence records for the tips on the tree and the sequences of the relevant queries are added into an alignment. <strong>llama</strong> then checks what lineages are present in the local tree and flags a maximum of 10 sequences per lineage to retain the surrounding context of the tree. Any peripheral sequences coming off of a polytomy that are not flagged and are not the query sequences are collapsed to a single node and summaries of the tip's contents are output. An outgroup sequence from the base of the tree at lineage A is added into the alignment.

- After collapsing the nodes, <strong>llama</strong> runs `iqtree` on the new alignment, with the outgroup and query sequences in, and then prunes off the outgroup sequence.

- <strong>llama</strong> then annotates this new phylogeny with lineage assignments and can produce a report (COMING SOON!).

### Output

- Catchment trees around the query sequences (uncollapsed)
- Collapsed local trees (containing query sequences if optional fasta file supplied) with a representative set of sequences from surrounding lineages and query tips uncollapsed

### Acknowledgements

<strong>llama</strong> makes use of [`datafunk`](https://github.com/cov-ert/datafunk) and [`clusterfunk`](https://github.com/cov-ert/clusterfunk) functions which have been written by members of the Rambaut Lab, specificially Rachel Colquhoun, JT McCrone, Ben Jackson and Shawn Yu.

<strong>llama</strong> runs a java implementation [`jclusterfunk`](https://github.com/cov-ert/clusterfunk) written by Andrew Rambaut.

[`baltic`](https://github.com/evogytis/baltic/tree/master/baltic) by Gytis Dudas is used to visualize the trees.

### References

[`minimap2`](https://github.com/lh3/minimap2) 

Heng Li, Minimap2: pairwise alignment for nucleotide sequences, Bioinformatics, Volume 34, Issue 18, 15 September 2018, Pages 3094–3100, https://doi.org/10.1093/bioinformatics/bty191

[iqtree](http://www.iqtree.org/#download)

L.-T. Nguyen, H.A. Schmidt, A. von Haeseler, B.Q. Minh (2015) IQ-TREE: A fast and effective stochastic algorithm for estimating maximum likelihood phylogenies.. Mol. Biol. Evol., 32:268-274. https://doi.org/10.1093/molbev/msu300

D.T. Hoang, O. Chernomor, A. von Haeseler, B.Q. Minh, L.S. Vinh (2018) UFBoot2: Improving the ultrafast bootstrap approximation. Mol. Biol. Evol., 35:518–522. https://doi.org/10.1093/molbev/msx281

Stéphane Guindon, Jean-François Dufayard, Vincent Lefort, Maria Anisimova, Wim Hordijk, Olivier Gascuel, New Algorithms and Methods to Estimate Maximum-Likelihood Phylogenies: Assessing the Performance of PhyML 3.0, Systematic Biology, Volume 59, Issue 3, May 2010, Pages 307–321, https://doi.org/10.1093/sysbio/syq010

[snakemake](https://snakemake.readthedocs.io/en/stable/index.html)

Köster, Johannes and Rahmann, Sven. “Snakemake - A scalable bioinformatics workflow engine”. Bioinformatics 2012.

### Software versions

- python=3.6
- snakemake-minimal=5.13
- iqtree=1.6.12
- minimap2=2.17-r941
- pandas==1.0.1
- pytools=2020.1
- dendropy=4.4.0
