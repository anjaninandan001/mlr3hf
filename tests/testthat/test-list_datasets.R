test_that("list_dataset returns an error when <1 is given as input", {
    skip_on_ci()
    skip_if_offline()

    expect_error(
        list_datasets(-1),
        "Assertion on 'num_of_dataset' failed: Element 1 is not >= 1."
    )
})
test_that("list_dataset column types are as expected", {
    skip_on_ci()
    skip_if_offline()

    datasets <- list_datasets(num_of_dataset = 5)
    expect_type(datasets$id, "character")
    expect_type(datasets$gated, "logical")
    expect_type(datasets$downloads, "integer")
})

test_that("list_datasets merges nrows/ncols when fetch_meta = TRUE", {
  testthat::local_mocked_bindings(
    fetch_dataset_meta = function(ids, max_concurrent = 10, timeout = 30) {
      data.table::data.table(
        id = ids,
        nrows = rep(100L, length(ids)),
        ncols = rep(7L, length(ids))
      )
    }
  )
  vcr::use_cassette("list_datasets_search_machine_learning", {
    result <- list_datasets(
      num_of_dataset = 3,
      search = "machine learning",
      fetch_meta = TRUE
    )
  })
  expect_true(all(c("nrows", "ncols") %in% names(result)))
  expect_true(all(result$nrows == 100L))
  expect_true(all(result$ncols == 7L))
})