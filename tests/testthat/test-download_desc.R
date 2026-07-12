test_that("testing download_desc", {
  vcr::local_cassette("download-desc-iris-basic")

  iris.desc.initial <- download_desc("scikit-learn/iris")
  iris.desc.repeated <- download_desc("scikit-learn/iris")

  expect_equal(iris.desc.initial$downloads, iris.desc.repeated$downloads)
  expect_equal(iris.desc.repeated$description, iris.desc.repeated$description)
})

test_that("download_desc fails on error", {
  local_mocked_bindings(
    GET = function(...) {
      structure(
        list(status_code = 404),
        class = "response"
      )
    },
    http_error = function(...) TRUE,
    status_code = function(...) 404,
    content = function(...) "Not Found",
    .package = "httr"
  )
  expect_error(
    download_desc("scikit-learn/iris"),
    "Failed to retrieve metadata"
  )
})

test_that("files_metadata TRUE and FALSE return different responses", {
  vcr::local_cassette("download-desc-files-metadata-false")
  iris.desc.initial <- download_desc(
    "scikit-learn/iris",
    files_metadata = FALSE
  )

  vcr::local_cassette("download-desc-files-metadata-true")
  iris.desc.repeated <- download_desc(
    "scikit-learn/iris",
    files_metadata = TRUE
  )

  expect_false(identical(iris.desc.initial, iris.desc.repeated))
})

test_that("download_desc handles non-existent repo gracefully", {
  vcr::local_cassette("download-desc-nonexistent-repo")

  expect_error(
    download_desc("scikit-learn/nonexistentrepo"),
    "Failed to retrieve metadata"
  )
})

test_that("download_desc returns expected fields", {
  vcr::local_cassette("download-desc-iris-fields")

  iris.desc.initial <- download_desc("scikit-learn/iris")
  iris.desc.repeated <- download_desc("scikit-learn/iris")

  expect_equal(iris.desc.initial$usedStorage, 5309549) #this value may change if the dataset is updated
  expect_equal(iris.desc.initial$siblings, iris.desc.repeated$siblings)
})
