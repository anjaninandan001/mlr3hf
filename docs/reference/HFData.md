# Hugging Face Dataset Wrapper

An [R6::R6Class](https://r6.r-lib.org/reference/R6Class.html) that wraps
a dataset hosted on the Hugging Face Hub and exposes it as an `mlr3`
compatible data backend / task. Data is loaded lazily: no download or
parsing happens until fields that require access to the underlying data
(e.g. `data`, `nrow`, `ncol`, `colnames`) are accessed for the first
time. Results are then cached for the lifetime of the object.

A dataset can be identified either by a `config` (one of the dataset's
predefined configurations, loaded via its parquet export) or by a single
`file_name` within the repository. Exactly one of the two must be
supplied before data can be retrieved.

All active bindings are read-only; attempting to assign to them raises
an error. See the Fields section below for details on each one.

Note on `clone()`: like every R6 object, `HFData` objects have an
inherited `clone(deep = FALSE)` method for copying the object (`deep`
controls whether nested R6 fields are also cloned). It is not
re-documented here since it isn't defined in this class's source, but
behaves exactly as described in
[R6::R6Class](https://r6.r-lib.org/reference/R6Class.html).

## Active bindings

- `repo_id`:

  (`character(1)`)  
  The Hugging Face repository id, e.g. `"user/dataset"`. Read-only.

- `config`:

  (`character(1)` \| `NULL`)  
  The dataset configuration name, if specified. Read-only.

- `file_name`:

  (`character(1)` \| `NULL`)  
  The specific file name within the repository, if specified. Read-only.

- `split`:

  ([`character()`](https://rdrr.io/r/base/character.html) \| `NULL`)  
  The dataset split (e.g. `"train"`, `"test"`), if specified. Read-only.

- `target`:

  ([`character()`](https://rdrr.io/r/base/character.html) \| `NULL`)  
  The name of the target column. Read-only.

- `desc`:

  ([`list()`](https://rdrr.io/r/base/list.html))  
  The repository description/metadata, downloaded from the Hub on first
  access. Read-only.

- `storage`:

  (`character(1)`)  
  Human-readable size of the storage used by the whole repository (not a
  single file/config). Read-only.

- `data`:

  ([`data.frame()`](https://rdrr.io/r/base/data.frame.html))  
  The full dataset as a data frame. Triggers backend creation on first
  access. Read-only.

- `nrow`:

  (`integer(1)`)  
  Number of rows in the dataset. Read-only.

- `ncol`:

  (`integer(1)`)  
  Number of columns in the dataset. Read-only.

- `colnames`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Column names of the dataset. Read-only.

- `siblings`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  File names of all sibling files in the repository. Read-only.

- `repo_link`:

  (`character(1)`)  
  URL to the dataset page on the Hugging Face Hub. Read-only.

- `configs`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Available dataset configurations, queried from the datasets-server
  API. Read-only.

- `splits`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Available splits for the selected configuration. Read-only.

- `coltypes`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Named vector of the (first) class of each column. Read-only.

- `task_type`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  One of `"auto"`, `"classif"`, or `"regr"`. Read-only.

- `feature_names`:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Column names excluding the target column. Read-only.

## Methods

### Public methods

- [`HFData$new()`](#method-HFData-new)

- [`HFData$print()`](#method-HFData-print)

- [`HFData$clone()`](#method-HFData-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new `HFData` object.

#### Usage

    HFData$new(
      repo_id,
      config = NULL,
      file_name = NULL,
      split = NULL,
      target = NULL,
      primary_key = NULL,
      task_type = c("auto", "classif", "regr"),
      ...
    )

#### Arguments

- `repo_id`:

  (`character(1)`) Repository id on the Hugging Face Hub.

- `config`:

  (`character(1)`\|`NULL`) Dataset configuration name. Defaults to NULL,
  meaning no configuration is selected.

- `file_name`:

  (`character(1)`\|`NULL`) Specific file name within the repository.
  Defaults to NULL, meaning no configuration is selected.

- `split`:

  ([`character()`](https://rdrr.io/r/base/character.html)\|`NULL`)
  Dataset split to load. Defaults to NULL, meaning no configuration is
  selected.

- `target`:

  ([`character()`](https://rdrr.io/r/base/character.html)) Name of the
  target column. Defaults to NULL, meaning no configuration is selected.

- `primary_key`:

  (`character(1)`\|`NULL`) Name of the primary key column. Defaults to
  NULL, meaning no configuration is selected.

- `task_type`:

  (`character(1)`\|`NULL`) One of `"auto"`, `"classif"`, `"regr"`.

- `...`:

  Additional arguments, stored for later use.

#### Returns

A new `HFData` object.

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print a short summary of the `HFData` object, including its dimensions,
target column, and repository storage size.

#### Usage

    HFData$print()

#### Returns

`self`, invisibly (called for its side effect).

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    HFData$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
