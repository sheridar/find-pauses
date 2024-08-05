### common helper scripts ###

import os
import re
import glob

# estimates the amount of memory based on file size
def memory_estimator(input_files, multiplier, minsize=4):
    total_size_gb = sum(os.path.getsize(f) for f in input_files) / (1024 ** 3)  # Convert bytes to GB
    return round(max(total_size_gb * multiplier, minsize))  # Ensure at least minsize GB

# extract barcode from fastq file
def _get_barcodes(wildcards):
    import os.path
    import re
    sample = wildcards.sample
    patternfile = BARCODES
    filename =  PROJ + "/" + sample + "_R1_clumpify.fastq.gz"
    
    if os.path.exists(patternfile):
      with gzip.open(filename,'rt') as f:
        header = f.readline().strip().split()
        header2 = header[1].split(":")
        my_indexs = header2[-1].split("+")
      
      index_patterns = {}
      for line in open(patternfile):
        index, pattern = line.strip().split("=")
        index_patterns[index] = pattern
        
      results = []
      for t in my_indexs:
        for p in index_patterns:
          match = re.search(p, t)
          if match:
            results.append(index_patterns[p])
            break  # Exit the loop if a match is found
    else:
      results=BARCODES.strip().split()
    return ','.join(results)
    
# gets number for norm fraction sample
def _get_norm_samp(wildcards):
    sample = wildcards.sample + "_" + INDEX_SAMPLE
    filename =  PROJ + "/stats/" + PROJ + "_" + INDEX_SAMPLE + "_subsample_frac.tsv"
    num = 0
    with open(filename, "r") as file:
      for line in file:
        parts = line.strip().split('\t')
        if len(parts) == 3 and parts[0] == sample:
          num = parts[2]
          break
    return float(num)
        
# gets number for norm fraction sample
def _get_norm_spike(wildcards):
    sample = wildcards.sample + "_" + INDEX_SPIKE
    filename =  PROJ + "/stats/" + PROJ + "_" + INDEX_SPIKE + "_subsample_frac.tsv"
    num = 0
    with open(filename, "r") as file:
      for line in file:
        parts = line.strip().split('\t')
        if len(parts) == 3 and parts[0] == sample:
          num = parts[2]
          break
    return float(num)
    
# gets number for norm fraction
def _get_norm_sub_map(wildcards):
    sample = wildcards.sample + "_" + INDEX_MAP
    filename =  PROJ + "/stats/" + PROJ + "_" + INDEX_MAP + "_subsample_frac.tsv"
    num = 0
    with open(filename, "r") as file:
      for line in file:
        parts = line.strip().split('\t')
        if len(parts) == 3 and parts[0] == sample:
          num = parts[2]
          break
    return float(num)
        
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
# sample name the expectation is that all fastqs in the list will have the same suffix
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

# Function to retrieve fastq paths
def _get_fq_paths(wildcards):
    fqs = _get_fqs(wildcards.sample, RAW_DATA, FASTQ_DIR, full_name = True)

    return fqs

# build color sample name dictonary
def _get_colors(sample_key, color):
    if len(sample_key) >= len(color):
      color.extend(["0,0,0"]*len(set(sample_key)))
    res = {}
    for key in sample_key:
      for value in color:
        res[key] = value
        color.remove(value)
        break  
    return(res)

# grab color from dict
def _get_col(wildcards):
    sample = wildcards.newnam
    return COLS_DICT.get(sample, "0,0,0")
        
# build bamCoverage scaleFactor sample dictonary
def _get_norm_scale(sample_key, norm_type, index_sample):
    res = {}
    for key in sample_key:
        if norm_type.lower() in ["subsample", "none", "rpkm", "cpm", "bpm", "rpgc"] or norm_type.isspace():
            res[key] = 1
        else:
            norm_type_with_index = norm_type + "_" + index_sample
            path = PROJ + "/counts/"
            sample = SAMPLES[key][0]
            filename = glob.glob(path + sample + "*_count.txt")
            if filename:
                filename = filename[0]
                with open(filename, "r") as f:
                    for line in f:
                        if norm_type_with_index in line:
                            num = line.strip().split()
                            if float(num[1]) != 0:
                                res[key] = 1000000 / float(num[1])
                            else:
                                res[key] = 1
                            break
                    else:
                        res[key] = "NA"
            else:
                res[key] = "NA"
    return res

# grab normalization options for bamCoverage for each sample
def _get_norm(wildcards):
    NORMS_DICT = _get_norm_scale(NAMS_UNIQ,NORM,INDEX_SAMPLE)
    if NORM in ["RPKM","CPM","BPM","RPGC"]:
      results = "--normalizeUsing " + NORM
    else:
      results = "--normalizeUsing None"
    sample = wildcards.newnam
    if sample in NORMS_DICT:
      value = (NORMS_DICT[sample])
      results = results + " --scaleFactor " + str(value)
    return results
  
# file nameing based on normalization and filter options    
def _get_normtype(normUsing, norm_type, blacklist, orentation):
    word = "_norm_" + norm_type
    
    match = re.search(r"--Offset\s+(-?\d+)", normUsing)
    if match:
      if orentation == "R2R1" or orentation == "R2":
        orent = -1
      else:
        orent = 1
      num = int(match.group(1)) * orent
      if num == -1:
        offset = "_3end"
      elif num == 1:
        offset = "_5end"
      else:
        offset = "_offset_" + str(num)
      word = word + offset
    if re.search(r"\S", blacklist):
      word = word + "_BL"
    return " ".join(word.split())
  
# set orentation for deeptools bamCovrage stranded data
def _get_bamCov_strand(mytype, orentation):
    if orentation == "R2R1" or orentation == "R2":
      return mytype
    elif mytype == "forward":
      return "reverse"
    else:
      return "forward"
    
# set featureCounts options based on orentation and .gtf/.saf ref file
def _get_featCout(filetype, orentation):
  # set options for read orentation
    if orentation == "R2R1" or orentation == "R2":
      results = "-s 2 "
    elif orentation == "R1R2" or orentation == "R1":
      results = "-s 1 "
    else:
      results = "-s 0 "
  # set paired end options
    if orentation != "R2" and orentation != "R1":
      results = results + "-p -C --countReadPairs "
  # Options for SAF or GTF files
    if filetype == "SAF":
      results = results + "-F SAF -g GeneID -O "
    elif filetype == "GTF":
        results = results + "-F GTF --extraAttributes 'gene_name,gene_biotype' -t gene -O "
    return results

# file nameing based on normalization, Matrix options, and genelist   
def _get_matrixtype(normUsing, computeMatrix,genelist):
    if genelist != "":
      genelist = "_" + genelist
    matchu = re.search(r"--upstream (\w+)", computeMatrix)
    if matchu:
      value = int(matchu.group(1))
      result = str(value / 1000) + "k_"
    else:
      result = "0k_"
    matchu5 = re.search(r"--unscaled5prime (\w+)", computeMatrix)
    if matchu5:
      value = int(matchu5.group(1))
      result = result + str(value / 1000) + "k_"
    matchb = re.search(r"--regionBodyLength (\w+)", computeMatrix)
    if matchb:
      value = int(matchb.group(1))
      result = result + str(value / 1000) + "k_"
    matchu3 = re.search(r"--unscaled3prime (\w+)", computeMatrix)
    if matchu3:
      value = int(matchu3.group(1))
      result = result + str(value / 1000) + "k_"
    matchd = re.search(r"--downstream (\w+)", computeMatrix)
    if matchd:
      value = int(matchd.group(1))
      result = result + str(value / 1000) + "k_"
    matchbin = re.search(r"--binSize (\w+)", computeMatrix)
    if matchbin:
      value = matchbin.group(1)
      result = result + value + "bin"
    else:
      result = result + "0bin"
    message = "_" + result + normUsing + genelist
    return message


# controls and sets output if subsample normalzation is set
def _get_bampath(bampath):
    if bampath == "subsample":
        word = "bams_sub"
    else:
        word = "bams"
    return word

## RGB conversion helpers
#
def _rgb2hex(wildcards):
    samples = SAMPLES[wildcards.group2]
    hex_colors = []
    for group in samples:
      if group in COLS_DICT:
        results = COLS_DICT[group]
      else:
        results = "0,0,0"
      myrgb = tuple(map(int, results.split(",")))
      myhex = "#{:02x}{:02x}{:02x}".format(*myrgb)
      hex_colors.append(myhex)
    # Join hex colors with space separator
    hex_colors = hex_colors + hex_colors
    return " ".join(hex_colors)
    
#    
def _rgb2hexplus(wildcards):
    samples = SAMPLES[wildcards.group2]
    hex_colors = []
    hex_colors2 = []
    for group in samples:
      if group in COLS_DICT:
        results = COLS_DICT[group]
      else:
        results = "0,0,0"
      myrgb = tuple(map(int, results.split(",")))
      myhex = "white,#{:02x}{:02x}{:02x}".format(*myrgb)
      myhex2 = "#{:02x}{:02x}{:02x},white".format(*myrgb)
      hex_colors.append(myhex)
      hex_colors2.append(myhex2)
    # Join hex colors with space separator
    hex_colors = hex_colors + hex_colors2
    return " ".join(hex_colors)

#
def _rgb2hexplus2(wildcards):
    samples = SAMPLES[wildcards.group2]
    hex_colors = []
    hex_colors2 = []
    for group in samples:
      if group in COLS_DICT:
        results = COLS_DICT[group]
      else:
        results = "0,0,0"
      myrgb = tuple(map(int, results.split(",")))
      myhex = "white,#{:02x}{:02x}{:02x}".format(*myrgb)
      myhex2 = "#{:02x}{:02x}{:02x},white".format(*myrgb)
      hex_colors.append(myhex)
      hex_colors2.append(myhex2)
    # Join hex colors with space separator
    hex_colors = hex_colors2 + hex_colors
    return " ".join(hex_colors)

#
