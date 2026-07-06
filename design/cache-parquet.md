# Parquet Caching

**Implementation:** `R/cache_parquet.R`

## Goal

This document describes the design and implementation of the Parquet caching system. It explains how datasets are cached, how downloads are organized on disk, and how the cache avoids re-downloading unchanged Parquet shards.

The implementation is designed to efficiently support versioned datasets hosted on the Hugging Face Hub.

---

## Design

The caching mechanism is built around the following design:

* **Blobs** store the physical contents of downloaded Parquet shards.
* **Snapshots** represent a specific dataset revision, identified by its commit hash.

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


### Directory responsibilities

* **blobs/** contains the physical Parquet files named by their ETag.
* **snapshots/** contains one directory per dataset revision (commit hash).
* Snapshot files are symbolic links (or copies) pointing to the corresponding blob.

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
