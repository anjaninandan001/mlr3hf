utils::globalVariables("tmp")

#' it is used to create url so that dataset can be downloaded in the local
#' @noRd
hub_url <- function(
  repo_id,
  filename,
  ...,
  revision = "main",
  repo_type = "dataset"
) {
  base <- mlr3hf_hub_url()
  glue::glue("{base}/{repo_type}s/{repo_id}/resolve/{revision}/{filename}")
}
#' In hugginface some dataset are private some are gated for all this function authorize the user to use the dataset
#' @noRd
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

    for (h in headers) {
      header <- h$headers
      names(header) <- tolower(names(header))

      if (!is.null(header[[nm]])) {
        return(header[[nm]])
      }
    }
  }
  NULL
}

#' @noRd
normalize_etag <- function(etag) {
  if (is.null(etag)) {
    return(NULL)
  }
  etag <- gsub(pattern = '"', x = etag, replacement = "")
  etag <- gsub(pattern = "W/", x = etag, replacement = "")
  etag
}

repo_folder_name_cache <- new.env(hash = TRUE, parent = emptyenv())

#' @noRd
repo_folder_name <- function(repo_id) {
  if (exists(repo_id, envir = repo_folder_name_cache, inherits = FALSE)) {
    return(get(repo_id, envir = repo_folder_name_cache, inherits = FALSE))
  }
  result <- gsub("[/:]", "--", repo_id)
  result <- paste0("datasets--", result)
  assign(repo_id, result, envir = repo_folder_name_cache)

  return(result)
}
#' get_file_metadata it helps in getting the commit_hash and etag
#' @noRd
get_file_metadata <- function(url) {
  headers <- hub_headers()
  headers["Accept-Encoding"] <- "identity"
  req <- httr::HEAD(
    url,
    httr::config(followlocation = FALSE),
    httr::add_headers(.headers = headers)
  )
  list(
    status_code = req$status_code,
    location = grab_from_headers(req, "location") %||% req$url,
    commit_hash = grab_from_headers(req, "x-repo-commit"),
    etag = normalize_etag(grab_from_headers(req, c("x-linked-etag", "etag"))),
    size = as.integer(grab_from_headers(req, "content-length")),
    error_code = grab_from_headers(req, "x-error-code"),
    error_message = grab_from_headers(req, "x-error-message")
  )
}
symlink_support_cache <- new.env(parent = emptyenv())
#' Check if symlinks are supported in the given directory
#'
#' Tests whether file.symlink() works in the storage folder.
#' Caches the result per folder to avoid repeated tests.
#' Matches Python's huggingface_hub behavior.
#'
#' @param storage_folder Path to storage folder
#' @return TRUE if symlinks work, FALSE otherwise
#' @noRd
supports_symlinks <- function(storage_folder) {
  cache_key <- normalizePath(storage_folder, winslash = "/", mustWork = FALSE)
  if (exists(cache_key, envir = symlink_support_cache, inherits = FALSE)) {
    return(get(cache_key, envir = symlink_support_cache, inherits = FALSE))
  }
  test_dir <- fs::path(storage_folder, ".symlink_test")
  fs::dir_create(test_dir, recurse = TRUE)
  on.exit(fs::dir_delete(test_dir), add = TRUE)
  test_file <- fs::path(test_dir, "test.txt")
  test_link <- fs::path(test_dir, "test_link.txt")
  writeLines("test", test_file)
  result <- suppressWarnings(file.symlink(test_file, test_link))
  assign(cache_key, result, envir = symlink_support_cache)

  if (!result) {
    cli::cli_warn(c(
      "cache system uses symlinks",
      "i" = "Symlinks not supported here, disk usage can increase"
    ))
  }
  result
}

#' Link, move, or copy blob to pointer path based on symlink support
#'
#' Helper function that handles creating the final pointer file.
#' - If symlinks supported: creates symlink
#' - If symlinks not supported and blob just downloaded: moves file
#' - If symlinks not supported and blob already existed: copies file
#'
#' @param blob_path Path to the blob file (source)
#' @param pointer_path Path to the pointer file (destination)
#' @param owned Whether the blob is safe to delete if symlinks are not supported
#' @param storage_folder Path to storage folder (for symlink check)
#' @noRd
link_or_copy <- function(blob_path, pointer_path, owned, storage_folder) {
  if (supports_symlinks(storage_folder)) {
    try(fs::file_delete(pointer_path), silent = TRUE)
    file.symlink(blob_path, pointer_path)
    return(pointer_path)
  }
  if (owned) {
    fs::file_move(blob_path, pointer_path)
  } else {
    fs::file_copy(blob_path, pointer_path, overwrite = TRUE)
  }
  return(pointer_path)
}

#' @noRd
# It helps in downloading the datasets using url
download_file <- function(
  url,
  blob_path,
  filename,
  expected_size = NA,
  max_retries = mlr3hf_retries()
) {
  attempt <- 1
  success <- FALSE

  while (attempt <= max_retries && !success) {
    result <- tryCatch(
      {
        withr::with_tempfile("tmp", {
          lock <- filelock::lock(paste0(blob_path, ".lock"))
          on.exit(
            {
              filelock::unlock(lock)
            },
            add = TRUE
          )

          bar_id <- cli::cli_progress_bar(
            name = if (attempt > 1) {
              glue::glue("{filename} (retry {attempt})")
            } else {
              filename
            },
            total = if (is.numeric(expected_size)) expected_size else NA,
            type = "download"
          )

          progress <- function(down, up) {
            if (down[1] != 0) {
              cli::cli_progress_update(
                total = down[1],
                set = down[2],
                id = bar_id
              )
            }
            TRUE
          }

          handle <- curl::new_handle(
            noprogress = FALSE,
            progressfunction = progress
          )
          curl::handle_setheaders(handle, .list = as.list(hub_headers()))

          curl::curl_download(url, tmp, handle = handle, quiet = FALSE)

          if (!fs::file_exists(tmp) || fs::file_size(tmp) == 0) {
            stop("Downloaded file is empty or missing")
          }

          cli::cli_progress_done(id = bar_id)
          fs::file_move(tmp, blob_path)
        })
        TRUE
      },
      error = function(err) {
        cli::cli_warn("Attempt {attempt}/{max_retries} failed: {err$message}")
        FALSE
      }
    )

    if (isTRUE(result)) {
      success <- TRUE
    } else {
      attempt <- attempt + 1
      if (attempt <= max_retries) {
        Sys.sleep(2^attempt)
      }
    }
  }

  if (!success) {
    cli::cli_abort("Download failed after {max_retries} attempts: {.url {url}}")
  }
}
#' @noRd
get_with_retry <- function(
  url,
  query = NULL,
  headers = NULL,
  max_retries = mlr3hf_retries(),
  ...
) {
  attempt <- 1

  repeat {
    result <- tryCatch(
      {
        args <- list(url = url)
        if (!is.null(headers)) {
          args <- c(args, list(httr::add_headers(.headers = headers)))
        }
        if (!is.null(query)) {
          args$query <- query
        }
        do.call(httr::GET, args)
      },
      error = function(e) e
    )
    network_failed <- inherits(result, "error")
    status_failed <- !network_failed &&
      (httr::status_code(result) == 429 ||
        httr::status_code(result) >= 500)

    if (!network_failed && !status_failed) {
      return(result)
    }

    attempt <- attempt + 1

    if (attempt <= max_retries) {
      message(
        "Attempt ",
        attempt - 1,
        " failed, retrying in ",
        2^attempt
      )
      Sys.sleep(2^attempt)
    } else {
      if (network_failed) {
        stop(
          "Request failed after ",
          max_retries,
          " attempts: ",
          conditionMessage(result),
          call. = FALSE
        )
      } else {
        stop(
          "Request failed after ",
          max_retries,
          " attempts. Status: ",
          httr::status_code(result),
          call. = FALSE
        )
      }
    }
  }
}
