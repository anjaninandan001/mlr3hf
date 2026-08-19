# tutorial

## mlr3hf

This tutorial provides a quick overview of the main features of
`mlr3hf`.

If you are not familiar with **Hugging Face**, we recommend reading its
documentation first, as this vignette assumes a basic understanding of
Hugging Face concepts.

The tutorial first introduces the `HFData` object provided by `mlr3hf`.
It then demonstrates how to browse datasets available on Hugging Face
and concludes with a discussion of authentication, caching, and
supported data formats.

### Hugging Face Objects

`mlr3hf` currently supports one object type:

- **`HFData`** represents a Hugging Face dataset together with its
  metadata. It can be converted into an `mlr3` data backend or task,
  allowing the dataset to be used directly within the `mlr3` ecosystem.

Every dataset on Hugging Face has a unique repository identifier
(`repo_id`), which can be used to retrieve it.

#### Data

Like other `mlr3` packages, `mlr3hf` provides both R6 constructors and
convenient sugar functions for creating objects.

``` r
library(mlr3hf)
library(mlr3)

hf_data_parquet = hfdt(
  repo_id = "scikit-learn/iris",
  config = "default",
  target = "Species",
  task_type = "classif",
  primary_key = "Id"
)

hf_data_hfhub = hfdt(
  repo_id = "scikit-learn/iris",
  file_name = "Iris.csv",
  target = "Species",
  task_type="classif",
  primary_key="Id"
)
```

- **Note**: primary_key is optional. If not specified, a new column
  named `mlr3_row_id` is generated automatically and used as the row
  identifier. it is in backend but excluded from the task’s feature
  columns. \### Arguments

Not all arguments are required simultaneously. The following rules
apply:

- `repo_id` and `target` are required.
- `config` and `file_name` are mutually exclusive — only one of the two
  may be specified.
- `task_type` is optional and defaults to `"auto"`. But specifying it
  explicitly is recommended, as it allows `mlr3hf` to create the correct
  type of `mlr3` task (classification or regression) when converting the
  dataset.
- All other arguments are optional.

| Argument      | Description                                                                                                                                                                                                                                                                                                                            |
|---------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `repo_id`     | The repository identifier on Hugging Face, typically of the form `owner_name/repo_name`.                                                                                                                                                                                                                                               |
| `config`      | The name of the configuration (subset) available within the repository. This refers to the `refs/convert/parquet` branch of the dataset, where configurations are split into train, test, and validation sets.                                                                                                                         |
| `file_name`   | The path or name of a file to retrieve directly from the dataset repository. If the file is located at the root of the repository, only the filename is required. This downloads the canonical version of the dataset — i.e., the original file (CSV, TSV, Parquet, etc.) as uploaded to Hugging Face, without any Parquet conversion. |
| `target`      | The name of the target feature to be predicted (the output/label column).                                                                                                                                                                                                                                                              |
| `primary_key` | The name of an existing column to use as the row identifier. If `NULL` (the default), a new column named `mlr3_row_id` is generated automatically. In either case, this column remains part of the backend but is excluded from the task’s feature columns.                                                                            |
| `task_type`   | The type of task to create: `"classif"` for classification or `"regr"` for regression.                                                                                                                                                                                                                                                 |
| `revision`    | The revision of the dataset to use. It may be a branch name, tag, or commit hash.                                                                                                                                                                                                                                                      |

#### Active Bindings

`HFData` provides several active bindings for convenient access to the
dataset and its metadata:

| Binding         | Description                                                            |
|-----------------|------------------------------------------------------------------------|
| `nrow`          | Number of rows in the dataset.                                         |
| `ncol`          | Number of columns in the dataset.                                      |
| `repo_link`     | URL to the dataset repository on Hugging Face.                         |
| `desc`          | Repository description, including siblings, configs, and tags.         |
| `storage`       | Storage information for the repository.                                |
| `configs`       | All configurations available in the repository.                        |
| `siblings`      | All filenames contained in the repository.                             |
| `data`          | The loaded dataset.                                                    |
| `colnames`      | Names of all columns in the dataset.                                   |
| `splits`        | Available data splits (`train`, `test`, `validation`) as row ID lists. |
| `coltypes`      | The data type of each column.                                          |
| `feature_names` | Column names excluding the target column.                              |

These bindings can be accessed directly on an `HFData` object:

``` r
hf_data_parquet$data
```

    ## Key: <Id>
    ##         Id SepalLengthCm SepalWidthCm PetalLengthCm PetalWidthCm        Species
    ##      <int>         <num>        <num>         <num>        <num>         <char>
    ##   1:     1           5.1          3.5           1.4          0.2    Iris-setosa
    ##   2:     2           4.9          3.0           1.4          0.2    Iris-setosa
    ##   3:     3           4.7          3.2           1.3          0.2    Iris-setosa
    ##   4:     4           4.6          3.1           1.5          0.2    Iris-setosa
    ##   5:     5           5.0          3.6           1.4          0.2    Iris-setosa
    ##  ---                                                                           
    ## 146:   146           6.7          3.0           5.2          2.3 Iris-virginica
    ## 147:   147           6.3          2.5           5.0          1.9 Iris-virginica
    ## 148:   148           6.5          3.0           5.2          2.0 Iris-virginica
    ## 149:   149           6.2          3.4           5.4          2.3 Iris-virginica
    ## 150:   150           5.9          3.0           5.1          1.8 Iris-virginica

``` r
hf_data_parquet$nrow
```

    ## [1] 150

``` r
hf_data_parquet$coltypes
```

    ##            Id SepalLengthCm  SepalWidthCm PetalLengthCm  PetalWidthCm 
    ##     "integer"     "numeric"     "numeric"     "numeric"     "numeric" 
    ##       Species 
    ##   "character"

Note that `hf_data_parquet` is an object of class `R6`/`HFData`.

The dataset can be converted to an
[`mlr3::DataBackend`](https://mlr3.mlr-org.com/reference/DataBackend.html).

``` r
backend = as_data_backend(hf_data_parquet)
backend
```

    ## 
    ## ── <DataBackendDataTable> (150x6) ──────────────────────────────────────────────
    ##     Id SepalLengthCm SepalWidthCm PetalLengthCm PetalWidthCm     Species
    ##  <int>         <num>        <num>         <num>        <num>      <char>
    ##      1           5.1          3.5           1.4          0.2 Iris-setosa
    ##      2           4.9          3.0           1.4          0.2 Iris-setosa
    ##      3           4.7          3.2           1.3          0.2 Iris-setosa
    ##      4           4.6          3.1           1.5          0.2 Iris-setosa
    ##      5           5.0          3.6           1.4          0.2 Iris-setosa
    ##      6           5.4          3.9           1.7          0.4 Iris-setosa
    ## [...] (144 rows omitted)

Since Hugging Face datasets do not define a prediction target, the
target column must be specified when creating an `mlr3` task.

``` r
task = as_task(hf_data_parquet)
task
```

    ## 
    ## ── <TaskClassif> (150x5) ───────────────────────────────────────────────────────
    ## • Target: Species
    ## • Target classes: Iris-setosa (33%), Iris-versicolor (33%), Iris-virginica
    ## (33%)
    ## • Properties: multiclass
    ## • Features (4):
    ##   • dbl (4): PetalLengthCm, PetalWidthCm, SepalLengthCm, SepalWidthCm

Once converted, the backend or task can be used with the complete `mlr3`
ecosystem.

``` r
rr = resample(
  task,
  lrn("classif.rpart"),
  rsmp("holdout")
)
```

### `hfdt()` and `htsk()`

`mlr3hf` provides two complementary entry points for working with
Hugging Face datasets:

- **[`hfdt()`](https://anjaninandan001.github.io/mlr3hf/reference/hfdt.md)**
  constructs an `HFData` object, giving access to the dataset itself
  along with its metadata (via the active bindings described above)
  before converting it into an `mlr3` task.
- **`htsk()`** is a convenience function that skips the intermediate
  `HFData` object and returns an
  [`mlr3::Task`](https://mlr3.mlr-org.com/reference/Task.html) directly.

Use
[`hfdt()`](https://anjaninandan001.github.io/mlr3hf/reference/hfdt.md)
when you need to inspect or work with the dataset and its metadata
first; use `htsk()` when you only need the resulting task.

### Working with `hfdt()`

An `HFData` object can be converted directly into an
[`mlr3::Task`](https://mlr3.mlr-org.com/reference/Task.html).

``` r
hf_data = hfdt(
  repo_id = "scikit-learn/iris",
  config = "default",
  target = "Species",
  task_type = "classif",
  primary_key = "Id"
)
```

The underlying dataset can be accessed using:

``` r
hf_data$data
```

    ## Key: <Id>
    ##         Id SepalLengthCm SepalWidthCm PetalLengthCm PetalWidthCm        Species
    ##      <int>         <num>        <num>         <num>        <num>         <char>
    ##   1:     1           5.1          3.5           1.4          0.2    Iris-setosa
    ##   2:     2           4.9          3.0           1.4          0.2    Iris-setosa
    ##   3:     3           4.7          3.2           1.3          0.2    Iris-setosa
    ##   4:     4           4.6          3.1           1.5          0.2    Iris-setosa
    ##   5:     5           5.0          3.6           1.4          0.2    Iris-setosa
    ##  ---                                                                           
    ## 146:   146           6.7          3.0           5.2          2.3 Iris-virginica
    ## 147:   147           6.3          2.5           5.0          1.9 Iris-virginica
    ## 148:   148           6.5          3.0           5.2          2.0 Iris-virginica
    ## 149:   149           6.2          3.4           5.4          2.3 Iris-virginica
    ## 150:   150           5.9          3.0           5.1          1.8 Iris-virginica

The feature names are available through the following (this is only
produced if a target is specified):

``` r
hf_data$feature_names
```

    ## [1] "Id"            "SepalLengthCm" "SepalWidthCm"  "PetalLengthCm"
    ## [5] "PetalWidthCm"

If the dataset provides predefined train, validation, or test splits,
they can be accessed using:

``` r
hf_data$splits
```

    ## $train
    ##   [1]   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18
    ##  [19]  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35  36
    ##  [37]  37  38  39  40  41  42  43  44  45  46  47  48  49  50  51  52  53  54
    ##  [55]  55  56  57  58  59  60  61  62  63  64  65  66  67  68  69  70  71  72
    ##  [73]  73  74  75  76  77  78  79  80  81  82  83  84  85  86  87  88  89  90
    ##  [91]  91  92  93  94  95  96  97  98  99 100 101 102 103 104 105 106 107 108
    ## [109] 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126
    ## [127] 127 128 129 130 131 132 133 134 135 136 137 138 139 140 141 142 143 144
    ## [145] 145 146 147 148 149 150

The object can then be converted into an `mlr3` task:

``` r
task = as_task(hf_data)
task
```

    ## 
    ## ── <TaskClassif> (150x5) ───────────────────────────────────────────────────────
    ## • Target: Species
    ## • Target classes: Iris-setosa (33%), Iris-versicolor (33%), Iris-virginica
    ## (33%)
    ## • Properties: multiclass
    ## • Features (4):
    ##   • dbl (4): PetalLengthCm, PetalWidthCm, SepalLengthCm, SepalWidthCm

### Datasets with Predefined Splits

Many Hugging Face datasets provide predefined `train`, `test`, and
optionally `validation` splits. These splits are available through the
`$splits` field of the `HFData` object as vectors of row IDs, allowing
them to be reused directly in `mlr3` workflows.

``` r
library(mlr3learners)

hf_data = hfdt(
  repo_id = "a4n9i/scikit_iris",
  config = "default",
  target = "Species",
  task_type= "classif"
)

task = as_task(hf_data)

train_row_id = hf_data$splits$train
test_row_id  = hf_data$splits$test
```

The predefined train and test splits can be passed directly to
`ResamplingCustom`, allowing the original dataset split to be reused
instead of generating a new one.

``` r
resampling = rsmp("custom")

resampling$instantiate(
  task,
  train_sets = list(train_row_id),
  test_sets = list(test_row_id)
)

resampling
```

    ## 
    ## ── <ResamplingCustom> : Custom Splits ──────────────────────────────────────────
    ## • Iterations: 1
    ## • Instantiated: TRUE
    ## • Parameters: list()

The resulting resampling object can be used like any other `mlr3`
resampling strategy.

``` r
rr = resample(
  task,
  lrn("classif.rpart"),
  resampling
)

rr$aggregate()
```

    ## classif.ce 
    ##  0.6333333

#### Using a Validation Split

Some Hugging Face datasets also provide a predefined validation split.
This split can be attached to the training task and used by learners
that support internal validation, such as `classif.xgboost`, for early
stopping or monitoring validation performance.

Extract the predefined row IDs:

``` r
train_ids = hf_data$splits$train
valid_ids = hf_data$splits$validation
test_ids  = hf_data$splits$test
```

Create the training task:

``` r
tsk_train = task$clone(deep = TRUE)
tsk_train$filter(train_ids)
```

Create the validation task:

``` r
tsk_train$internal_valid_task = valid_ids
```

Create the learner:

``` r
lrn = lrn("classif.xgboost")
```

Configure the learner to use the predefined validation task:

``` r
lrn$validate = "predefined"

lrn$param_set$set_values(
  nrounds = 500,
  early_stopping_rounds = 10,
  eval_metric = "mlogloss"
)
```

Train the learner:

``` r
lrn$train(tsk_train)
```

Inspect the validation score:

``` r
lrn$internal_valid_scores
```

    ## $mlogloss
    ## [1] 13.82791

Finally, evaluate the trained model on the predefined test split.

``` r
tsk_test = task$clone(deep = TRUE)
tsk_test$filter(test_ids)

pred = lrn$predict(tsk_test)

pred$score(msr("classif.ce"))
```

    ## classif.ce 
    ##  0.6333333

The validation task is only used by learners supporting the
`"validation"` property. Learners such as `classif.rpart` ignore
`internal_valid_task`, whereas learners such as `classif.xgboost` use it
for internal validation and early stopping. \## Using
[`tsk()`](https://mlr3.mlr-org.com/reference/mlr_sugar.html)

In addition to `HFData` and the sugar function
[`hfdt()`](https://anjaninandan001.github.io/mlr3hf/reference/hfdt.md),
`mlr3hf` allows Hugging Face datasets to be created directly using
`mlr3`’s standard
[`tsk()`](https://mlr3.mlr-org.com/reference/mlr_sugar.html) interface
by providing the required dataset parameters.

``` r
task = tsk("hf", repo_id = "scikit-learn/iris", config = "default", target = "Species",task_type="classif")
task
```

    ## 
    ## ── <TaskClassif> (150x6) ───────────────────────────────────────────────────────
    ## • Target: Species
    ## • Target classes: Iris-setosa (33%), Iris-versicolor (33%), Iris-virginica
    ## (33%)
    ## • Properties: multiclass
    ## • Features (5):
    ##   • dbl (5): Id, PetalLengthCm, PetalWidthCm, SepalLengthCm, SepalWidthCm

Since `tsk("hf", ...)` is registered like any other task generator in
`mlr3`, it integrates directly with the rest of the `mlr3` ecosystem —
for example, it can be used immediately with
[`resample()`](https://mlr3.mlr-org.com/reference/resample.html),
[`benchmark()`](https://mlr3.mlr-org.com/reference/benchmark.html), or
any learner without additional conversion steps.

``` r
rr = resample(
  task,
  lrn("classif.rpart"),
  rsmp("holdout")
)

rr$aggregate()
```

    ## classif.ce 
    ##          0

### Listing Datasets

The
[`list_datasets()`](https://anjaninandan001.github.io/mlr3hf/reference/list_datasets.md)
function retrieves datasets available on Hugging Face.

The returned datasets can be filtered by search term, author, and the
number of results to retrieve. Internally, the function uses the Hugging
Face cursor API to fetch additional pages of results when required.

The main arguments are:

- `num_of_dataset`: Number of datasets to return (default: `100`).
- `chunk_size`: Number of datasets retrieved per API request (default:
  `100`).
- `search`: Search term used to filter datasets.
- `author`: Filter datasets by author.

``` r
list_hf_data = list_datasets(
  num_of_dataset = 5,
  search = "machine learning"
)

list_hf_data
```

    ##                                                                              id
    ##                                                                          <char>
    ## 1:                                          shwetha729/quantum-machine-learning
    ## 2: autoevaluate/autoeval-eval-hendrycks_test-machine_learning-af1921-2535877708
    ## 3:                                            joey234/mmlu-machine_learning-neg
    ## 4:                                    joey234/mmlu-machine_learning-neg-prepend
    ## 5:                             joey234/mmlu-machine_learning-verbal-neg-prepend
    ##     gated downloads
    ##    <lgcl>     <int>
    ## 1:  FALSE        13
    ## 2:  FALSE         3
    ## 3:  FALSE        17
    ## 4:  FALSE        19
    ## 5:  FALSE        13

### API Authentication

Authentication is required when accessing private or gated datasets.

`mlr3hf` looks for an authentication token in the following order:

1.  `options(mlr3hf.hf_token = "...")`
2.  `HF_TOKEN`
3.  `HUGGING_FACE_HUB_TOKEN`

An access token can be obtained from the Hugging Face account settings.

``` r
options(mlr3hf.hf_token = "your_api_token")

Sys.setenv(HF_TOKEN = "your_api_token")

Sys.setenv(HUGGING_FACE_HUB_TOKEN = "your_api_token")
```

### Caching

Downloaded datasets are automatically cached on the local machine to
avoid repeated downloads.

By default, the cache directory is:

``` text
~/.cache/huggingface/
```

A different cache location can be specified using:

``` r
options(
  mlr3hf.cache_dir = "path/to/cache/directory"
)
```

### Supported Data Formats

`mlr3hf` supports two methods for loading datasets:

- **Parquet datasets**, which are automatically generated by the Hugging
  Face Datasets library and provide efficient, column-oriented storage
  suitable for large datasets.

- **Canonical dataset files**, such as CSV, TSV, or other files stored
  directly in a dataset repository.

Depending on the arguments supplied, `mlr3hf` automatically selects the
appropriate loading strategy: if `repo_id`, `config`, and `target` are
specified, the Parquet dataset is downloaded; if `repo_id`, `file_name`,
and `target` are specified, the canonical (original) dataset file is
downloaded instead.

**For more information on data backends, see the corresponding
[section](https://mlr3book.mlr-org.com/chapters/chapter10/advanced_technical_aspects_of_mlr3.html#sec-backends)
in the `mlr3book`.**
