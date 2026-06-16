test_that("cache_parquet stops when config is NULL", {
    expect_error(
        cache_parquet(repo_id = "scikit-learn/iris", config = NULL),
        "requires config"
    )
})

test_that("cache_parquet errors on invalid config", {
    skip_on_ci()
    skip_if_offline()

    expect_error(
        cache_parquet(repo_id = "scikit-learn/iris", config = "nonexistent"),
        "Config .* not available"
    )
})

test_that("cache_parquet errors on invalid split", {
    skip_on_ci()
    skip_if_offline()

    expect_error(
        cache_parquet(
            repo_id = "scikit-learn/iris",
            config = "default",
            split = "nonexistent"
        ),
        "Split .* not available"
    )
})

test_that("cache_parquet downloads and returns snapshot paths", {
    skip_on_ci()
    skip_if_offline()
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
    skip_on_ci()
    skip_if_offline()
    withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

    iris.paths.fresh <- cache_parquet(
        repo_id = "scikit-learn/iris",
        config = "default"
    )
    iris.paths.cached <- cache_parquet(
        repo_id = "scikit-learn/iris",
        config = "default"
    )

    expect_equal(iris.paths.fresh, iris.paths.cached)
})

test_that("cache_parquet filters by split correctly", {
    skip_on_ci()
    skip_if_offline()
    withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

    iris.train <- cache_parquet(
        repo_id = "scikit-learn/iris",
        config = "default",
        split = "train"
    )

    expect_true(is.list(iris.train))
    expect_true(length(iris.train) == 1) 
    expect_true(!is.null(iris.train[["train"]]))
})
