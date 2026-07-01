#' Cache a File from a Hugging Face Hub Repository
#'
#' Downloads and caches a specific file from the canonical (original)
#' version of a dataset repository on the Hugging Face Hub — that is,
#' the dataset as published by its authors, rather than the
#' auto-generated Parquet conversion (see \code{\link{cache_parquet}}
#' for that). If the file has already been cached locally, it is
#' reused instead of being downloaded again.
#'
#' @param repo_id Character string. The repository ID of the dataset on
#'   the Hugging Face Hub, in the form \code{"user_id/repo_name"}
#'   (e.g. \code{"scikit-learn/iris"}).
#' @param file_name Character string. The name of the file to download
#'   from the repository, e.g. \code{"iris.csv"}.
#' @param local_files_only Logical. If \code{TRUE}, only the local
#'   cache is checked and no network request is made; an error is
#'   raised if the file is not already cached. If \code{FALSE}
#'   (default), the file is downloaded if not already present, or if a
#'   newer revision is available.
#' @param revision Character string. The branch, tag, or commit hash to
#'   download the file from. Defaults to \code{"main"}.
#' @param ... Additional arguments for future use.
#'
#' @return Character string giving the local file path where the
#'   cached file is stored.
#'
#' @details
#' Files are cached in a local directory following the Hugging Face
#' Hub caching convention, keyed by \code{repo_id}, \code{revision},
#' and \code{file_name}. Subsequent calls with the same arguments will
#' return the cached path without re-downloading, unless the remote
#' file has changed.
#'
#' @examplesIf interactive()
#' cache_hfhub(
#'   repo_id   = "scikit-learn/iris",
#'   file_name = "iris.csv"
#' )
#'
#' # Use a cached copy only, without attempting a network request
#' cache_hfhub(
#'   repo_id          = "scikit-learn/iris",
#'   file_name        = "iris.csv",
#'   local_files_only = TRUE
#' )
#'
#' @seealso
#' \code{\link{cache_parquet}} for caching the auto-converted Parquet
#' version of a dataset instead.
#'
#' \url{https://huggingface.co/docs/huggingface_hub/en/guides/manage-cache}
#'
#' @export
cache_hfhub <- function(
    repo_id,
    file_name,
    local_files_only = FALSE,
    revision = "main",
    ...
) {
    cache_dir <- mlr3hf_cache_dir()
    storage_folder <- fs::path(cache_dir, "hub", repo_folder_name(repo_id))
    if (is.null(file_name)) {
        stop("require filename")
    }
    if (grepl("^[0-9a-f]{40}$", revision)) {
        pointer_path <- fs::path(
            storage_folder,
            "snapshots",
            revision,
            file_name
        )
        if (fs::file_exists(pointer_path)) {
            return(pointer_path)
        }
    }
    if (!local_files_only) {
        url <- hub_url(repo_id, file_name, revision = revision)
        metadata <- get_file_metadata(url)

        if (metadata$status_code >= 400) {
            stop("Failed to fetch metadata for: ", repo_id, call. = FALSE)
        }

        commit_hash <- metadata$commit_hash
        if (is.null(commit_hash)) {
            cli::cli_abort(gettext(
                "Distant resource does not seem to be on huggingface.co (missing commit header)."
            ))
        }
        etag <- metadata$etag
        if (is.null(etag)) {
            cli::cli_abort(gettext(
                "Distant resource does not have an ETag, we won't be able to reliably ensure reproducibility."
            ))
        }
        expected_size <- metadata$expected_size
    }

    # etag is NULL == we don't have a connection or we passed local_files_only.
    # try to get the last downloaded one from the specified revision.
    # If the specified revision is a commit hash, look inside "snapshots".
    # If the specified revision is a branch or tag, look inside "refs".
    if (is.null(etag)) {
        # Try to get "commit_hash" from "revision"
        commit_hash <- NULL
        if (grepl("^[0-9a-f]{40}$", revision)) {
            commit_hash <- revision
        } else {
            ref_path <- fs::path(storage_folder, "refs", revision)
            if (fs::file_exists(ref_path)) {
                commit_hash <- readLines(ref_path)
            }
        }

        # Return pointer file if exists
        if (!is.null(commit_hash)) {
            pointer_path <- fs::path(
                storage_folder,
                "snapshots",
                commit_hash,
                file_name
            )
            if (fs::file_exists(pointer_path)) {
                return(pointer_path)
            }
        }

        if (local_files_only) {
            cli::cli_abort(gettext(
                "Cannot find the requested files in the disk cache and",
                " outgoing traffic has been disabled. To enable hf.co look-ups",
                " and downloads online, set 'local_files_only' to False."
            ))
        } else {
            cli::cli_abort(gettext(
                "Connection error, and we cannot find the requested files in",
                " the disk cache. Please try again or make sure your Internet",
                " connection is on."
            ))
        }
    }

    if (is.null(etag)) {
        cli::cli_abort(gettext("etag must have been retrieved from server"))
    }
    if (is.null(commit_hash)) {
        cli::cli_abort(gettext(
            "commit_hash must have been retrieved from server"
        ))
    }

    blob_path <- fs::path(storage_folder, "blobs", etag)
    snapshot_path <- fs::path(
        storage_folder,
        "snapshots",
        commit_hash,
        file_name
    )

    fs::dir_create(fs::path(storage_folder, "blobs"), recurse = TRUE)
    fs::dir_create(
        fs::path(storage_folder, "snapshots", commit_hash),
        recurse = TRUE
    )

    if (revision != commit_hash) {
        ref_path <- fs::path(storage_folder, "refs", revision)
        fs::dir_create(fs::path_dir(ref_path))
        fs::file_create(ref_path)
        writeLines(commit_hash, ref_path)
    }

    if (fs::file_exists(snapshot_path)) {
        return(snapshot_path)
    }

    if (fs::file_exists(blob_path)) {
        link_or_copy(blob_path, snapshot_path, owned = FALSE, storage_folder)
        return(snapshot_path)
    }
    download_file(
        url,
        blob_path,
        file_name,
        expected_size,
        max_retries = mlr3hf_retries()
    )
    link_or_copy(blob_path, snapshot_path, owned = TRUE, storage_folder)

    return(snapshot_path)
}
