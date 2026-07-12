test_that("cache_parquet stops when config is NULL", {
    expect_error(
        cache_parquet(repo_id = "scikit-learn/iris", config = NULL),
        "requires config"
    )
})
test_that("cache_parquet errors on invalid split", {
    testthat::local_reproducible_output() #handling ANSI code
    webmockr::stub_request(
        "get",
        "https://datasets-server.huggingface.co/parquet?dataset=scikit-learn/iris"
    ) |>
        webmockr::to_return(
            status = 200,
            body = jsonlite::toJSON(
                list(
                    parquet_files = data.frame(
                        dataset = "scikit-learn/iris",
                        config = "default",
                        split = "train", # only train split exists in scikit-learn/iris
                        filename = "0000.parquet",
                        size = 1234
                    )
                ),
                auto_unbox = TRUE
            ),
            headers = list("Content-Type" = "application/json")
        )

    expect_error(
        cache_parquet(
            repo_id = "scikit-learn/iris",
            config = "default",
            split = "nonexistent"
        ),
        "Split(s) not available: nonexistent. Available: train"
    )
})


test_that("cache_parquet downloads and returns snapshot paths", {
    vcr::local_cassette("cache-parquet-download-full")
    withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

    iris.paths <- cache_parquet(
        repo_id = "scikit-learn/iris",
        config = "default"
    )

    expect_true(is.list(iris.paths))
    expect_true(length(iris.paths) > 0)
    expect_true(all(sapply(unlist(iris.paths), fs::file_exists)))
})

test_that("cache_parquet returns same paths on second call", {
    withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

    vcr::local_cassette("cache-parquet-second-call-fresh")
    iris.paths.fresh <- cache_parquet(
        repo_id = "scikit-learn/iris",
        config = "default"
    )

    vcr::local_cassette("cache-parquet-second-call-cached")
    iris.paths.cached <- cache_parquet(
        repo_id = "scikit-learn/iris",
        config = "default"
    )

    expect_equal(iris.paths.fresh, iris.paths.cached)
})
