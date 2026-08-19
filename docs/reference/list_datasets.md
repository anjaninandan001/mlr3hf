# List Datasets from Hugging Face Hub

Query datasets hosted on <https://huggingface.co/datasets> via the
Hugging Face Hub API, returning metadata such as dataset id, gated
status, and download counts.

## Usage

``` r
list_datasets(
  num_of_dataset = 100,
  chunk_size = 100,
  search = NULL,
  author = NULL,
  ...
)
```

## Arguments

- num_of_dataset:

  (`integer(1)`)  
  Total number of records to retrieve. Must be a positive integer.
  Default is `100`.

- chunk_size:

  (`integer(1)`)  
  Number of records to request per API call. Default is `100`.

- search:

  (`character(1)`)  
  Optional search keyword to filter datasets by. Default is `NULL`.

- author:

  (`character(1)`)  
  Optional author/organization name to filter datasets by. Default is
  `NULL`.

- ...:

  Additional arguments passed on to `get_with_retry()`, e.g.
  `max_retries`.

## Value

([`data.table()`](https://rdrr.io/pkg/data.table/man/data.table.html))
of results with columns `id`, `gated`, and `downloads`, or an empty
[`data.table()`](https://rdrr.io/pkg/data.table/man/data.table.html) if
no datasets are found.

## References

<https://huggingface.co/docs/hub/api>

\#' @importFrom data.table data.table as.data.table rbindlist

## Examples

``` r
if (FALSE) { # \dontrun{
dat <- list_datasets(num_of_dataset = 50)
dat <- list_datasets(num_of_dataset = 500, chunk_size = 100)
dat <- list_datasets(author = "a4n9i")
} # }
```
