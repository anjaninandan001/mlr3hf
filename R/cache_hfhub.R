#' @title cache_hfhub
#' @description it helps in caching the canonical dataset means the original dataset that are on hf.
#' @param repo_id repo id of the dataset
#' @param file_name file name e.g. "iris.csv"
#' @param local_files_only can if data is already present in the disk then that can be accessed
#' @param revision it helps in getting any commit_hash, branch datasets
#' @param ... additional arguments passed to httr::GET
#'
#' @return it returns the path of the dataset were its downloaded
#' @examples
#' \dontrun{
#'   cache_hfhub(
#'     repo_id   = "scikit-learn/iris",
#'     file_name = "iris.csv",
#'     fun       = download_hub
#'   )
#' }
#' @export
cache_hfhub <- function(
    repo_id,
    file_name = NULL,
    local_files_only = FALSE,
    revision = "main",
    ...
) {
    cache_dir = mlr3hf_cache_dir()
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
    etag <- NULL
    commit_hash <- NULL
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

    lock <- filelock::lock(paste0(blob_path, ".lock"))
    on.exit(filelock::unlock(lock), add = TRUE)

    withr::with_tempfile("tmp", {
        download_hfhub(
            repo_id = repo_id,
            file_name = file_name,
            revision = "main",
            destfile = tmp
        )
        if (!fs::file_exists(tmp)) {
            cli::cli_abort("Download failed: file not found at {tmp}")
        }

        file.rename(tmp, blob_path)
    })
    link_or_copy(blob_path, snapshot_path, owned = TRUE, storage_folder)

    return(snapshot_path)
}
