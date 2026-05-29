<!-- badges: start -->
  [![R-CMD-check](https://github.com/anjaninandan001/mlr3hf/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/anjaninandan001/mlr3hf/actions/workflows/R-CMD-check.yaml)
  <!-- badges: end -->

After cloning this repo run following command in R terminal.
```r
source("R/defaults.R")
source("R/utils.R")
source("R/cache.R")
source("R/download_hfhub.R")
source("R/download_parquet.R")
result1 <- cached(
  repo_id   = "scikit-learn/iris",
  config = "default",parquet= TRUE, fun=download_parquet
)
result2 <- cached(
  repo_id   = "scikit-learn/iris",
  file_name = "Iris.csv",parquet=FALSE, fun=download_hfhub
)
print(result1)
print(result2)
```

**Output:**
```r
~/.cache/mlr3hf/dataset/scikit-learn/iris/default
~/.cache/mlr3hf/hub/scikit-learn_iris/snapshots/0bda0ce801be0fa2f464ff845a9d5ceae99aad7d/Iris.csv
```
