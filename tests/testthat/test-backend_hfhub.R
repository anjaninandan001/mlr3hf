test_that("backend_hfhub reads CSV and creates backend with default primary key", {
  csv.path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(x = 1:3, y = c("a", "b", "c")),
    csv.path,
    row.names = FALSE
  )

  backend <- backend_hfhub(csv.path)

  expect_true(inherits(backend, "DataBackend"))
  expect_true("mlr3_row_id" %in% backend$colnames)
  expect_equal(backend$nrow, 3)
})

test_that("backend_hfhub reads TSV correctly", {
  tsv.path <- withr::local_tempfile(fileext = ".tsv")
  utils::write.table(
    data.frame(x = 1:3, y = c("a", "b", "c")),
    tsv.path,
    sep = "\t",
    row.names = FALSE
  )

  backend <- backend_hfhub(tsv.path)

  expect_true(inherits(backend, "DataBackend"))
  expect_equal(backend$nrow, 3)
})

test_that("backend_hfhub reads Parquet correctly", {
  parquet.path <- withr::local_tempfile(fileext = ".parquet")
  nanoparquet::write_parquet(
    data.frame(x = 1:3, y = c("a", "b", "c")),
    parquet.path
  )

  backend <- backend_hfhub(parquet.path)

  expect_true(inherits(backend, "DataBackend"))
  expect_equal(backend$nrow, 3)
})

test_that("backend_hfhub errors on unsupported file format", {
  txt.path <- withr::local_tempfile(fileext = ".txt")
  writeLines("some text", txt.path)

  expect_error(
    backend_hfhub(txt.path),
    "currently not supporting for your given format: txt"
  )
})

test_that("backend_hfhub uses custom primary_key when provided", {
  csv.path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(id = 101:103, x = 1:3),
    csv.path,
    row.names = FALSE
  )

  backend <- backend_hfhub(csv.path, primary_key = "id")

  expect_true(inherits(backend, "DataBackend"))
  expect_equal(backend$primary_key, "id")
})

test_that("backend_hfhub errors when custom primary_key column doesn't exist", {
  csv.path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(x = 1:3, y = c("a", "b", "c")),
    csv.path,
    row.names = FALSE
  )

  expect_error(
    backend_hfhub(csv.path, primary_key = "nonexistent_col"),
    "not found in data"
  )
})

test_that("backend_hfhub auto-generates mlr3_row_id when primary_key is NULL", {
  csv.path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(x = 1:5),
    csv.path,
    row.names = FALSE
  )

  backend <- backend_hfhub(csv.path)

  expect_equal(backend$primary_key, "mlr3_row_id")
})

test_that("backend_hfhub-created backend works with mlr3 resampling", {
  csv.path <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(
      sepal_length = c(
        5.1,
        4.9,
        4.7,
        4.6,
        5.0,
        5.4,
        4.6,
        5.0,
        4.4,
        4.9,
        6.4,
        6.9,
        5.5,
        6.5,
        5.7,
        6.3,
        4.9,
        6.6,
        5.2,
        5.0
      ),
      species = factor(rep(c("setosa", "versicolor"), each = 10))
    ),
    csv.path,
    row.names = FALSE
  )

  backend <- backend_hfhub(csv.path)
  dt <- backend$data(backend$rownames, backend$colnames)
  dt[["species"]] <- as.factor(dt[["species"]])
  backend <- mlr3::as_data_backend(dt, primary_key = backend$primary_key) #read_csv returns character for factor columns, so we need to convert it back to factor for classification tasks

  task <- mlr3::TaskClassif$new(
    id = "iris_test",
    backend = backend,
    target = "species"
  )
  task$col_roles$feature <- setdiff(task$col_roles$feature, "mlr3_row_id")

  learner <- mlr3::lrn("classif.rpart")
  resampling <- mlr3::rsmp("cv", folds = 3)

  rr <- mlr3::resample(task, learner, resampling)

  expect_s3_class(rr, "ResampleResult")
  expect_equal(rr$resampling$iters, 3)

  scores <- rr$score(mlr3::msr("classif.acc"))
  expect_true(all(scores$classif.acc >= 0 & scores$classif.acc <= 1))
  expect_equal(nrow(scores), 3)
})
