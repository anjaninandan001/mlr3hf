test_that("testing download_desc", {
skip_on_cran()
skip_if_offline()
iris.first.call <- download_desc("scikit-learn/iris")
iris.second.call <- download_desc("scikit-learn/iris")
expect_equal(iris.first.call$downloads, iris.second.call$downloads)
expect_equal(iris.first.call$description, iris.second.call$description)
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
  skip_on_cran()
  skip_if_offline()
  
  iris.first.call <- download_desc("scikit-learn/iris", files_metadata = FALSE)
  iris.second.call <- download_desc("scikit-learn/iris", files_metadata = TRUE)
  
  expect_false(identical(iris.first.call, iris.second.call))
})

test_that("download_desc handles non-existent repo gracefully", {
  skip_on_cran()
  skip_if_offline()
  
  expect_error(
    download_desc("scikit-learn/nonexistentrepo"),
    "Failed to retrieve metadata"
  )
})

test_that("download_desc returns expected fields", {
skip_on_cran()
skip_if_offline()
iris.first.call <- download_desc("scikit-learn/iris")
iris.second.call <- download_desc("scikit-learn/iris")
expect_equal(iris.first.call$usedStorage, 5309549) #this value may change if the dataset is updated
expect_equal(iris.first.call$siblings, iris.second.call$siblings) # these features i.e usedStorage, description and siblings will be used in HFData.R
})