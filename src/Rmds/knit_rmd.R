renv::use(
  lockfile = "renv.lock",
  library  = "/opt/conda/envs/find-pauses/lib/R/library"
)

library(rmarkdown)
library(docopt)
library(here)

doc <- "Usage: knit_Rmd.R [-h] [-i INPUT] [-p PROJ] [-c CONFIG] [-g GO_GENOME] [-d GEN_CONFIG] [-o OUT]

-i --input      INPUT      path to rmarkdown
-p --proj       PROJ       name of project, this is used to name output file
-c --config     CONFIG     path to config file
-g --go_genome  GO_GENOME  genome to use for GO analysis
-d --gen_config GEN_CONFIG path to genome specific config file
-o --output     OUTPUT     path to directory to write output file
-h --help                  display this help message"

opts <- docopt(doc)

print(opts)

proj       <- opts$proj
config     <- opts$config
go_genome  <- opts$go_genome
gen_config <- opts$gen_config
res_dir    <- opts$output
ttl        <- paste0("<p style=font-size:45px;>", proj, " NET-seq analysis</p>")

output <- here(res_dir, paste0(proj, "_analysis.html"))

# Render Rmd
render(
  input       = opts$input,
  output_file = output,
  params      = list(
    title      = ttl,
    proj       = proj,
    res_dir    = res_dir,
    config     = config,
    go_genome  = go_genome,
    gen_config = gen_config
  )
)


