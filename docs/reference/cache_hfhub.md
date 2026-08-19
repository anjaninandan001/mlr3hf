# Cache a File from a Hugging Face Hub Repository

Downloads and caches a specific file from the canonical (original)
version of a dataset repository on the Hugging Face Hub — that is, the
dataset as published by its authors, rather than the auto-generated
Parquet conversion (see
[`cache_parquet`](https://anjaninandan001.github.io/mlr3hf/reference/cache_parquet.md)
for that). If the file has already been cached locally, it is reused
instead of being downloaded again.

## Usage

``` r
cache_hfhub(
  repo_id,
  file_name,
  local_files_only = FALSE,
  revision = "main",
  ...
)
```

## Arguments

- repo_id:

  Character string. The repository ID of the dataset on the Hugging Face
  Hub, in the form `"user_id/repo_name"` (e.g. `"scikit-learn/iris"`).

- file_name:

  Character string. The name of the file to download from the
  repository, e.g. `"iris.csv"`.

- local_files_only:

  Logical. If `TRUE`, only the local cache is checked and no network
  request is made; an error is raised if the file is not already cached.
  If `FALSE` (default), the file is downloaded if not already present,
  or if a newer revision is available.

- revision:

  Character string. The branch, tag, or commit hash to download the file
  from. Defaults to `"main"`.

- ...:

  Additional arguments for future use.

## Value

Character string giving the local file path where the cached file is
stored.

## Details

Files are cached in a local directory following the Hugging Face Hub
caching convention, keyed by `repo_id`, `revision`, and `file_name`.
Subsequent calls with the same arguments will return the cached path
without re-downloading, unless the remote file has changed.

## See also

[`cache_parquet`](https://anjaninandan001.github.io/mlr3hf/reference/cache_parquet.md)
for caching the auto-converted Parquet version of a dataset instead.

<https://huggingface.co/docs/huggingface_hub/en/guides/manage-cache>

## Examples

``` r
if (FALSE) { # interactive()
cache_hfhub(
  repo_id   = "scikit-learn/iris",
  file_name = "iris.csv"
)

# Use a cached copy only, without attempting a network request
cache_hfhub(
  repo_id          = "scikit-learn/iris",
  file_name        = "iris.csv",
  local_files_only = TRUE
)
}
```
