download_hfhub <- function(repo_id, file_name, revision = "main", ..., 
                           destfile,
                           retries = mlr3hf_retries()) {  

  url <- hub_url(repo_id, file_name, revision = revision)

  for (retry in seq_len(retries)) {

  result <- tryCatch(
    httr::GET(
      url,
      httr::add_headers(.headers = hub_headers()),
      httr::write_disk(destfile, overwrite = TRUE)
    ),
    error = function(e) e
  )
  if(httr::status_code(result) != 200) {
    stop("Failed to download file")
  }

  if (!inherits(result, "error") &&
      !httr::http_error(result)) {
    return(destfile)
  }

  if (retry == retries) {
    cli::cli_abort("Download failed after {retries} attempts")
  }

  Sys.sleep(2 ^ retry)
}
}