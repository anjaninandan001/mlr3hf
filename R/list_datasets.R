#' @title List Datasets from Hugging Face Hub
#'
#' @name list_datasets
#' @rdname list_datasets
#'
#' @description
#' Query datasets hosted on \url{https://huggingface.co/datasets} via the
#' Hugging Face Hub API, returning metadata such as dataset id, gated
#' status, and download counts.
#'
#' @param num_of_dataset (`integer(1)`)\cr
#'   Total number of records to retrieve. Must be a positive integer.
#'   Default is `100`.
#' @param chunk_size (`integer(1)`)\cr
#'   Number of records to request per API call.
#'   Default is `100`.
#' @param search (`character(1)`)\cr
#'   Optional search keyword to filter datasets by. Default is `NULL`.
#' @param author (`character(1)`)\cr
#'   Optional author/organization name to filter datasets by.
#'   Default is `NULL`.
#' @param ... Additional arguments passed on to `get_with_retry()`, e.g.
#'   `max_retries`.
#'
#' @return (`data.table()`) of results with columns `id`, `gated`, and
#'   `downloads`, or an empty `data.table()` if no datasets are found.
#'
#' @references
#' \url{https://huggingface.co/docs/hub/api}
#'
#' #' @importFrom data.table data.table as.data.table rbindlist
NULL
#' @importFrom checkmate assertInt assertCharacter
#' @importFrom data.table as.data.table
#' @importFrom data.table rbindlist as.data.table
#' @export
#' @examples
#' \dontrun{
#' dat <- list_datasets(num_of_dataset = 50)
#' dat <- list_datasets(num_of_dataset = 500, chunk_size = 100)
#' dat <- list_datasets(author = "a4n9i")
#' }
list_datasets <- function(
  num_of_dataset = 100,
  chunk_size = 100,
  search = NULL,
  author = NULL,
  ...
) {
    assertInt(num_of_dataset, lower = 1)
    assertInt(chunk_size, lower = 1)
    assertCharacter(search, null.ok = TRUE)
    assertCharacter(author, null.ok = TRUE)

  base_url <- mlr3hf_parquet_url()
  fetched <- 0
  all_data <- list()

  next_url <- base_url
  query <- list(limit = min(chunk_size, num_of_dataset))
  if (!is.null(search)) {
    query$search <- search
  }
  if (!is.null(author)) {
    query$author <- author
  }

  repeat {
    if (identical(next_url, base_url)) {
      result <- get_with_retry(base_url, query = query, ...)
    } else {
      result <- get_with_retry(next_url, ...)
    }
    if (httr::status_code(result) != 200) {
      stop(
        "Failed to retrieve data: ",
        httr::status_code(result),
        call. = FALSE
      )
    }

    content <- httr::content(result, as = "text", encoding = "UTF-8")
    data <- jsonlite::fromJSON(content)
    dt <- as.data.table(data)

    if (nrow(dt) == 0) {
      break
    }

    dat <- dt[, .(id, gated, downloads)]
    all_data[[length(all_data) + 1]] <- dat
    fetched <- fetched + nrow(dt)

    if (fetched >= num_of_dataset) {
      break
    }

    link_header <- httr::headers(result)$link

    if (is.null(link_header)) {
      break
    }

    next_match <- regmatches(
      link_header,
      regexpr('(?<=<)[^>]+(?=>;\\s*rel="next")', link_header, perl = TRUE)
    )

    if (length(next_match) == 0) {
      break
    }

    next_url <- next_match
  }

  rbindlist(all_data)
}
utils::globalVariables(c("id", "gated", "downloads","."))