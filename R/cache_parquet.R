#' Cache a Parquet Export of a Hugging Face Dataset
#'
#' Downloads and caches the Parquet files for a dataset hosted on the
#' Hugging Face Hub, using the auto-generated \code{refs/convert/parquet}
#' branch. This branch contains a Parquet conversion of the dataset that
#' Hugging Face maintains automatically, which avoids the need to load
#' the dataset via its original (often script-based) loading format.
#'
#' @param repo_id Character string. The repository ID of the dataset on
#'   the Hugging Face Hub, in the form \code{"user_id/repo_name"}
#'   (e.g. \code{"fancyzhx/amazon_polarity"}).
#' @param config Character string. The dataset configuration name. Many
#'   datasets expose only one configuration, in which case
#'   \code{"default"} can usually be used. If unsure, inspect the
#'   repository's \code{refs/convert/parquet} branch on the Hub to see
#'   the available configuration folders.
#' @param split Character string. The dataset split to cache, such as
#'   \code{"train"}, \code{"test"}, or \code{"validation"}. If
#'   \code{NULL} (default), all available splits for the given
#'   configuration are cached.
#' @param revision Character string. A specific commit hash to pin the
#'   download to, instead of using the latest revision of the
#'   \code{refs/convert/parquet} branch. Defaults to \code{NULL}, which
#'   resolves to the most recent commit.
#' @param ... Additional arguments, reserved for future use.
#'
#' @return A named \code{list} with one entry per cached split. Each
#'   entry is itself a list containing:
#'   \describe{
#'     \item{split}{Character string giving the split name.}
#'     \item{path}{Character string giving the local file path where
#'       the cached Parquet file was saved.}
#'   }
#'
#' @details
#' Files are downloaded from the
#' \code{refs/convert/parquet} branch maintained by Hugging Face, not
#' from the dataset's default branch. Large datasets may be split
#' across multiple Parquet shards; all matching shards for the
#' requested split are downloaded and cached.
#'
#' @examplesIf interactive()
#' cache_parquet(
#'   repo_id = "scikit-learn/iris",
#'   config  = "default"
#' )
#'
#' cache_parquet(
#'   repo_id = "fancyzhx/amazon_polarity",
#'   config  = "amazon_polarity",
#'   split   = "train"
#' )
#'
#' @seealso
#' \url{https://huggingface.co/docs/datasets-server/en/parquet}
#'
#' @export
cache_parquet <- function(
    repo_id,
    revision = "refs%2Fconvert%2Fparquet",
    config,
    split = NULL,
    ...
) {
    cache_dir <- mlr3hf_cache_dir()
    if (is.null(config)) {
        stop("requires config")
    }
    data_dir <- fs::path(cache_dir, "datasets")
    base_url <- "https://datasets-server.huggingface.co/parquet?dataset="
    api_url <- glue::glue("{base_url}{repo_id}")
    response <- httr::GET(api_url)

    data <- jsonlite::fromJSON(
        httr::content(response, "text", encoding = "UTF-8"),
        simplifyDataFrame = TRUE,
        simplifyVector = TRUE
    )

    parquet_files <- data.frame(
        dataset = as.character(data$parquet_files$dataset),
        config = as.character(data$parquet_files$config),
        split = as.character(data$parquet_files$split),
        #url = as.character(data$parquet_files$url),
        filename = as.character(data$parquet_files$filename),
        size = as.numeric(data$parquet_files$size),
        stringsAsFactors = FALSE
    )

    filtered_files <- parquet_files[parquet_files$config == config, ]
    b_url <- mlr3hf_hub_url()

    if (nrow(filtered_files) == 0) {
        cli::cli_abort(
            "Config '{config}' not available: {paste(unique(parquet_files$config), collapse=', ')}"
        )
    }

    if (!is.null(split)) {
        filtered_files <- filtered_files[filtered_files$split == split, ]

        if (nrow(filtered_files) == 0) {
            cli::cli_abort(
                "Split '{split}' not available: {paste(unique(parquet_files$split), collapse=', ')}"
            )
        }
    }

    snapshot_paths <- list()
    for (i in seq_len(nrow(filtered_files))) {
        curr_split <- filtered_files$split[i]
        filename <- filtered_files$filename[i]
        expected_size <- filtered_files$size[i]

        url <- glue::glue(
            "{b_url}/datasets/{repo_id}/resolve/{revision}/{config}/{curr_split}/{filename}"
        )

        metadata <- get_file_metadata(url)
        etag <- metadata$etag
        commit_hash <- metadata$commit_hash
        error_code <- metadata$error_code

        if (!is.null(error_code)) {
            cli::cli_abort(
                "Metadata fetch failed for {url} , Correct your input. Commit_hash for 'refs/convert/parquet' and other branch are different. "
            )
        }

        blob_dir <- fs::path(
            data_dir,
            repo_folder_name(repo_id),
            config,
            curr_split,
            "blobs"
        )
        snapshot_dir <- fs::path(
            data_dir,
            repo_folder_name(repo_id),
            config,
            curr_split,
            "snapshots"
        )

        fs::dir_create(blob_dir, recurse = TRUE)
        fs::dir_create(fs::path(snapshot_dir, commit_hash), recurse = TRUE)

        blob_path <- fs::path(blob_dir, etag)
        snapshot_path <- fs::path(snapshot_dir, commit_hash, filename)

        if (fs::file_exists(snapshot_path)) {
            snapshot_paths[[curr_split]] <- c(
                snapshot_paths[[curr_split]],
                snapshot_path
            )
            next
        }

        if (fs::file_exists(blob_path)) {
            link_or_copy(
                blob_path,
                snapshot_path,
                owned = FALSE,
                as.character(data_dir)
            )
            snapshot_paths[[curr_split]] <- c(
                snapshot_paths[[curr_split]],
                snapshot_path
            )
            next
        }
        #dataset will download here
        download_file(
            url,
            blob_path,
            filename,
            expected_size,
            max_retries = mlr3hf_retries()
        )
        if (!fs::file_exists(blob_path)) {
            cli::cli_abort("Blob missing after download for: {curr_split}")
        }

        link_or_copy(
            blob_path,
            snapshot_path,
            owned = TRUE,
            as.character(data_dir)
        )

        if (!fs::file_exists(snapshot_path)) {
            message("Snapshot link failed for: {curr_split}")
        }

        snapshot_paths[[curr_split]] <- c(
            snapshot_paths[[curr_split]],
            snapshot_path
        )
    }
    return(snapshot_paths)
}
