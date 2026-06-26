#' @title List Datasets from Hugging Face Hub
#'
#' @name list_datasets
#' @rdname list_datasets
#'
#' @description
#' This function allows to query datasets hosted on
#' \url{https://huggingface.co/datasets} via the Hugging Face Hub API,
#' returning metadata such as dataset id, gated status, and download counts.
#'
#' @details
#' This function relies on `num_of_dataset` to control
#' how many records are fetched
#'
#' @param num_of_dataset (`integer(1)`)\cr
#'   Total number of records to retrieve. Must be a positive integer.
#'   Default is `100`.
#' @param chunk_size (`integer(1)`)\cr
#'   Number of records to request per API call (chunk size). Values greater
#'   than 100 are silently capped to 100, since that is the maximum allowed
#'   by the Hugging Face Hub API.
#'   Default is `100`.
#'
#' @return (`data.table()`) of results with columns `id`, `gated`, and
#'   `downloads`, or an empty `data.table()` if no datasets are found.
#'
#' @references
#' \url{https://huggingface.co/docs/hub/api}
#'
#' @importFrom data.table data.table as.data.table rbindlist
NULL
#' @importFrom checkmate assertInt
#'
#' @export
#' @examples
#' \dontrun{
#' dat <- list_datasets(num_of_dataset = 50)
#' dat <- list_datasets(num_of_dataset = 500, chunk_size = 100)
#' }
list_datasets <- function(num_of_dataset = 100, chunk_size = 100) {
    assertInt(num_of_dataset, lower = 1)
    assertInt(chunk_size, lower = 1)
    base_url <- mlr3hf_parquet_url()
    offset <- 0
    all_data <- list()

    repeat {
        remaining <- num_of_dataset - offset
        current_limit <- min(chunk_size, remaining)

        url <- glue::glue("{base_url}?limit={current_limit}&offset={offset}")

        result <- httr::GET(url)
        if (result$status_code != 200) {
            stop("Failed to retrieve data: ", result$status_code, call. = FALSE)
        }

        content <- httr::content(result, as = "text", encoding = "UTF-8")
        data <- jsonlite::fromJSON(content)
        dt <- as.data.table(data)

        if (nrow(dt) == 0) {
            break
        }

        dat <- dt[, list(id, gated, downloads)]
        all_data[[length(all_data) + 1]] <- dat

        offset <- offset + nrow(dt)

        if (offset >= num_of_dataset) {
            break
        }
    }

    rbindlist(all_data)
}
