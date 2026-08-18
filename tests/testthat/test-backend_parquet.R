test_that("nano_parquet reads single file and creates backend", {
  parquet.path <- withr::local_tempfile(fileext = ".parquet")
  nanoparquet::write_parquet(
    data.frame(x = 1:3, y = c("a", "b", "c")),
    parquet.path
  )

  result <- nano_parquet(list(train = parquet.path))

  expect_true(inherits(result$backend, "DataBackend"))
  expect_true(is.list(result$splits))
  expect_equal(result$backend$nrow, 3)
})

test_that("nano_parquet combines multiple splits correctly", {
  train.path <- withr::local_tempfile(fileext = ".parquet")
  test.path <- withr::local_tempfile(fileext = ".parquet")

  nanoparquet::write_parquet(data.frame(x = 1:3), train.path)
  nanoparquet::write_parquet(data.frame(x = 4:5), test.path)

  result <- nano_parquet(list(train = train.path, test = test.path))

  expect_true(inherits(result$backend, "DataBackend"))
  expect_equal(result$backend$nrow, 5) # 3 + 2 rows combined
  expect_true(all(c("train", "test") %in% names(result$splits)))
})

test_that("nano_parquet auto-generates mlr3_row_id when primary_key is NULL", {
  parquet.path <- withr::local_tempfile(fileext = ".parquet")
  nanoparquet::write_parquet(data.frame(x = 1:4), parquet.path)

  result <- nano_parquet(list(train = parquet.path))

  expect_equal(result$backend$primary_key, "mlr3_row_id")
})

test_that("nano_parquet uses custom primary_key when provided", {
  parquet.path <- withr::local_tempfile(fileext = ".parquet")
  nanoparquet::write_parquet(
    data.frame(id = 101:104, x = 1:4),
    parquet.path
  )

  result <- nano_parquet(list(train = parquet.path), primary_key = "id")

  expect_equal(result$backend$primary_key, "id")
})

test_that("nano_parquet errors when custom primary_key column doesn't exist", {
  testthat::local_reproducible_output() #handling ANSI code
  parquet.path <- withr::local_tempfile(fileext = ".parquet")
  nanoparquet::write_parquet(data.frame(x = 1:3), parquet.path)

  expect_error(
    nano_parquet(list(train = parquet.path), primary_key = "nonexistent_col"),
    "Column 'nonexistent_col' not found in data"
  )
})

test_that("nano_parquet splits reflect correct primary_key values per split", {
  train.path <- withr::local_tempfile(fileext = ".parquet")
  test.path <- withr::local_tempfile(fileext = ".parquet")

  nanoparquet::write_parquet(data.frame(x = 1:2), train.path)
  nanoparquet::write_parquet(data.frame(x = 3:4), test.path)

  result <- nano_parquet(list(train = train.path, test = test.path))

  expect_equal(result$splits$train, c(1, 2))
  expect_equal(result$splits$test, c(3, 4))
})

test_that("nano_parquet removes internal split column from backend data", {
  train.path <- withr::local_tempfile(fileext = ".parquet")
  nanoparquet::write_parquet(data.frame(x = 1:3), train.path)

  result <- nano_parquet(list(train = train.path))

  expect_false("..split_tmp" %in% result$backend$colnames)
})

test_that("nano_parquet handles columns with different names across splits (fill = TRUE)", {
  train.path <- withr::local_tempfile(fileext = ".parquet")
  test.path <- withr::local_tempfile(fileext = ".parquet")

  nanoparquet::write_parquet(
    data.frame(x = 1:2, extra_col = c("a", "b")),
    train.path
  )
  nanoparquet::write_parquet(data.frame(x = 3:4), test.path)

  result <- nano_parquet(list(train = train.path, test = test.path))

  expect_true("extra_col" %in% result$backend$colnames)
  expect_equal(result$backend$nrow, 4)
})


test_that("nano_parquet backend supports full pipeline + resampling workflow", {
  library(mlr3pipelines)
  data.path <- withr::local_tempfile(fileext = ".parquet")
  nanoparquet::write_parquet(
    data.frame(
      f1 = rnorm(30),
      f2 = c(rnorm(28), NA, NA),
      target = factor(rep(c("yes", "no"), 15))
    ),
    data.path
  )

  result <- nano_parquet(list(all = data.path))

  task <- mlr3::TaskClassif$new(
    id = "full_workflow_test",
    backend = result$backend,
    target = "target"
  )
  task$col_roles$feature <- setdiff(task$col_roles$feature, "mlr3_row_id")

  graph <- mlr3pipelines::po("imputemean") %>>%
    mlr3pipelines::po("learner", learner = mlr3::lrn("classif.rpart"))
  graph_learner <- mlr3pipelines::GraphLearner$new(graph)

  resampling <- mlr3::rsmp("cv", folds = 3)
  rr <- mlr3::resample(task, graph_learner, resampling)

  expect_s3_class(rr, "ResampleResult")
  scores <- rr$score(mlr3::msr("classif.acc"))
  expect_equal(nrow(scores), 3)
  expect_true(all(!is.na(scores$classif.acc)))
})

test_that("nano_parquet splits can be used as a predefined train/test resampling", {
  train.path <- withr::local_tempfile(fileext = ".parquet")
  test.path <- withr::local_tempfile(fileext = ".parquet")

  nanoparquet::write_parquet(
    data.frame(
      x1 = rnorm(15),
      y = factor(rep(c("a", "b"), length.out = 15))
    ),
    train.path
  )
  nanoparquet::write_parquet(
    data.frame(
      x1 = rnorm(5),
      y = factor(rep(c("a", "b"), length.out = 5))
    ),
    test.path
  )

  result <- nano_parquet(list(train = train.path, test = test.path))

  task <- mlr3::TaskClassif$new(
    id = "split_test",
    backend = result$backend,
    target = "y"
  )
  task$col_roles$feature <- setdiff(
    task$col_roles$feature,
    c("mlr3_row_id")
  )

  resampling <- mlr3::rsmp("custom")
  resampling$instantiate(
    task,
    train_sets = list(result$splits$train),
    test_sets = list(result$splits$test)
  )

  learner <- mlr3::lrn("classif.rpart")
  rr <- mlr3::resample(task, learner, resampling)

  expect_s3_class(rr, "ResampleResult")
  expect_equal(rr$resampling$iters, 1)

  predicted <- rr$predictions()[[1]]
  expect_equal(length(predicted$row_ids), length(result$splits$test))
})

test_that("nano_parquet errors when primary_key column cannot be coerced to integer", {
  parquet.path <- withr::local_tempfile(fileext = ".parquet")
  nanoparquet::write_parquet(
    data.frame(id = c("a", "b", "c"), x = 1:3),
    parquet.path
  )

  expect_error(
    nano_parquet(list(train = parquet.path), primary_key = "id"),
    "Primary key column 'id' \\(class: character\\) cannot be safely coerced to integer"
  )
})