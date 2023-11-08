

# https://github.com/sheridar/find-pauses

rsync -artuv /beevol/home/erickson/dockertest/findpauses/* .

##### edited the run.sh file so that it points to home directory like this.

--singularity-args '--bind /beevol/home' \
--use-singularity \

### add this to pause.snake 

SINGULARITY     = config["SINGULARITY"]

if SINGULARITY != "" or SINGULARITY is not None:
  container: SINGULARITY

# add this to PLOTS.yaml

SINGULARITY:
 "/beevol/home/erickson/dockerfiles/RyanFindPauses.sif"

# add this to SAMPLES.yaml

SINGULARITY:
  ""

# There is also a small edit to 08_find_pauses.snake, there is a wildcard that needs to be escaped at line 284

from: awk -v FS="*_" -v OFS="\t" -v strand=$strand '{{print $1, $2, strand}}'

to: awk -v FS="\\*_" -v OFS="\t" -v strand=$strand '{{print $1, $2, strand}}'