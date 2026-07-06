# HF Hub Caching

**Implementation:** `R/cache_hfhub.R`

## Goal

This document describes the design and implementation of the Hugging Face Hub caching system. It explains how individual files are cached, how revisions are managed, and how the cache avoids re-downloading files that have already been downloaded.

Unlike `cache_parquet()`, which downloads the auto-converted Parquet branch of a dataset, `cache_hfhub()` downloads a specific file from the **canonical (author-published) version** of a repository, at a given branch, tag, or commit.

---

## Design

The caching mechanism is built around the following design:

* **Blobs** store the physical contents of downloaded files.
* **Snapshots** represent a specific repository revision, identified by its commit hash.
* **Refs** map branch or tag names (for example, `main`) to their corresponding commit hashes.

A user requests a file by providing:

* `repo_id`
* `file_name`
* optionally, `revision` (a branch name, tag, or commit hash; defaults to `main`)
* `local_files_only` (defaults to `FALSE`)

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

## Download Flow

1. The user provides `repo_id`, `file_name`, and optionally `revision` / `local_files_only`.
2. **If `revision` is already a full commit hash** and a matching snapshot exists on disk, it is returned immediately — no network call, regardless of `local_files_only`.
3. **Else, if `local_files_only = FALSE`**, the function builds the download URL and fetches file metadata (commit hash, ETag, expected size). If the server responds with an HTTP error status, the function aborts immediately with an error — it does **not** fall back to a local cache lookup at this point.
4. **If `local_files_only = TRUE`**, the online metadata step is skipped entirely, and the function instead tries to resolve `revision` locally:
   * if `revision` is a commit hash, use it directly;
   * otherwise, look up the corresponding commit hash in `refs/<revision>`.
   * If a matching snapshot is found this way, its path is returned immediately.
   * If not found, the function aborts with an error telling the user to enable network access.
5. With a resolved commit hash and ETag (from step 3), the function computes `blob_path` and `snapshot_path`, creating any missing cache directories.
6. If `revision` was a branch/tag (not already the commit hash itself), `refs/<revision>` is (re)written with the resolved commit hash.
7. If the snapshot already exists, its path is returned.
8. Otherwise, if a blob with the same ETag already exists, it's linked/copied into the snapshot directory and returned.
9. Otherwise, the file is downloaded via `download_file()`, stored in `blobs/` under its ETag, then linked/copied into the snapshot directory.
10. The path to the file inside the snapshot directory is returned to the caller.

---
