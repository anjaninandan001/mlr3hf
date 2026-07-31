# HF Hub Caching

**Implementation:** `R/cache_hfhub.R`

## Goal

This document describes the design and implementation of the Hugging Face Hub caching system. It explains how individual files are cached, how revisions are managed, and how the cache avoids re-downloading files that have already been downloaded.

Unlike `cache_parquet()`, which downloads the auto-converted Parquet branch of a dataset, `cache_hfhub()` downloads a specific file from the **canonical (author-published) version** of a repository, at a given branch, tag, or commit.

---
## Key Terms
* **ETag:** An ETag (Entity Tag) is a unique identifier, or "fingerprint," assigned to a file. It changes whenever the contents of that specific file are modified, making it useful for detecting file updates and validating cached copies.
* **Commit Hash:** A commit hash is a unique alphanumeric identifier for a specific revision of a repository. It changes whenever any file in the dataset repository is modified, added, or removed. Unlike an ETag, which is specific to an individual file, a commit hash represents the state of the entire repository at a particular point in time.

## Design

The caching mechanism follows given below design:

* **Blobs** store the physical contents of downloaded files.
* **Snapshots** represent a specific repository revision, identified by its commit hash.
* **Refs** map branch or tag names (for example, `main`) to their corresponding commit hashes.

A user requests a file by providing:

- **`repo_id`**: The Hugging Face dataset repository ID. This is a required argument and should be specified in the format `owner/dataset`, for example, `scikit-learn/iris` or `ibm-research/duorc`.

- **`file_name`**: The path to a specific file within the dataset repository. If the file is located in the repository root, specify only the filename (e.g., `iris.csv`). If it is inside one or more directories, provide the relative path from the repository root, for example, `data/train.csv` or `folder/subfolder/file.csv`.

- **`revision`** *(optional, defaults to `"main"`)*: The repository revision from which the file should be fetched. This can be a branch name, a tag, or a commit hash. Use this argument if the desired file exists in a revision other than the default `main` branch.

- **`local_files_only`** *(optional, defaults to `FALSE`)*: If set to `TRUE`, the function uses only the locally cached file and does not contact the Hugging Face Hub to check whether a newer version is available (i.e., it skips metadata checks such as the ETag and commit hash). This avoids unnecessary network requests but means that updates to the dataset on Hugging Face will not be detected until `local_files_only = FALSE` is used.

When downloading a file, it is first stored in the **blobs** directory using its **ETag** as the filename. The cache then calls `link_or_copy()` to create the corresponding file inside the appropriate **snapshot** directory. Depending on the value of `symlink_cache`, this operation either creates a symbolic link to the blob or copies the file.

The **refs** directory is used only when the requested revision is specified as a branch or tag rather than a commit hash. Each file inside `refs/` is named after the branch or tag (for example, `main`) and contains the commit hash that the branch or tag currently resolves to. This mapping allows the cache to reconstruct the correct snapshot when working offline or when `local_files_only = TRUE`.

Every downloaded file is associated with:

* a **commit hash**, identifying the repository revision from which the file was downloaded; and
* an **ETag**, uniquely identifying the file contents.

Although the commit hash changes whenever the repository revision changes, the file contents may remain identical. Since blobs are indexed by their ETag, unchanged files are reused across multiple revisions instead of being downloaded again. 

---

## Cache Layout

```text
~/.cache/huggingface/
    └── hub/
        └── <repo_name>/
            ├── blobs/
            │   └── <etag>                  # actual downloaded file
            │
            ├── snapshots/
            │   └── <commit_hash>/
            │       └── <file_name>         # symlink/copy → ../../blobs/<etag>
            │
            └── refs/
                └── <branch or tag>                    # contains commit hash
```

### Directory responsibilities

* **blobs/** contains the physical downloaded files named by their ETag.
* **snapshots/** contains one directory per repository revision (commit hash).
* **refs/** maps branch or tag names to commit hashes, refreshed on each online resolution.
* Snapshot files are symbolic links (or copies) pointing to the corresponding blob.

---

## URL used 

The following URL is used to download a file from the Hugging Face Hub:
```text
https://huggingface.co/datasets/<repo_id>/resolve/<revision>/<file_name>
```

The function `get_file_metadata(url)` uses the same URL to retrieve the file metadata (such as the **commit hash** and **ETag**) by sending an HTTP HEAD request. The HEAD request does not download the file itself; it only retrieves the response headers containing the metadata. The actual file is downloaded later using a separate download request (HTTP GET) if it is not already present in the local cache.

The retrieved metadata is used to determine whether the requested file is already available in the local cache. If the corresponding blob exists, it is reused by creating the appropriate snapshot entry. Otherwise, the file is downloaded using an HTTP `GET` request and stored in the cache before being linked (or copied) into the snapshot directory.

---


## Download Flow

1. The user provides `repo_id`, `file_name`, and optionally `revision` / `local_files_only`.
2. **If `revision` is already a full commit hash** and a matching snapshot exists on disk, it is returned immediately — no network call, regardless of `local_files_only`.
3. **Else, if `local_files_only = FALSE`**, the function builds the download URL and fetches file metadata (commit hash, ETag, expected size). If the server responds with an HTTP error status, the function aborts immediately with an error — it does **not** fall back to a local cache lookup at this point.
4. **If `local_files_only = TRUE`**, the online metadata step is skipped entirely, and the function instead tries to resolve `revision` locally:
   * if `revision` is a commit hash, use it directly;
   * otherwise, look up the corresponding commit hash in `refs/<revision>`.
   * If a matching snapshot is found this way, its path is returned immediately.
   * If not found, the function aborts with an error telling the user to enable network access.
**Note:** When local_files_only = TRUE, the dataset is loaded exclusively from the local cache. No request is made to check for updates on the Hugging Face Hub, so any newer version available in the remote repository is ignored. As a result, the locally cached version is used even if the repository has been updated.  
5. With a resolved commit hash and ETag (from step 3), the function computes `blob_path` and `snapshot_path`, creating any missing cache directories.
6. If `revision` was a branch/tag (not already the commit hash itself), `refs/<revision>` is (re)written with the resolved commit hash.
7. If the snapshot already exists, its path is returned.
8. Otherwise, if a blob with the same ETag already exists, it's linked/copied into the snapshot directory and returned.
9. Otherwise, the file is downloaded via `download_file()`, stored in `blobs/` under its ETag, then linked/copied into the snapshot directory.
10. The path to the file inside the snapshot directory is returned to the caller.

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

## References

For a reference implementation of this caching approach, see the **hfhub** package:

- [hfhub: `hub_download.R`](https://github.com/mlverse/hfhub/blob/master/R/hub_download.R)

For more details on the Hugging Face Hub cache structure and design, see the official documentation:

- [Hugging Face Hub – Manage Cache](https://huggingface.co/docs/huggingface_hub/v0.22.2/guides/manage-cache)

---