# Cache a Parquet Export of a Hugging Face Dataset

Downloads and caches the Parquet files for a dataset hosted on the
Hugging Face Hub, using the auto-generated `refs/convert/parquet`
branch. This branch contains a Parquet conversion of the dataset that
Hugging Face maintains automatically, which avoids the need to load the
dataset via its original (often script-based) loading format.

## Usage

``` r
cache_parquet(
  repo_id,
  revision = "refs%2Fconvert%2Fparquet",
  config,
  split = NULL,
  ...
)
```

## Arguments

- repo_id:

  Character string. The repository ID of the dataset on the Hugging Face
  Hub, in the form `"user_id/repo_name"` (e.g.
  `"fancyzhx/amazon_polarity"`).

- revision:

  Character string. A specific commit hash to pin the download to,
  instead of using the latest revision of the `refs/convert/parquet`
  branch. Defaults to `NULL`, which resolves to the most recent commit.

- config:

  Character string. The dataset configuration name. Many datasets expose
  only one configuration, in which case `"default"` can usually be used.
  If unsure, inspect the repository's `refs/convert/parquet` branch on
  the Hub to see the available configuration folders.

- split:

  Character string. The dataset split to cache, such as `"train"`,
  `"test"`, or `"validation"`. If `NULL` (default), all available splits
  for the given configuration are cached.

- ...:

  Additional arguments, reserved for future use.

## Value

A named `list` with one entry per cached split. Each entry is itself a
list containing:

- split:

  Character string giving the split name.

- path:

  Character string giving the local file path where the cached Parquet
  file was saved.

## Details

Files are downloaded from the `refs/convert/parquet` branch maintained
by Hugging Face, not from the dataset's default branch. Large datasets
may be split across multiple Parquet shards; all matching shards for the
requested split are downloaded and cached.

## See also

<https://huggingface.co/docs/datasets-server/en/parquet>

## Examples

``` r
if (FALSE) { # interactive()
cache_parquet(
  repo_id = "scikit-learn/iris",
  config  = "default"
)

cache_parquet(
  repo_id = "fancyzhx/amazon_polarity",
  config  = "amazon_polarity",
  split   = "train"
)
}
```
