
hub_url<-function(repo_id,filename,...,revision="main",repo_type="dataset"){
    base <- mlr3hf_hub_url()
  glue::glue("{base}/{repo_type}s/{repo_id}/resolve/{revision}/{filename}")
}
hub_headers <- function() {
  headers <- c("user-agent" = "mlr3hf/0.0.1")
  token <- mlr3hf_token()
  if (!is.null(token)) {
    headers["authorization"] <- paste0("Bearer ", token)
  }
  headers
}
grab_from_headers <- function(req, nms) {
  headers <- req$all_headers
  for (nm in nms) {
    nm <- tolower(nm)

    for(h in headers) {
      header <- h$headers
      names(header) <- tolower(names(header))

      if (!is.null(header[[nm]]))
        return(header[[nm]])
    }
  }
  NULL
}
normalize_etag <- function(etag) {
  if (is.null(etag)) return(NULL)
  etag <- gsub(pattern = '"', x = etag, replacement = "")
  etag <- gsub(pattern = "W/", x = etag, replacement = "")
  etag
}
get_file_metadata <-function(url) {
  headers <- hub_headers()
  headers["Accept-Encoding"] <- "identity"
  req <- httr::HEAD(
    url,
    httr::config(followlocation = FALSE),
    httr::add_headers(.headers = headers)
  )
  list( #we only use commit_hash and etag for caching, but other fields can be used later for hub_info() or other purposes
    status_code   = req$status_code,
    location      = grab_from_headers(req, "location") %||% req$url,
    commit_hash   = grab_from_headers(req, "x-repo-commit"),
    etag          = normalize_etag(grab_from_headers(req, c("x-linked-etag", "etag"))),
    size          = as.integer(grab_from_headers(req, "content-length")),
    error_code    = grab_from_headers(req, "x-error-code"),
    error_message = grab_from_headers(req, "x-error-message")
  )
}
