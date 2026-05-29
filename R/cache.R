symlink_support_cache <- new.env(parent = emptyenv())

supports_symlinks <- function(storage_folder) {
  cache_key <- normalizePath(storage_folder, winslash = "/", mustWork = FALSE)
  if (exists(cache_key, envir = symlink_support_cache)) {
    return(get(cache_key, envir = symlink_support_cache))
  }
  test_dir  <- fs::path(storage_folder, ".symlink_test")
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
      "i" = "Symlinks not supported here ,disk usage may increase"
    ))
  }
  result
}
REGEX_COMMIT_HASH <- function() {
  "^[0-9a-f]{40}$"
}

resolve_revision <- function(storage_folder, revision) {
  ref_path <- fs::path(storage_folder, "refs", revision)
  if (fs::file_exists(ref_path)) {
    return(readLines(ref_path, warn = FALSE))
  }
  return(revision)
}

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

repo_folder_name <- function(repo_id) {
  gsub("[/:]", "_", repo_id)
}

get_pointer_path <- function(cache_dir, repo_id, commit_hash, file_name) {
  fs::path(cache_dir, repo_folder_name(repo_id), "snapshots", commit_hash, file_name)
}

update_ref <- function(storage_folder, revision, commit_hash) {
  ref_path <- fs::path(storage_folder, "refs", revision)
  fs::dir_create(fs::path(storage_folder, "refs"), recurse = TRUE)
  writeLines(commit_hash, ref_path)
}

cached <- function(repo_id, config, fun, revision = "main", file_name = NULL, ..., parquet = mlr3hf_parquet()) {
   if (!parquet && is.null(file_name)) {
  stop("file_name required when parquet = FALSE", call. = FALSE)
}
 if(parquet && is.null(config)) {
  stop("config required when parquet = TRUE", call. = FALSE)
}
  cache_dir <- mlr3hf_cache_dir()
  

  # Parquet mode
  if (parquet) {
    data_dir<-fs::path(cache_dir,"dataset")
    dataset_dir <- fs::path(data_dir, repo_id, config)

    
    if (!fs::dir_exists(dataset_dir)) {
      fs::dir_create(dataset_dir, recurse = TRUE)
    }

    files <- fs::dir_ls(dataset_dir, recurse = TRUE)
    if (length(files) > 0) {
      message("Using cached dataset: ", dataset_dir)
      return(dataset_dir)
    }

    fun(repo_id = repo_id, config = config, ..., file_dir = dataset_dir)

    files <- fs::dir_ls(dataset_dir, recurse = TRUE, full.names = TRUE)
    if (length(files) == 0) {
      cli::cli_warn(c(
        "Failed to cache dataset: {repo_id} / {config}",
        "i" = "Dataset will be downloaded again on next request"
      ))
    }

    return(dataset_dir)
  }

  #for parquet = FALSE, we use file_name and revision to manage caching

  # storage folder for the repo (where blobs, snapshots, and refs are stored)
  storage_folder <- fs::path(cache_dir, "hub", repo_folder_name(repo_id))

  # resolve revision to commit hash (if it's a branch or tag)
  commit_hash <- resolve_revision(storage_folder, revision)
  # IF COMMIT HASH, CHECK POINTER PATH IN CACHE , FAST RETURN, NO NETWORK
  if (grepl(REGEX_COMMIT_HASH(), commit_hash)) {
    snapshot_path <- get_pointer_path(cache_dir, repo_id, commit_hash, file_name)
    if (fs::file_exists(snapshot_path)) {
      return(snapshot_path)   # fast return ,no network
    }
  }

  # SERVER CALL: get metadata to find commit_hash and etag
  url      <- hub_url(repo_id, file_name, revision = revision)
  metadata <- get_file_metadata(url)

  if (metadata$status_code >= 400) {
    stop("Failed to fetch metadata for: ", repo_id, call. = FALSE)
  }

  #take commit_hash and etag from metadata
  commit_hash <- metadata$commit_hash
  etag        <- metadata$etag

  # create paths
  blob_path     <- fs::path(storage_folder, "blobs", etag)
  snapshot_path <- fs::path(storage_folder, "snapshots", commit_hash, file_name)

  # create necessary directories
  fs::dir_create(fs::path(storage_folder, "blobs"), recurse = TRUE)
  fs::dir_create(fs::path(storage_folder, "snapshots", commit_hash), recurse = TRUE)

  # if snapshot exists, return,no need to check blob or download
  if (fs::file_exists(snapshot_path)) {
    return(snapshot_path)
  }

  # if blob exists, link or copy to snapshot and return,no need to download
  if (fs::file_exists(blob_path)) {
    link_or_copy(blob_path, snapshot_path, owned = FALSE, storage_folder)
    return(snapshot_path)
  }

  # locked the file before downloading 
  lock <- filelock::lock(paste0(blob_path, ".lock"))
  on.exit(filelock::unlock(lock), add = TRUE)

  # after acquiring lock, check again if snapshot exists (another process might have downloaded it)
  if (fs::file_exists(snapshot_path)) {
    return(snapshot_path)
  }

  # download dataset
  withr::with_tempfile("tmp", {
  fun(
    repo_id   = repo_id,
    file_name = file_name,
    revision  = revision,
    destfile  = tmp        
  )
  file.rename(tmp, blob_path)  
 })

  # saving refs
  update_ref(storage_folder, revision, commit_hash)

  # link or copy
  link_or_copy(blob_path, snapshot_path, owned = TRUE, storage_folder)

  return(snapshot_path)
}
utils::globalVariables("tmp")