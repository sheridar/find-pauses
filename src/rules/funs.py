# ===== Functions for pipeline =====================


# Create persistent dictionary to store gene subsampling info
def _create_gene_sub_dict(group, region, dict_dir):
    from pytools.persistent_dict import PersistentDict

    dict_name = "GENE_SUB_DICT_" + group + "_" + region
    dict_dir  = dict_dir + "/" + dict_name

    os.makedirs(dict_dir, exist_ok = True)

    gene_sub_dict = PersistentDict(dict_name, container_dir = dict_dir)

    return(gene_sub_dict)


# Delete all files in directory
def _clear_directory(directory):

    # List all contents of the directory
    for filename in os.listdir(directory):
        file_path = os.path.join(directory, filename)

        # Check if file or directory
        if os.path.isfile(file_path) or os.path.islink(file_path):
            os.remove(file_path)

        elif os.path.isdir(file_path):
            shutil.rmtree(file_path)


# Find all fastqs matching sample name in provided directories
def _find_fqs(sample, dirs):
    fq_pat   = ".*" + sample + r".+\.(fastq|fq)\.gz$"
    fq_paths = []
    
    for dir in dirs:
        all_files = glob.glob(os.path.abspath(os.path.join(dir, "*.gz")))
        paths     = [f for f in all_files if re.match(fq_pat, f)]
    
        for path in paths:
            fq_paths.append(path)

    if not fq_paths:
        sys.exit("ERROR: no fastqs found for " + fq_pat + ".")

    return fq_paths


# Determine the suffix (e.g. fastq.gz) for a list of fastqs matching a single
# sample name the expectation is that all fastqs in the list will have the
# same suffix
def _get_fq_sfx(fqs):
    sfx = []
    
    for fq in fqs:
        if re.search(r"\.fastq\.gz$", fq):
            sf = ".fastq.gz"
    
        if re.search(r"\.fq\.gz$", fq):
            sf = ".fq.gz"
    
        sfx.append(sf)
    
    sfx = set(sfx)
    
    if len(sfx) > 1:
        sys.exit("ERROR: Multiple fastqs found for " + sample + ".")
    
    sfx = list(sfx)[0]

    return sfx


# For the fastq suffix (e.g. fastq.gz) get the complete suffix for both reads
# (e.g. _R1_001.fastq.gz)
def _get_full_fq_sfxs(sfx):
    if sfx == ".fastq.gz":
        fq_sfx = ["_" + x + "_001" + sfx for x in ["R1", "R2"]]

    elif sfx == ".fq.gz":
        fq_sfx = ["_" + x + sfx for x in ["1", "2"]]

    else:
        fq_sfx = sfx

    return fq_sfx


# Get the fastq file for both reads for the provided sample name
def _get_fqs(sample, dirs, link_dir, full_name = False):

    fq_paths = _find_fqs(sample, dirs)
    
    sfx = _get_fq_sfx(fq_paths)

    sfxs = _get_full_fq_sfxs(sfx)

    # Find matching fastqs and create symlinks 
    fastqs = []
    
    for full_sfx in sfxs:
        fq_pat = ".*/" + sample + ".*" + full_sfx
    
        fq = [f for f in fq_paths if re.match(fq_pat, f)]
    
        # Check for duplicate paths
        if not fq:
            sys.exit("ERROR: no fastqs found for " + fq_pat + ".")
    
        if len(fq) > 1:
            sys.exit("ERROR: Multiple fastqs found for " + fq_pat + ".")
    
        fq = fq[0]
    
        fastq = os.path.basename(fq)

        # Create symlinks
        # Using subprocess since os.symlink requires a target file instead of
        # target directory
        fq_lnk = link_dir + "/" + fastq
    
        if not os.path.exists(fq_lnk):
            cmd = "ln -s " + fq + " " + link_dir
    
            if cmd != "":
                subprocess.run(cmd, shell = True)
    
        # Return fastq path or just the fastq name
        if full_name:
            fastqs.append(fq_lnk)
    
        else:
            fastqs.append(fastq)
    
    return fastqs


