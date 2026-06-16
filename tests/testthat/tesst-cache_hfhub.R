test_that("cache_hfhub stops when file_name is NULL", {
    expect_error(
        cache_hfhub(repo_id = "scikit-learn/iris", file_name = NULL),
        "require filename"
    )
})

test_that("cache_hfhub downloads and caches file", {
    skip_on_ci()
    skip_if_offline()
    withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

    iris.path <- cache_hfhub(
        repo_id = "scikit-learn/iris",
        file_name = "Iris.csv"
    )
    expect_true(fs::file_exists(iris.path))
})

test_that("cache_hfhub returns same path on second call", {
    skip_on_ci()
    skip_if_offline()
    withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

    iris.path.fresh <- cache_hfhub(
        repo_id = "scikit-learn/iris",
        file_name = "Iris.csv"
    )
    iris.path.cached <- cache_hfhub(
        repo_id = "scikit-learn/iris",
        file_name = "Iris.csv"
    )

    expect_equal(iris.path.fresh, iris.path.cached)
})

test_that("cache_hfhub local_files_only errors when file not cached", {
    withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

    expect_error(
        cache_hfhub(
            repo_id = "scikit-learn/iris",
            file_name = "Iris.csv",
            local_files_only = TRUE
        )
    )
})
