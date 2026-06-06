<!-- badges: start -->
  [![R-CMD-check](https://github.com/anjaninandan001/mlr3hf/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/anjaninandan001/mlr3hf/actions/workflows/R-CMD-check.yaml)
  <!-- badges: end -->

## Getting Started with `mlr3hf`

This package provides utilities for working with Hugging Face datasets. To use it, specify the repository ID, target variable, and whether the dataset is stored as a parquet file.

### Installation

You can install the package using one of the following methods:

#### Option 1: Install from GitHub

```r
# Clone the repository
git clone https://github.com/anjaninandan001/mlr3hf
```

#### Option 2: Install the package directly

```r
install.packages("mlr3hf")
```

### Usage

After installation, load the package and use the available functions:

```r
htsk()
```

For additional details, refer to the package documentation:

```r
help(package = "mlr3hf")
```

### Example

```r
dt <- HFData$new(
  repo_id = "scikit-learn/iris",
  file_name = "Iris.csv",
  parquet = FALSE,
  target = "Species"
)
```

### Output

```r
Wait....results in progress, we are developing
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `repo_id` | Hugging Face dataset repository identifier. |
| `file_name` | Name of the dataset file within the repository. |
| `parquet` | Logical value indicating whether the dataset is stored in parquet format. |
| `target` | Name of the target/dependent variable. |

> **Note:** The package is currently under active development. Some features may be experimental and outputs may change in future releases.