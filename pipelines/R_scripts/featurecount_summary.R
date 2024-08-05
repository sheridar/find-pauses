#!/usr/bin/env Rscript

library("tidyverse")

samp <- list()
for(i in seq_along(snakemake@input)) {
  
  sub_reads <- read_tsv(snakemake@input[[i]],comment = "#",show_col_types = FALSE) %>% 
    dplyr::select(-Chr,-Start,-End,-Strand,-Length) %>% 
    dplyr::rename(count=names(.)[2])
  index <- sub_reads %>% dplyr::select(Geneid) %>% mutate(Geneid=stringr::str_extract(.$Geneid,"(?<=_)\\w+$")) %>%
    distinct()
    paste(collapse = "_")
  samp[[i]] <- read_tsv(paste0(snakemake@input[[i]],".summary"),comment = "#",show_col_types = FALSE) %>% 
    dplyr::rename(count=names(.)[2]) %>% summarise(count=sum(count)) %>% bind_cols(index,.) %>% 
    bind_rows(.,sub_reads)
  
}

out <- bind_rows(samp)

write_delim(out, snakemake@output[[1]],col_names = F,delim = " ")
