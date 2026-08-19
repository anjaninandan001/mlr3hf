# Coerce an HFData Object to an mlr3 Task

Converts an
[HFData](https://anjaninandan001.github.io/mlr3hf/reference/HFData.md)
object into an `mlr3`
[Task](https://mlr3.mlr-org.com/reference/Task.html), either a
[TaskClassif](https://mlr3.mlr-org.com/reference/TaskClassif.html) or a
[TaskRegr](https://mlr3.mlr-org.com/reference/TaskRegr.html). The target
column and task type can be taken from the `HFData` object or overridden
explicitly.

When `task_type = "auto"`, the task type is inferred from the class of
the target column: factor and logical columns become classification
tasks, numeric and integer columns become regression tasks.

## Usage

``` r
# S3 method for class 'HFData'
as_task(x, target_names = NULL, task_type = NULL, ...)
```

## Arguments

- x:

  (`HFData`)  
  The `HFData` object to convert.

- target_names:

  ([`character()`](https://rdrr.io/r/base/character.html))  
  Name of the target column. If `NULL`, the `target` stored in `x` is
  used. Multiple targets are not supported.

- task_type:

  (`character(1)`)  
  One of `"auto"`, `"classif"`, or `"regr"`. Defaults to `"auto"`, in
  which case the type is inferred from the target column.

- ...:

  Additional arguments (currently unused).

## Value

An
[mlr3::TaskClassif](https://mlr3.mlr-org.com/reference/TaskClassif.html)
or [mlr3::TaskRegr](https://mlr3.mlr-org.com/reference/TaskRegr.html)
object.
