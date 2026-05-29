test_that("/ converts slashes to double dashes", {
  result <- repo_folder_name("user/repo")
  expect_equal(result, "user_repo")
})
test_that(": converts colons to double dashes", {
  result <- repo_folder_name("user:repo")
  expect_equal(result, "user_repo")
})

test_that("regex for commit hash", {
  regex <- REGEX_COMMIT_HASH()
  valid <- "a3c256e4b5d6f7a8b9c0d1e2f3a4b5c6d7e8f9a0"
  invalid <- "a3c256e4b5d6f7g8h9i0j1k2l3m4n5o6p7q8r9s0" #characters of wrong length
  expect_true(grepl(regex, valid))    
  expect_false(grepl(regex, invalid)) 
})
test_that("normalize_etag removes quotes and W/", {
  expect_equal(normalize_etag('"W/etag123"'), "etag123")
  expect_equal(normalize_etag('"etag123"'), "etag123")
  expect_equal(normalize_etag('W/etag123'), "etag123")
  expect_equal(normalize_etag('etag123'), "etag123")
  expect_null(normalize_etag(NULL))
})
test_that("get_file_metadata returns expected fields", {
  # This test assumes that the URL is valid and accessible. You may want to mock httr::HEAD for a more controlled test.
  url <- "https://huggingface.co/datasets/scikit-learn/iris/resolve/main/Iris.csv"
  metadata <- get_file_metadata(url)
  expect_true(is.list(metadata))
  expect_true(all(c("status_code", "location", "commit_hash", "etag", "size", "error_code", "error_message") %in% names(metadata)))
})
test_that("get_file_metadata handles errors", {
  url <- "https://huggingface.co/datasets/scikit-learn/iris/resolve/main/nonexistentfile.csv"
  metadata <- get_file_metadata(url)
  expect_true(is.list(metadata))
  expect_equal(metadata$status_code, 404)
})  
test_that("get_file_metadata normalizes etag", {
  url <- "https://huggingface.co/datasets/scikit-learn/iris/resolve/main/Iris.csv"
  metadata <- get_file_metadata(url)
  expect_false(grepl('"', metadata$etag))
  expect_false(grepl('W/', metadata$etag))
})
test_that("supports_symlinks returns a logical value", {
  result <- supports_symlinks(tempdir())
  expect_true(is.logical(result))
})  