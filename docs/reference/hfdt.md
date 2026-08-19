# Create an HFData object from a Hugging Face dataset

Creates an
[`HFData`](https://anjaninandan001.github.io/mlr3hf/reference/HFData.md)
object for a dataset hosted on the Hugging Face Hub. The returned object
can be converted to an mlr3 task using
[`mlr3::as_task()`](https://mlr3.mlr-org.com/reference/as_task.html) or
accessed through its active bindings.

## Usage

``` r
hfdt(
  repo_id,
  config = NULL,
  file_name = NULL,
  target = NULL,
  primary_key = NULL,
  split = NULL,
  revision = NULL,
  task_type = c("auto", "classif", "regr"),
  ...
)
```

## Arguments

- repo_id:

  (`character(1)`)  
  Repository ID of the dataset on the Hugging Face Hub, e.g.
  `"scikit-learn/iris"` or `"ibm-research/duorc"`.

- config:

  (`character(1)`\|`NULL`)  
  Dataset configuration to load. If `NULL`, the default configuration is
  used when available.

- file_name:

  (`character(1)`\|`NULL`)  
  Path to a specific dataset file within the repository. This can be
  used instead of `config` to load a particular file.

- target:

  (`character`\|`NULL`)  
  Name(s) of the target column(s). If `NULL`, the target must be
  specified later before converting to an mlr3 task.

- primary_key:

  (`character`\|`NULL`)  
  Name(s) of the column(s) that uniquely identify each observation.

- split:

  (`character(1)`\|`NULL`)  
  Dataset split to load, such as `"train"`, `"test"`, or `"validation"`.
  If `NULL`, all available splits are loaded.

- revision:

  (`character(1)`\|`NULL`)  
  Revision of the dataset to load.

- task_type:

  (`character(1)`)  
  Type of task for the dataset. One of `"auto"`, `"classif"`, or
  `"regr"`. If `"auto"`, the task type is inferred from the target
  column(s).

- ...:

  Additional arguments passed to
  [`HFData`](https://anjaninandan001.github.io/mlr3hf/reference/HFData.md).

## Value

An
[`HFData`](https://anjaninandan001.github.io/mlr3hf/reference/HFData.md)
object.
