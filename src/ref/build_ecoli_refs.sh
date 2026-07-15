#!/usr/bin/env bash
#
# build_ecoli_refs.sh
# -------------------
# Derive the find-pauses reference bed tree for E. coli K-12 MG1655 (RefSeq
# ASM584v2, GCF_000005845.2, contig NC_000913.3) from the RefSeq GTF.
#
# Reproduces the human/mouse bed conventions expected by the pipeline:
#   * all beds are bed6, contig kept as-is (NC_000913.3, NO "chr" prefix -
#     the E. coli genome config sets ADD_CHR_PREFIX: False)
#   * the name field is the gene key shared across every region/window bed:
#         {chrom}:{gene_start}-{gene_end}{strand};{gene_id}|{gene_name}
#     e.g.  NC_000913.3:189-255+;b0001|thrL
#   * window beds carry a 1-based, strand-aware window id in column 5
#     (win 1 = 5'-most in the direction of transcription)
#   * separation lists are `bedtools closest -d` output pre-filtered by distance
#
# Requires: bedtools, gawk, bgzip (htslib), sort.  Run on the cluster.
#
# Usage:
#   build_ecoli_refs.sh <gtf> <fasta_fai> <out_dir>
#   e.g. (run from the project root after cloning to the cluster)
#   bash src/ref/build_ecoli_refs.sh \
#     /beevol/home/erickson/ref/misc/e_coli/GCF_000005845.2_ASM584v2_genomic.gtf \
#     /beevol/home/erickson/ref/misc/e_coli/GCF_000005845.2_ASM584v2_genomic.fna.fai \
#     /beevol/home/sheridanr/Projects/ecoli-net/ref/gene_lists/Ecoli
#
# The <out_dir> must match the gene-list paths in src/configs/Ecoli.yaml.
#
set -o nounset -o pipefail -o errexit

GTF="${1:?usage: build_ecoli_refs.sh <gtf> <fasta_fai> <out_dir>}"
FAI="${2:?need fasta .fai}"
OUT="${3:?need output dir}"

# ------------------------------------------------------------------ geometry --
# All distances in bp. Tune here; keep in sync with the Ecoli.yaml meta_wins /
# pause_regions block and the report's window parameters.
TSS_WIN=300     # 5' metaplot half-width around the TSS   (-> "5-10bp" key)
TSS_BIN=10      # 5' metaplot bin size
TES_WIN=500     # 3' metaplot half-width around gene end   (-> "3-50bp" key)
TES_BIN=50      # 3' metaplot bin size
BODY_BIN=200    # gene-body bin size                       (-> "*_200bp")
TSS_PROX=100    # promoter-proximal region: TSS .. +TSS_PROX ; body = +TSS_PROX .. end
SEP=100         # min neighbour separation for the "isolated gene" list
FLANK=100       # read-retention flank around the gene body (GENES filter)

# ------------------------------------------------------------------- outputs --
mkdir -p "$OUT"/base_lists "$OUT"/gene_regions "$OUT"/gene_windows "$OUT"/masks

# clean 2-column genome file for bedtools -g (contig <tab> length)
GENOME="$OUT/Ecoli.genome"
cut -f1,2 "$FAI" > "$GENOME"

log() { echo ">> $*" >&2; }

# ============================================================== base gene bed ==
# protein-coding genes only -> bed6 with the shared gene-key name
BASE="$OUT/base_lists/Ecoli_TSS_end.bed"
log "base gene list (protein_coding)"
gawk -F'\t' 'BEGIN{OFS="\t"}
  $3=="gene" && $9 ~ /gene_biotype "protein_coding"/ {
    match($9, /gene_id "([^"]+)"/, gi)
    sym = gi[1]
    if (match($9, /[[:space:]]gene "([^"]+)"/, gn)) sym = gn[1]
    s = $4 - 1; e = $5; st = $7
    name = $1 ":" s "-" e st ";" gi[1] "|" sym
    print $1, s, e, name, ".", st
  }' "$GTF" \
  | sort -k1,1 -k2,2n > "$BASE"
log "  $(wc -l < "$BASE") genes"

# ================================================== strand-aware region helper ==
# emit a sub-region of each gene, clamped to the gene bounds.
#   $1 mode: tss_prox | body | whole
region_from_base() {
  local mode="$1"
  gawk -F'\t' -v OFS='\t' -v mode="$mode" -v prox="$TSS_PROX" '
    {
      chrom=$1; s=$2; e=$3; name=$4; st=$6
      if (mode=="whole") { os=s; oe=e }
      else if (st=="+") {
        if (mode=="tss_prox") { os=s;        oe=(s+prox<e?s+prox:e) }
        else                  { os=(s+prox<e?s+prox:e); oe=e }        # body
      } else {
        if (mode=="tss_prox") { os=(e-prox>s?e-prox:s); oe=e }
        else                  { os=s; oe=(e-prox>s?e-prox:s) }        # body
      }
      if (oe>os) print chrom, os, oe, name, $5, st
    }' "$BASE"
}

log "gene regions (TSS .. +${TSS_PROX} ; +${TSS_PROX} .. end)"
region_from_base tss_prox | sort -k1,1 -k2,2n > "$OUT/gene_regions/Ecoli_TSS_+${TSS_PROX}bp.bed"
region_from_base body     | sort -k1,1 -k2,2n > "$OUT/gene_regions/Ecoli_+${TSS_PROX}bp_end.bed"
region_from_base whole    | sort -k1,1 -k2,2n > "$OUT/gene_regions/Ecoli_TSS_end.bed"

# ================================================ strand-aware window helper ====
# make_windows <anchor: tss|tes> <halfwidth> <bin> <outfile>
# builds [anchor-halfwidth, anchor+halfwidth] per gene, bins it, and numbers the
# bins 1..N in the direction of transcription (win 1 = 5'-most).
make_windows() {
  local anchor="$1" half="$2" bin="$3" outfile="$4"

  # per-gene window region around the anchor, clamped to the chromosome
  gawk -F'\t' -v OFS='\t' -v anchor="$anchor" -v half="$half" '
    { chrom=$1; s=$2; e=$3; name=$4; st=$6
      if (anchor=="tss") a = (st=="+"? s : e)
      else               a = (st=="+"? e : s)   # tes = gene three-prime end
      os = a-half; if (os<0) os=0
      oe = a+half
      print chrom, os, oe, name, $5, st
    }' "$BASE" \
    | sort -k1,1 -k2,2n \
    | bedtools makewindows -b - -w "$bin" -i src \
    | sort -k4,4 -k1,1 -k2,2n \
    | gawk -F'\t' -v OFS='\t' '
        # windows arrive grouped by gene (name), ascending coord.
        # strand is the char just before ";" in the name key. Use the buffered
        # gene strand (cur_strand), captured when the group starts, so flushing
        # the previous gene never picks up the strand of the next gene.
        function flush(   i, id) {
          for (i=1; i<=cnt; i++) {
            id = (cur_strand=="-" ? cnt - i + 1 : i)
            print c[i], s[i], e[i], cur, id, cur_strand
          }
        }
        {
          name=$4
          split(name, p, ";"); coord=p[1]; st=substr(coord, length(coord), 1)
          if (name != cur) { if (cnt>0) flush(); cur=name; cur_strand=st; cnt=0 }
          cnt++; c[cnt]=$1; s[cnt]=$2; e[cnt]=$3
        }
        END { if (cnt>0) flush() }' \
    | sort -k1,1 -k2,2n > "$outfile"
}

log "5' TSS windows  (+/-${TSS_WIN}, ${TSS_BIN}bp)  -> 5-10bp key"
make_windows tss "$TSS_WIN" "$TSS_BIN" "$OUT/gene_windows/Ecoli_5_-${TSS_WIN}_+${TSS_WIN}_${TSS_BIN}bp.bed"

log "3' end windows  (+/-${TES_WIN}, ${TES_BIN}bp)  -> 3-50bp key"
make_windows tes "$TES_WIN" "$TES_BIN" "$OUT/gene_windows/Ecoli_3_-${TES_WIN}_+${TES_WIN}_${TES_BIN}bp.bed"

log "gene-body windows (${BODY_BIN}bp)  -> *_200bp key"
# whole-gene body binned, strand-aware numbering via the same helper logic
gawk -F'\t' -v OFS='\t' '{print $1,$2,$3,$4,$5,$6}' "$BASE" \
  | sort -k1,1 -k2,2n \
  | bedtools makewindows -b - -w "$BODY_BIN" -i src \
  | sort -k4,4 -k1,1 -k2,2n \
  | gawk -F'\t' -v OFS='\t' '
      function flush(   i,id){for(i=1;i<=cnt;i++){id=(cur_strand=="-"?cnt-i+1:i);print c[i],s[i],e[i],cur,id,cur_strand}}
      { name=$4; split(name,p,";"); coord=p[1]; st=substr(coord,length(coord),1)
        if(name!=cur){if(cnt>0)flush();cur=name;cur_strand=st;cnt=0} cnt++;c[cnt]=$1;s[cnt]=$2;e[cnt]=$3 }
      END{if(cnt>0)flush()}' \
  | sort -k1,1 -k2,2n > "$OUT/gene_windows/Ecoli_TSS_end_${BODY_BIN}bp.bed"

# ================================================= separation / test lists ======
log "isolated-gene list (>= ${SEP}bp from nearest neighbour)"
bedtools closest -a "$BASE" -b "$BASE" -io -d -t first -g "$GENOME" \
  | gawk -F'\t' -v OFS='\t' -v sep="$SEP" '$NF>=sep' \
  > "$OUT/base_lists/Ecoli_${SEP}bpsep.bed"
log "  $(wc -l < "$OUT/base_lists/Ecoli_${SEP}bpsep.bed") isolated genes"

log "non-overlapping gene list (TEST_GENES)"
bedtools intersect -a "$BASE" -b "$BASE" -c \
  | gawk -F'\t' -v OFS='\t' '$NF==1{NF--; print}' \
  > "$OUT/base_lists/Ecoli_0ksep.bed"

# ============================================================ read-retention ====
log "GENES read-retention regions (gene body +/-${FLANK}bp, merged)"
bedtools slop -b "$FLANK" -g "$GENOME" -i "$BASE" \
  | sort -k1,1 -k2,2n \
  | bedtools merge -i - \
  > "$OUT/base_lists/Ecoli_genes_+-${FLANK}bp.bed"

# ==================================================================== masks =====
log "rRNA + tRNA mask"
gawk -F'\t' -v OFS='\t' '
  $3=="gene" && $9 ~ /gene_biotype "(rRNA|tRNA)"/ {
    match($9, /gene_id "([^"]+)"/, gi)
    print $1, $4-1, $5, gi[1], ".", $7
  }' "$GTF" \
  | sort -k1,1 -k2,2n > "$OUT/masks/Ecoli_rRNA_tRNA.bed"

# empty (valid) mask, in case a no-op mask is ever needed
: | bgzip > "$OUT/masks/Ecoli_empty.bed.gz"

# ================================================================ compress ======
log "bgzip all beds"
find "$OUT" -name '*.bed' -print0 | xargs -0 -I{} bash -c 'bgzip -f "{}"'

log "done. tree under: $OUT"
