renv::use(
  lockfile = "renv.lock",
  library = "/opt/conda/envs/find-pauses/lib/R/library"
)

library(rmarkdown)
library(docopt)
library(here)

doc <- "Usage: knit_Rmd.R [--help] [--input INPUT] [--proj PROJ] [--genome GENOME] [--output OUT]

-i --input INPUT    path to rmarkdown
-p --proj PROJ      name of project, this is used to name output file
-g --genome GENOME  path to genome specific config file
-o --output OUTPUT  path to directory to write output file
-h --help           display this help message"

opts <- docopt(doc)

print(opts)

proj    <- opts$proj
genome  <- opts$genome
res_dir <- opts$output
ttl     <- paste0("<p style=font-size:45px;>", proj, " NET-seq analysis</p>")

output <- here(res_dir, paste0(proj, "_analysis.html"))

# Render Rmd
render(
  input       = opts$input,
  output_file = output,
  params      = list(title = ttl, genome = genome)
)

