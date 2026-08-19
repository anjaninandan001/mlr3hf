# Coerce an HFData Object to an mlr3 Data Backend

Converts an
[HFData](https://anjaninandan001.github.io/mlr3hf/reference/HFData.md)
object into an `mlr3`
[DataBackend](https://mlr3.mlr-org.com/reference/DataBackend.html),
triggering download and parsing of the underlying dataset if this has
not already happened.

## Usage

``` r
# S3 method for class 'HFData'
as_data_backend(data, ...)
```

## Arguments

- data:

  (`HFData`)  
  The `HFData` object to convert.

- ...:

  Additional arguments (currently unused).

## Value

An `mlr3`
[DataBackend](https://mlr3.mlr-org.com/reference/DataBackend.html).
