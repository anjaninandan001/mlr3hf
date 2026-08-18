test_that("cache_hfhub stops when file_name is NULL", {
    expect_error(
        cache_hfhub(repo_id = "scikit-learn/iris", file_name = NULL),
        "require filename"
    )
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
test_that("cache_hfhub downloads and caches file", {
    vcr::local_cassette("cache-hfhub-iris-fresh")
    withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

    iris.path <- cache_hfhub(
        repo_id = "scikit-learn/iris",
        file_name = "Iris.csv"
    )
    expect_true(fs::file_exists(iris.path))
})

test_that("cache_hfhub returns same path on second call", {
    withr::local_envvar(c("MLR3HF_CACHE_DIR" = withr::local_tempdir()))

    vcr::local_cassette("cache-hfhub-iris-fresh")
    iris.path.fresh <- cache_hfhub(
        repo_id = "scikit-learn/iris",
        file_name = "Iris.csv"
    )

    vcr::local_cassette("cache-hfhub-iris-repeat")
    iris.path.cached <- cache_hfhub(
        repo_id = "scikit-learn/iris",
        file_name = "Iris.csv"
    )

    expect_equal(iris.path.fresh, iris.path.cached)
})

test_that("cache_hfhub handles filenames with subdirectories", {
    repo_id <- "ibm-research/duorc"
    file_name <- "ParaphraseRC/test-00000-of-00001.parquet"
    revision <- "2de12436b8945030c283bf4af83925d60efe10c6"

    path <- cache_hfhub(
        repo_id = repo_id,
        file_name = file_name,
        revision = revision
    )

    expect_true(fs::file_exists(path))

    expect_equal(
        fs::path_file(path),
        "test-00000-of-00001.parquet"
    )

    expect_equal(
        fs::path_file(fs::path_dir(path)),
        "ParaphraseRC"
    )
})
