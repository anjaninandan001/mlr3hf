#' @title cache_parquet
#' @description it helps in caching the dataset which in the branch refs/convert/parquet
#' @param repo_id repo id of the dataset
#' @param config if dataset have no config give config as default or you can check the repository config is mainly a folder
#' @param split user have option to select a specific split
#' @param ... additional arguments for future
#'
#' @return list containing split and the url of the split
#' @examples
#' \dontrun{
#'   cache_parquet(
#'     repo_id   = "scikit-learn/iris",
#'     config="default"
#'   )
#' }
#' cache_parquet(repo_id="scikit-learn/iris",config="default")
#' @export
cache_parquet <- function(repo_id, config = NULL, split = NULL, ...) {
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
        url = as.character(data$parquet_files$url),
        filename = as.character(data$parquet_files$filename),
        size = as.numeric(data$parquet_files$size),
        stringsAsFactors = FALSE
    )

    filtered_files <- parquet_files[parquet_files$config == config, ]

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
        url <- filtered_files$url[i]
        filename <- filtered_files$filename[i]

        metadata <- get_file_metadata(url)
        etag <- metadata$etag
        commit_hash <- metadata$commit_hash

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

        lock <- filelock::lock(paste0(blob_path, ".lock"))
        on.exit(filelock::unlock(lock), add = TRUE, after = FALSE)

        withr::with_tempfile("tmp", {
            headers <- hub_headers()

            response <- httr::GET(
                url,
                httr::write_disk(tmp, overwrite = TRUE),
                httr::add_headers(.headers = headers)
            )

            if (response$status_code >= 400) {
                cli::cli_abort(
                    "Download failed ({response$status_code}): {url}"
                )
            }
            if (!fs::file_exists(tmp)) {
                cli::cli_abort("Download failed: {url}")
            }
            file.rename(tmp, blob_path)
        })

        link_or_copy(
            blob_path,
            snapshot_path,
            owned = TRUE,
            as.character(data_dir)
        )
        snapshot_paths[[curr_split]] <- c(
            snapshot_paths[[curr_split]],
            snapshot_path
        )
    }
    return(snapshot_paths)
}
