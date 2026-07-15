#' Read nanoparquet files and create a data backend
#'
#' @param path Path to the nanoparquet file or a named list of paths (for multiple splits)
#' @param primary_key Name of the primary key column (default: "mlr3_row_id")
#' @param ... Additional arguments for future use
#' @return A list containing:
#'   \item{backend}{A [mlr3::DataBackend] object}
#'   \item{splits}{A named list of primary keys per split e.g. list(train = c(1,2,3), test = c(4,5,6))}
#' @noRd
nano_parquet <- function(path, primary_key = NULL, ...) {
    dt <- lapply(path, nanoparquet::read_parquet)

    combined <- data.table::rbindlist(
        dt,
        use.names = TRUE,
        fill = TRUE,
        idcol = "..split_tmp"
    )

    if (is.null(primary_key)) {
        primary_key <- "mlr3_row_id"
        data.table::set(
            combined,
            j = primary_key,
            value = seq_len(nrow(combined))
        )
    } else {
        if (!primary_key %in% names(combined)) {
            cli::cli_abort("Column '{primary_key}' not found in data")
        }
    }

    splits <- split(combined[[primary_key]], combined[["..split_tmp"]])
    data.table::set(combined, j = "..split_tmp", value = NULL)

    backend <- mlr3::as_data_backend(data = combined, primary_key = primary_key)

    list(backend = backend, splits = splits)
}
