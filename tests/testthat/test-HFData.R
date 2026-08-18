test_that("HFData constructor validates input types", {
  expect_error(HFData$new(repo_id = 123), "repo_id")
  expect_error(HFData$new(repo_id = "a/b", config = 123), "config")
  expect_error(HFData$new(repo_id = "a/b", target = 123), "target")
  expect_error(HFData$new(repo_id = "a/b", primary_key = 123), "primary_key")
})

test_that("HFData constructor accepts valid arguments and stores fields", {
  hf <- HFData$new(
    repo_id = "scikit-learn/iris",
    config = "default",
    target = "species"
  )

  expect_equal(hf$repo_id, "scikit-learn/iris")
  expect_equal(hf$config, "default")
  expect_equal(hf$target, "species")
  expect_null(hf$file_name)
})

test_that("HFData task_type defaults to 'auto' and validates choices", {
  hf <- HFData$new(repo_id = "scikit-learn/iris")
  expect_equal(hf$task_type, "auto")

  expect_error(
    HFData$new(repo_id = "scikit-learn/iris", task_type = "invalid_type")
  )
})

test_that("HFData active bindings are read-only", {
  hf <- HFData$new(repo_id = "scikit-learn/iris")
  expect_error(hf$repo_id <- "other/repo")
  expect_error(hf$target <- "y")
})

test_that("HFData errors when both config and file_name are specified", {
  hf <- HFData$new(
    repo_id = "scikit-learn/iris",
    config = "default",
    file_name = "Iris.csv"
  )

  expect_error(
    hf$nrow,
    "Specify only one "
  )
})

test_that("HFData messages when neither config nor file_name is specified", {
  hf <- HFData$new(repo_id = "scikit-learn/iris")

  expect_message(
    tryCatch(hf$nrow, error = function(e) NULL),
    "No dataset configuration or file was specified"
  )
})

test_that("HFData repo_link builds correct URL", {
  hf <- HFData$new(repo_id = "scikit-learn/iris")
  expect_equal(
    hf$repo_link,
    "https://huggingface.co/datasets/scikit-learn/iris"
  )
})

test_that("HFData configs is cached after first access (only one HTTP call)", {
  webmockr::stub_request(
    "get",
    "https://datasets-server.huggingface.co/parquet?dataset=scikit-learn/iris"
  ) |>
    webmockr::to_return(
      status = 200,
      body = jsonlite::toJSON(
        list(parquet_files = data.frame(config = "default")),
        auto_unbox = TRUE
      ),
      headers = list("Content-Type" = "application/json")
    )

  hf <- HFData$new(repo_id = "scikit-learn/iris")

  config_name <- hf$configs
  config_name_cached <- hf$configs

  expect_equal(config_name, config_name_cached)
})

test_that("HFData desc downloads and caches repository metadata", {
  vcr::local_cassette("hfdata-desc-iris")

  hf <- HFData$new(repo_id = "scikit-learn/iris")

  expect_true(is.list(hf$desc))
  expect_true("usedStorage" %in% names(hf$desc))
})

test_that("HFData storage formats bytes into human-readable string", {
  vcr::local_cassette("hfdata-desc-iris")

  hf <- HFData$new(repo_id = "scikit-learn/iris")

  expect_true(grepl("KB|MB|GB|B$", hf$storage))
})

test_that("HFData siblings returns file names from repository", {
  vcr::local_cassette("hfdata-desc-iris")

  hf <- HFData$new(repo_id = "scikit-learn/iris")

  expect_true(is.character(hf$siblings))
  expect_true(length(hf$siblings) > 0)
})

test_that("HFData builds backend via config path and exposes nrow/ncol/colnames", {
  vcr::local_cassette("hfdata-backend-config")
  withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

  hf <- HFData$new(
    repo_id = "scikit-learn/iris",
    config = "default"
  )

  expect_true(hf$nrow > 0)
  expect_true(hf$ncol > 0)
  expect_true(length(hf$colnames) > 0)
})

test_that("HFData splits are populated after backend build via config path", {
  vcr::local_cassette("hfdata-backend-config")
  withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

  hf <- HFData$new(repo_id = "scikit-learn/iris", config = "default")

  expect_true(is.list(hf$splits))
  expect_true(length(hf$splits) > 0)
})

test_that("HFData feature_names excludes the target column", {
  vcr::local_cassette("hfdata-backend-config")
  withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

  hf <- HFData$new(
    repo_id = "scikit-learn/iris",
    config = "default",
    target = "Species"
  )

  expect_false("Species" %in% hf$feature_names)
  expect_true(all(hf$feature_names %in% hf$colnames))
  expect_equal(length(hf$feature_names), length(hf$colnames) - 1)
})

test_that("HFData builds backend via file_name path", {
  vcr::local_cassette("hfdata-backend-filename")
  withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

  hf <- HFData$new(
    repo_id = "scikit-learn/iris",
    file_name = "Iris.csv",
    target = "Species"
  )

  expect_true(hf$nrow > 0)
  expect_true("Species" %in% hf$colnames)
})

test_that("as_task infers regr for numeric target", {
  hf <- HFData$new(repo_id = "scikit-learn/iris", target = "y")

  fake_data <- data.table::data.table(
    x1 = 1:10,
    y = rnorm(10),
    mlr3_row_id = 1:10
  )
  fake_backend <- mlr3::as_data_backend(fake_data, primary_key = "mlr3_row_id")

  priv <- get_private(hf)
  priv$.backend <- fake_backend

  task <- as_task(hf)

  expect_s3_class(task, "TaskRegr")
})
