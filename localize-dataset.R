source("config.R")

globalVariables(c("NAPS_dataset_path"))

if (startsWith(NAPS_dataset_path, "http://") ||
    startsWith(NAPS_dataset_path, "https://")) {
    
    cat("Dataset path seems to be a compatible remote resource\n")
    cat("Downloading\n")
    
    url <- NAPS_dataset_path
    new_dataset_path <- paste0("data/", basename(NAPS_dataset_path))
    
    download.file(url, new_dataset_path)
    
    cat("Done\n")
    
    cat("Writing the new dataset path to config.R\n")
    cat(paste(
        "",
        "",
        "# ===========================",
        "# ADDED BY localize-dataset.R",
        paste0("NAPS_dataset_path <- '", new_dataset_path, "'"),
        "# ===========================",
        "",
        sep = "\n"
        ), file = "config.R", append = TRUE)
    
    cat("Done\n")
} else {
    cat("Dataset path does not seem to be a compatible remote resource\n")
    cat("Exiting\n")
}
