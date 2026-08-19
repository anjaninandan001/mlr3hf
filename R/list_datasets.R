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
#' @param fetch_meta (`logical(1)`)\cr
#'   If `TRUE` (default), also fetches `nrows` and `ncols` for each dataset
#'   via `fetch_dataset_meta()`. If `FALSE`, skips this extra network call
#'   and returns only `id`, `gated`, `downloads`.
#' @param max_concurrent (`integer(1)`)\cr
#'   Maximum number of simultaneous connections used when fetching metadata.
#'   Default is `10`.
#' @param ... Additional arguments passed on to `get_with_retry()`, e.g.
#'   `max_retries`.
#'
#' @return (`data.table()`) of results with columns `id`, `nrows`, and
#' `ncols`   or an empty `data.table()` if no datasets are found.
#' @importFrom data.table data.table as.data.table rbindlist
NULL
#' @importFrom checkmate assertInt assertCharacter
#' @importFrom data.table as.data.table
#' @importFrom data.table rbindlist as.data.table
#' @references
#' \url{https://huggingface.co/docs/hub/api}
#'
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
  fetch_meta = TRUE,
  max_concurrent = 10,
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

  out <- rbindlist(all_data)

  if (isTRUE(fetch_meta) && nrow(out) > 0) {
    meta <- fetch_dataset_meta(out$id, max_concurrent = max_concurrent)
    out <- merge(out, meta, by = "id", all.x = TRUE, sort = FALSE)
  }

  out[]
}

#' Fetch nrows/ncols for a vector of dataset ids concurrently via curl's
#' multi-handle pool.
#'
#' A single call to `/size` per dataset is enough. First the `configs[]`
#' array is checked: if the dataset does not have exactly one config,
#' nrows/ncols are both NA. If it does have exactly one config, `nrows` is
#' computed by summing `num_rows` across all of that config's entries in
#' the `splits[]` array (rather than trusting the config-level aggregate
#' directly), and `ncols` is read from `num_columns` on one of those
#' splits (column count doesn't vary across splits of the same config).
#'
#' If a dataset has zero or more than one config, both nrows and ncols are
#' set to NA -- there's no single unambiguous row/column count to report
#' in that case.
#'
#' @param ids Character vector of dataset ids, e.g. "google/dataset-one".
#' @param max_concurrent Integer. Max simultaneous connections in the pool.
#' @param timeout Numeric. Per-request timeout in seconds.
#'
#' @return A data.table with columns: id, nrows, ncols.
fetch_dataset_meta <- function(ids, max_concurrent = 10, timeout = 30) {
  size_env <- new.env(parent = emptyenv())
  pool <- curl::new_pool(total_con = max_concurrent, host_con = max_concurrent)

  make_size_callback <- function(id) {
    force(id)
    list(
      done = function(res) assign(id, res, envir = size_env),
      fail = function(msg) assign(id, NULL, envir = size_env)
    )
  }

  for (id in ids) {
    h <- curl::new_handle(timeout = timeout)
    url <- paste0(
      "https://datasets-server.huggingface.co/size?dataset=",
      utils::URLencode(id, reserved = TRUE)
    )
    cb <- make_size_callback(id)
    curl::curl_fetch_multi(
      url,
      handle = h,
      pool = pool,
      done = cb$done,
      fail = cb$fail
    )
  }
  curl::multi_run(pool = pool)

  rbindlist(
    lapply(ids, function(id) {
      res <- get0(id, envir = size_env)
      if (is.null(res) || res$status_code != 200) {
        return(data.table(id = id, nrows = NA_integer_, ncols = NA_integer_))
      }
      parsed <- tryCatch(
        jsonlite::fromJSON(rawToChar(res$content)),
        error = function(e) NULL
      )
      configs <- parsed$size$configs
      if (is.null(configs) || NROW(configs) != 1) {
        return(data.table(id = id, nrows = NA_integer_, ncols = NA_integer_))
      }

      cfg_name <- configs$config[1]
      splits <- parsed$size$splits
      splits_for_cfg <- if (!is.null(splits)) {
        splits[splits$config == cfg_name, ]
      } else {
        NULL
      }

      if (is.null(splits_for_cfg) || nrow(splits_for_cfg) == 0) {
        return(data.table(id = id, nrows = NA_integer_, ncols = NA_integer_))
      }

      data.table(
        id = id,
        nrows = sum(splits_for_cfg$num_rows, na.rm = TRUE),
        ncols = splits_for_cfg$num_columns[1]
      )
    }),
    fill = TRUE
  )
}
utils::globalVariables(c("id", "gated", "downloads", "."))
