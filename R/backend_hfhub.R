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
        if (!is.integer(data[[primary_key]])) {
            coerced <- suppressWarnings(as.integer(data[[primary_key]]))
            unsafe <- any(coerced != data[[primary_key]], na.rm = TRUE) ||
                any(is.na(data[[primary_key]]) != is.na(coerced))

            if (unsafe) {
                cli::cli_abort(
                    "Primary key column '{primary_key}' (class: {class(data[[primary_key]])[1L]}) cannot be safely coerced to integer (values too large or non-whole). mlr3 requires an integer primary key."
                )
            }
            data.table::set(data, j = primary_key, value = coerced)
        }
    }

    mlr3::as_data_backend(data, primary_key = primary_key)
}
