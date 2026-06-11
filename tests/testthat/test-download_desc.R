test_that("testing download_desc", {
skip_on_cran()
skip_if_offline()
res1<-download_desc("scikit-learn/iris")
res2<-download_desc("scikit-learn/iris")
expect_equal(res1$downloads, res2$downloads)
expect_equal(res1$description, res2$description)
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
  
  res1 <- download_desc("scikit-learn/iris", files_metadata = FALSE)
  res2 <- download_desc("scikit-learn/iris", files_metadata = TRUE)
  
  expect_false(identical(res1, res2))
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
res1 <- download_desc("scikit-learn/iris")
res2 <- download_desc("scikit-learn/iris")
expect_equal(res1$usedStorage, 5309549) #this value may change if the dataset is updated
expect_equal(res1$siblings,res2$siblings) # these features i.e usedStorage, description and siblings will be used in HFData.R
})