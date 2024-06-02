
def _gene_subsample_1(input, output, group, sub_region, DICT_DIR):
    import gzip
    import sys
    
    from funs import _create_gene_sub_dict
    
    # Persistent dictionary for storing minimum gene counts for subsampling
    # clear the dictionary to remove results from previous runs
    GENE_SUB_DICT = _create_gene_sub_dict(group, sub_region, DICT_DIR)
    
    GENE_SUB_DICT.clear()
    
    # Get list of genes present in the first input file
    # could use any file in the group
    with gzip.open(input[0], "rt") as f:
        genes = [l.strip().split("\t")[3] for l in f]
    
    # Create set with counts for each gene and sample file
    for gene in genes:
        gene_set = set()
    
        for file in input:
            f = gzip.open(file, "rt")
    
            found = False
    
            for l in f:
                l = l.strip().split("\t")
                g = l[3]
                c = int(l[6])
    
                if g == gene:
                    gene_set.add(c)
    
                    found = True
    
                    break
    
            if not found:
                gene_set.add(0)  # report 0 counts if gene not found
    
        # Store minimum count for the group in persistent dict
        min_reads = min(gene_set)
    
        GENE_SUB_DICT.store(gene, min_reads)
    
        # Save minimum counts in summary file
        with open(output, "a") as out:
            out.write("%s\t%s\tSampled reads\t%s\n" % (group, gene, min_reads))


def _gene_subsample_2(reads, tmp, group, sub_region, DICT_DIR):
    from pytools.persistent_dict import PersistentDict
    import random
    import gzip
    import sys
    
    sys.path.insert(0, "src/rules")
    
    from funs import _create_gene_sub_dict
    
    # Persistent dictionary
    # this contains the minimum number of reads aligning to each gene for
    # the subsampling group
    GENE_SUB_DICT = _create_gene_sub_dict(group, sub_region, DICT_DIR)
    
    # Create dictionary containing reads to use for subsampling
    reads = gzip.open(reads, "rt")
    
    READS_DICT = dict()
    
    for l in reads:
        l    = l.strip()
        gene = l.split("\t")[3]
    
        if gene not in READS_DICT:
            READS_DICT[gene] = [l]
    
        else:
            READS_DICT[gene].append(l)
    
    # Subsample reads in READS_DICT and write bed file
    # pull minimum read count for the gene from GENE_SUB_DICT
    with open(tmp, "a") as out:
        for gene in READS_DICT.keys():
    
            MIN_READS = GENE_SUB_DICT.fetch(gene)
    
            if len(READS_DICT[gene]) > MIN_READS:
                READS_DICT[gene] = random.sample(READS_DICT[gene], MIN_READS)
    
            for l in READS_DICT[gene]:
                out.write("%s\n" % l)


