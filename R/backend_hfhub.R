#' Read data from Hugging Face Hub and create a data backend
#' @param path Path to the data file (CSV, Parquet, or TSV)
#' @param primary_key Name of the primary key column (default: "mlr3_row_id")
#' @param ... Additional arguments for future use
#' @return A data backend
#' @noRd
backend_hfhub <- function(path, primary_key = NULL, ...) {
    ext <- tolower(tools::file_ext(path))

    data <- switch(
        ext,
        "csv" = utils::read.csv(path, stringsAsFactors = FALSE),
        "parquet" = nanoparquet::read_parquet(path),
        "tsv" = utils::read.csv(path, sep = "\t", stringsAsFactors = FALSE),
        cli::cli_abort("currently not supporting for your given format: {ext}")
    )

    data <- data.table::as.data.table(data)
    if (is.null(primary_key)) {
        primary_key <- "mlr3_row_id"
        data.table::set(data, j = primary_key, value = seq_len(nrow(data)))
    } else {
        if (!primary_key %in% names(data)) {
            cli::cli_abort("Column '{primary_key}' not found in data")
        }
    }

    mlr3::as_data_backend(data, primary_key = primary_key)
}
