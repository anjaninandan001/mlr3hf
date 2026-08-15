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
        id_col <- combined[[primary_key]]

        if (!is.integer(id_col)) {
            coerced <- suppressWarnings(as.integer(id_col))
            unsafe <- any(coerced != id_col, na.rm = TRUE) ||
                any(is.na(id_col) != is.na(coerced))

            if (unsafe) {
                stop(sprintf(
                    "Primary key column '%s' (class: %s) cannot be safely coerced to integer (values too large or non-whole). mlr3 requires an integer primary key.",
                    primary_key,
                    class(id_col)[1L]
                ))
            }

            data.table::set(combined, j = primary_key, value = coerced)
        }
    }

    splits <- split(combined[[primary_key]], combined[["..split_tmp"]])
    data.table::set(combined, j = "..split_tmp", value = NULL)

    backend <- mlr3::as_data_backend(data = combined, primary_key = primary_key)

    list(backend = backend, splits = splits)
}
