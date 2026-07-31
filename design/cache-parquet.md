# Parquet Caching

**Implementation:** `R/cache_parquet.R`

## Goal

This document describes the design and implementation of the Parquet caching system. It explains how datasets are cached, how downloads are organized on disk, and how the cache avoids re-downloading unchanged Parquet shards.

The implementation is designed to efficiently support versioned datasets hosted on the Hugging Face Hub.

---
## Key terms
* **ETag:** An ETag (Entity Tag) is a unique identifier, or "fingerprint," assigned to an individual file. It changes only when the contents of that specific file are modified, making it useful for detecting file updates and validating cached copies.
* **Commit Hash:** A commit hash is a unique alphanumeric identifier that represents a specific revision of a repository. It changes whenever any file in the repository is added, modified, or removed. Unlike an ETag, which is specific to an individual file, a commit hash identifies the state of the entire repository at a particular point in time.
* **Parquet Shards:** When a dataset from the main branch is converted to Parquet format, the generated files are stored in the `refs/convert/parquet` branch. Large datasets are split into multiple Parquet files (called shards), with each shard typically being up to approximately 200 MB in size. For example, a dataset that is approximately 1 GB (compressed) would generally be divided into about five Parquet shards.
---
## Design

The caching mechanism follows the same high-level architecture as the Hugging Face Hub cache and is built around two core concepts:

* **Blobs** store the physical contents of downloaded Parquet shards.
* **Snapshots** represent a specific dataset revision, identified by its commit hash.
blobs and snapshot are interlinked using symlinks
By default, Parquet files are downloaded from the converted Parquet revision:

```text
refs/convert/parquet
```

The function first queries the Hugging Face Datasets Server Parquet API to discover the available Parquet shards for the requested dataset. This returns metadata such as the available configurations, splits, shard filenames, and file sizes.

For each selected shard, a Hugging Face Hub download URL is constructed using the requested revision. The file metadata is then retrieved to obtain:

* the **commit hash**, identifying the dataset revision; and
* the **ETag**, uniquely identifying the shard contents.

Each downloaded shard is first stored in the **blobs** directory using its ETag as the filename. The cache then calls `link_or_copy()` to create the corresponding file inside the appropriate **snapshot** directory. Depending on the value of `symlink_cache`, this operation either creates a symbolic link to the blob or copies the file.

Every downloaded shard is therefore associated with:

* a **commit hash**, identifying the dataset revision from which the shard was downloaded; and
* an **ETag**, uniquely identifying the shard contents.

Although the commit hash changes whenever the dataset revision changes, individual shards may remain unchanged. Since blobs are indexed by their ETag, unchanged shards are reused across multiple dataset revisions instead of being downloaded again.


---

## Cache Layout
```
~/.cache/huggingface/
    └── datasets/
        └── <repo_folder>/
            └── <config>/
                ├── train/
                │   ├── blobs/
                │   │   └── <etag>              # actual parquet shard
                │   └── snapshots/
                │       └── <commit_hash>/
                │           └── <filename>.parquet -> ../../blobs/<etag>
                │
                ├── test/
                │   ├── blobs/
                │   └── snapshots/
                │
                └── validation/
                    ├── blobs/
                    └── snapshots/
```
**Note:** The `train`, `test`, and `validation` folders may not all be present for every dataset. Some datasets provide only a `train` split, in which case no `test` or `validation` directories are created. Others may include only `train` and `test`, while some provide all three splits.

### Directory responsibilities

* **blobs/** contains the physical Parquet files named by their ETag.
* **snapshots/** contains one directory per dataset revision (commit hash).
* Snapshot files are symbolic links (or copies) pointing to the corresponding blob.

---
## URL Used

To retrieve the list of Parquet files for a dataset, the following API endpoint is used:

```text
https://datasets-server.huggingface.co/parquet?dataset=<repo_id>
```

This endpoint returns metadata for all available Parquet files in the dataset, including the dataset configurations, splits, filenames, storage information, and Parquet shards.

```r
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
    # url = as.character(data$parquet_files$url),
    filename = as.character(data$parquet_files$filename),
    size = as.numeric(data$parquet_files$size),
    stringsAsFactors = FALSE
)
```

The download URL for a selected Parquet file is then passed to `get_file_metadata(url)`. This function sends an HTTP `HEAD` request to retrieve metadata such as the **commit hash**, **ETag**, and **content length** from the response headers. Because a `HEAD` request returns only the response headers, it does **not** download the file contents.

The retrieved metadata is used to determine whether the requested file is already available in the local cache. If the corresponding blob exists, it is reused by creating the appropriate snapshot entry. Otherwise, the file is downloaded using an HTTP `GET` request and stored in the cache before being linked (or copied) into the snapshot directory.

---

## Download Flow

When a user requests a dataset, the following steps occur:

1. The user provides a `repo_id`, a `config`, and optionally a `split` or `revision`.
2. `mlr3hf` queries the Hugging Face Datasets Server Parquet API to retrieve the metadata for all available Parquet files belonging to the dataset.
3. The returned metadata is filtered according to the requested configuration and, if specified, the requested split.
4. For each matching Parquet shard:
   * A download URL is constructed using the repository, revision, configuration, split, and shard filename.
   * The file metadata is retrieved to obtain the shard's **commit hash** and **ETag**.
   * The corresponding `blob_path` and `snapshot_path` are computed, and the required cache directories are created if they do not already exist.
   * If the snapshot already exists, it is reused immediately.
   * Otherwise, if a blob with the same ETag already exists, it is reused by linking/copying it into the snapshot directory.
   * Otherwise, the shard is downloaded via `download_file()` and stored in `blobs/` under its ETag, then linked/copied into the snapshot directory.
5. After all requested shards have been processed, the function returns the snapshot paths grouped by split.

---

## link_or_copy
This function creates the relationship between the blob and the snapshot. If the operating system supports symbolic links, it creates a symlink from the snapshot to the corresponding blob. Otherwise, it copies the file into the snapshot directory. This ensures compatibility across platforms while avoiding unnecessary duplication when symlinks are available.
```r

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
```
---

## Reference

You can learn more about the Parquet endpoint in the official Hugging Face documentation:

* [Parquet Endpoint](https://huggingface.co/docs/dataset-viewer/parquet#using-the-hugging-face-hub-api)

For details on the Hugging Face Hub cache structure and design, see:

* [Hugging Face Hub – Manage Cache](https://huggingface.co/docs/huggingface_hub/v0.22.2/guides/manage-cache)

---
