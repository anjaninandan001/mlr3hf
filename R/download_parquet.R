download_parquet <- function(repo_id, config, ..., file_dir) {
  server <- mlr3hf_parquet_url()
  url <- sprintf("%s/%s/parquet", server, repo_id)

  result <- httr::GET(
    url,
    httr::add_headers(.headers = hub_headers())
  )
  if (httr::status_code(result) != 200) {
    stop("Failed to fetch parquet metadata")
  }

  desc <- jsonlite::fromJSON(
    httr::content(result, "text", encoding = "UTF-8"),
    simplifyVector = FALSE
  )

  if (!config %in% names(desc)) {
    stop("Config not found: ", config)
  }

  cfg <- desc[[config]]

  downloaded <- c()

  for (split in names(cfg)) {
    urls <- cfg[[split]]

    split_dir <- fs::path(file_dir, split)
    if (!fs::dir_exists(split_dir)) {
      fs::dir_create(split_dir)
    }

    for (u in urls) {
      dest <- fs::path(split_dir, basename(u))

      downloaded <- c(
        downloaded,
        get_parquet(u, file = dest)
      )
    }
  }

  return(downloaded)
}


get_parquet <- function(url, retries = mlr3hf_retries(), file = NULL) {
  for (retry in seq_len(retries)) {
    result <- tryCatch(
      {
        httr::GET(
          url,
          httr::add_headers(.headers = hub_headers()),
          httr::write_disk(file, overwrite = TRUE)
        )
      },
      error = function(e) e
    )

    if (!inherits(result, "error") && !httr::http_error(result)) {
      return(file)
    }
    if (retry == retries) {
      cli::cli_abort("Download failed after {retries} attempts: {url}")
    }
    Sys.sleep(2^retry)
  }
}
