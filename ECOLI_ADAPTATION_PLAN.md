# E. coli adaptation plan — `find-pauses`

Branch: `ecoli-support`.

## Status (2026-07-14) — code complete, pending cluster validation

All repo changes done and locally validated (YAML parses; funs.R + setup.Rmd +
analysis-template.Rmd R parses; meta_geo resolver tested for human + E. coli;
build script ran on the cluster and output formats verified). **Multi-genome
preserved** — every change is backward-compatible via config defaults, so
human/mouse behaviour is unchanged.

Remaining before a full run (on the cluster, in the new `ecoli-net` repo):
1. Run `src/ref/build_ecoli_refs.sh` to `<project>/ref/gene_lists/Ecoli`.
2. Point `SAMPLES.yaml` at the E. coli fastqs (`GENOME: Ecoli`) + confirm
   adapters / UMI / strand chemistry match the libraries.
3. `./run.sh -d` dry-run, then a test render.


## Context

The `find-pauses` pipeline (Snakemake + R/Rmd) was written for human/mouse mNET-seq.
Ben Erickson has generated mNET-seq data in **E. coli K-12 MG1655**, which is prokaryotic:
no introns/exons/splice sites, no snoRNAs, no polyadenylation. We are adding first-class
E. coli support on this branch so the same pipeline can process the bacterial data, with the
splicing analysis removed and the eukaryote-specific gene anatomy re-anchored.

## Confirmed reference (inspected on cluster)

Files live at `sheridanr@10.129.32.156:/beevol/home/erickson/ref/misc/e_coli`.

- **Assembly: E. coli K-12 MG1655, RefSeq ASM584v2 (`GCF_000005845.2`).**
- Contig **`NC_000913.3`**, length **4,641,652 bp**, single circular chromosome, no plasmid.
- Annotation: NCBI RefSeq GTF/GFF (`GCF_000005845.2_ASM584v2_genomic.gtf/.gff`).
  - Feature types present: `gene` (4651), `CDS`, `transcript`, `exon`. `-t gene` featureCounts works.
  - `gene_biotype`: protein_coding 4290, pseudogene 145, ncRNA 107, **tRNA 86, rRNA 22**, other 1.
- **Already built by Ben** (use the `ecoli`-prefixed / ASM584v2 set, NOT the older `e_coli_k12.v2` = U00096.2):
  - bowtie2 index `ecoli.*.bt2` (from ASM584v2 FASTA)
  - `ecoli_chrom.size`, `GCF_...fna` + `.fai` (contig `NC_000913.3`)
  - gene-level beds `all_genes.bed`, `ecoli.genes.bed` (bed6, name = gene symbol)
  - `readme.txt` / `build.sh` document the download + index build.

### Decisions (Ryan, 2026-07-14)
1. **Gene filters** — relax neighbor-separation, keep TSS/body/3′ structure.
2. **3′ anatomy** — re-anchor 3′ half from pAS to annotated **gene 3′ end**.
3. **Masking** — build **rRNA + tRNA** masks (replace snoRNA/splice masks).
4. **Splicing** — remove entirely.

## The `chr`-prefix decision (resolved)

`03_dedup.snake:87–90` (rule `beds`) prepends `chr` to any contig not already starting with
`chr`. Ben's index, `.fai`, `chrom.size`, and beds all use bare `NC_000913.3`. Rather than rename
everything, add a genome-config flag **`ADD_CHR_PREFIX`** (default `True` → human/mouse unchanged;
`False` for E. coli). With it off, reads stay `NC_000913.3` and match Ben's existing files. This is
the single highest-risk item — a mismatch silently yields zero overlaps at every `bedtools intersect`.

## Reference bed formats (inspected — the build script must reproduce these)

All beds are **bed6**; the **name field is the gene key shared across every region/window bed**:
`{chrom}:{gene_start}-{gene_end}{strand};{gene_id}|{gene_name}` (e.g. `NC_000913.3:189-255+;b0001|thrL`).

| File (GRCh38 name) | Meaning | Format notes |
|---|---|---|
| `4_TSS_pAS` (base) | full gene TSS→3′end | bed6, name=gene key |
| `5_TSS_+500bp` | TSS→+500 (strand-aware) | bed6 |
| `4_+500bp_pAS` → **`4_+500bp_end`** | +500→3′end | bed6 (re-anchor to gene end) |
| `5_TSS_+100bp`, `+100_+300`, `+300_+500`, `+500_+1kb` | TSS sub-windows | bed6 |
| `4_TSS_pAS_200bp` | body in 200bp bins | bed6, **col5 = 1-based win_id** |
| `5_-2kb_+2kb_10bp` | ±2kb of TSS, 10bp bins | bed6, col5=win_id (strand-aware numbering) |
| `3_-5kb_+5kb_50bp` | ±5kb of **3′end**, 50bp bins | bed6, col5=win_id |
| `Nksep` | genes ≥N bp from nearest neighbor | 13 cols = `bedtools closest -d` output, pre-filtered by col13 ≥ threshold |
| `TSS_+5kb` (pause genes) | TSS→+5kb, capped at gene end | bed6 |

Window numbering is strand-aware (win 1 = 5′-most in the transcription direction); the R loaders
(`load_merge_wins`/`merge_wins` in funs.R) convert `win_id`→`win_dist` via a `ref_win`.

## Path layout (finalized)

New repo `ecoli-net` (templated from find-pauses) cloned to the cluster at
`/beevol/home/sheridanr/Projects/ecoli-net`.
- **Shared genome dir** (Ben's, ASM584v2): `/beevol/home/erickson/ref/misc/e_coli`
  → `INDEX`, `CHROMS`(.fai), `GTF`, `fasta`.
- **Generated gene lists** (in-project): `<project>/ref/gene_lists/Ecoli`
  → all region/window/base/mask beds, built by `build_ecoli_refs.sh`.
- Plotting `ref_dir` = project, `list_dir` = `ref/gene_lists/Ecoli`; `chrom_sizes`/`fasta`
  are absolute paths to the shared genome dir (setup.Rmd now uses absolute ref paths as-is).

## Phase 1 — Build E. coli reference tree (`src/ref/build_ecoli_refs.sh`, run once on cluster)

Derive a `gene_lists/Ecoli/` tree from the ASM584v2 GTF + `ecoli_chrom.size`, reproducing the
formats above, with contig `NC_000913.3` (no `chr`). Output groups:
- **base_lists**: `Ecoli_TSS_end` (all genes), `Ecoli_Nksep` (relaxed threshold — see open items),
  `Ecoli_0ksep` (TEST_GENES, non-overlapping).
- **gene_regions**: `TSS_+500bp`, `+500bp_end`, TSS sub-windows, `TSS_+5kb` (pause genes).
- **gene_windows**: `-2kb_+2kb_10bp` (TSS), `-5kb_+5kb_50bp` (3′end), `TSS_end_200bp`.
- **masks**: `Ecoli_rRNA_tRNA.bed.gz` (biotype rRNA+tRNA) for `MASK` and `PAUSE_MASK`; an empty
  bgzipped bed for any mask we want to no-op.
- Restrict to protein_coding genes for the metaplot/base lists (exclude rRNA/tRNA/ncRNA/pseudogene).

Modeled on Ben's `readme.txt` awk + `bedtools makewindows`/`closest`/`flank`. Protein-coding gene
name key built from GTF `gene_id`(locus tag `b####`) + `gene` symbol.

## Phase 2 — `src/configs/Ecoli.yaml`

Copy `GRCh38.yaml`, repoint to the `Ecoli` tree + Ben's index/chrom/GTF, and:
- Add `ADD_CHR_PREFIX: False`.
- Drop `META_BEDS`/`PAUSE_META_BEDS` entries `5ss-wins`, `exons`, `introns`; drop `exons`,`trxn_info`.
- `PAUSE_MASK`: `[Ecoli_rRNA_tRNA.bed.gz]` (must stay a YAML list); `MASK`: same.
- `pause_regions`: keep `TSS`/`body`; rename `pAS`→`end` (TSS→+500 / +500→end).
- Plotting block: `list_dir: gene_lists/Ecoli`, `genes_all/5/3/zone/pause` → relaxed sep lists,
  `chrom_sizes`/`fasta` → ASM584v2.
- Set `GENOME: "Ecoli"` in `SAMPLES.yaml`; add `Ecoli: "escherichia_coli"` to `go_genomes` in `plots.yaml`.

## Phase 3 — Repo code changes

**3a. chr-prefix flag** — `net.snake`: `ADD_CHR_PREFIX = config.get("ADD_CHR_PREFIX", True)`; pass to
`beds` rule param; gate the awk block in `03_dedup.snake:87–90`.

**3b. Remove splicing (delete):**
- `src/Rmds/exon-pausing-template.Rmd` (orphaned file).
- `analysis.Rmd`: `"load exons"` (~69–124), `"1st exon length"` (~126–179) + `high_conf_txns`/`ex_int_txns` uses.
- `analysis-template.Rmd`: `"ss functions"`, `"meta exons…"`, `"ss data…"`, `"ss metaplot…"` (~487–675) + prose ~480–485.
- `pause-quant-template.Rmd`: `### Exon intron pausing` section (~872–1030) + `get_ex_int_genes`/`sum_ex_int_counts`/`plot_ex_int_pauses` (~415–560).
- `pause-zone-template.Rmd`: `"exon length corr"` (already `eval=FALSE`).
- `qc-template.Rmd`: prune `snoRNA/snRNA/miRNA` from `"featurecounts"` biotype list; update MASK prose (rRNA/tRNA).

**3c. Re-anchor 3′ labels:** `analysis-template.Rmd` pAS axis break (~455) + prose; `pause-quant-template.Rmd` "+500bp–pAS"→"+500bp–3′end"; `funs.R` `add_breaks(...,"pAS")` (~957).

**3d. Relax thresholds:** `setup.Rmd` `MIN_GENE_LEN` (2 kb) / `MIN_ZONE_GENE_LEN` (4 kb) → E. coli values (open item).

**3e. GO:** `pause-zone-template.Rmd` — point `go_genome` at E. coli gProfiler id or gate GO off; locus-tag name handling.

## Phase 4 — Verify
- `./run.sh -d` dry-run: config parses, all bed paths resolve, DAG has no splicing targets.
- Small real run on one sample group; confirm non-zero reads survive `GENES`/`MASK`, featureCounts
  assigns to `gene`, bigwig strands sane, pauses called, `results/<PROJ>_analysis.html` renders with no
  splicing sections and 3′ panels labeled to gene end. Check non-zero intersects at each bedtools step
  (guards the `chr`-prefix decision).

## Open items (need a number / confirmation)
- **Separation threshold** for `Nksep` + **`GENES` flank**: quantify surviving genes at 100/200/500 bp before locking.
- **`MIN_GENE_LEN` / `MIN_ZONE_GENE_LEN`** values (E. coli ORF median ~1 kb).
- **Library strand chemistry**: confirm E. coli libraries are "read #1 = sense" (bigwig step hard-codes this, `06_bigwigs.snake:5`).
- **gProfiler organism id** for E. coli (or drop GO).
- Whether to keep the older U00096.2 files around (recommend: ignore; use ASM584v2 only).
</content>
</invoke>
