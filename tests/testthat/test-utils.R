# normalize_etag tests
test_that("normalize_etag removes quotes and W/", {
    expect_equal(normalize_etag('"W/etag123"'), "etag123")
    expect_equal(normalize_etag('"etag123"'), "etag123")
    expect_equal(normalize_etag('W/etag123'), "etag123")
    expect_equal(normalize_etag('etag123'), "etag123")
    expect_null(normalize_etag(NULL))
})

# repo_folder_name tests
test_that("repo_folder_name converts / to -- and adds datasets-- prefix", {
    expect_equal(
        repo_folder_name("scikit-learn/iris"),
        "datasets--scikit-learn--iris"
    )
})

test_that("repo_folder_name converts : to --", {
    expect_equal(repo_folder_name("user:repo"), "datasets--user--repo")
})

# hub_url tests
test_that("hub_url builds correct dataset url", {
    url <- hub_url(
        repo_id = "scikit-learn/iris",
        filename = "Iris.csv",
        revision = "main"
    )
    expect_equal(
        url,
        "https://huggingface.co/datasets/scikit-learn/iris/resolve/main/Iris.csv"
    )
})

test_that("hub_url uses custom revision", {
    url <- hub_url(
        repo_id = "scikit-learn/iris",
        filename = "Iris.csv",
        revision = "a3c256e4b5d6f7a8b9c0d1e2f3a4b5c6d7e8f9a0"
    )
    expect_true(grepl("a3c256e4b5d6f7a8b9c0d1e2f3a4b5c6d7e8f9a0", url))
})

# get_file_metadata tests
test_that("get_file_metadata returns expected fields", {
    skip_on_ci()
    skip_if_offline()
    url <- "https://huggingface.co/datasets/scikit-learn/iris/resolve/main/Iris.csv"
    metadata <- get_file_metadata(url)
    expect_true(is.list(metadata))
    expect_true(all(
        c(
            "status_code",
            "location",
            "commit_hash",
            "etag",
            "size",
            "error_code",
            "error_message"
        ) %in%
            names(metadata)
    ))
})

test_that("get_file_metadata returns 404 for nonexistent file", {
    skip_on_ci()
    skip_if_offline()
    url <- "https://huggingface.co/datasets/scikit-learn/iris/resolve/main/nonexistent.csv"
    metadata <- get_file_metadata(url)
    expect_equal(metadata$status_code, 404)
})

test_that("get_file_metadata normalizes etag", {
    skip_on_ci()
    skip_if_offline()
    url <- "https://huggingface.co/datasets/scikit-learn/iris/resolve/main/Iris.csv"
    metadata <- get_file_metadata(url)
    expect_false(grepl('"', metadata$etag))
    expect_false(grepl("W/", metadata$etag))
})

# supports_symlinks tests
test_that("supports_symlinks returns a logical value", {
    result <- supports_symlinks(tempdir())
    expect_true(is.logical(result))
})

test_that("supports_symlinks returns TRUE on Unix-like systems", {
    skip_if(.Platform$OS.type == "windows", "Skipping on Windows")
    expect_true(supports_symlinks(tempdir()))
})

test_that("supports_symlinks shows warning when symlinks not supported", {
    storage_folder <- tempdir()
    cache_key <- normalizePath(storage_folder, winslash = "/", mustWork = FALSE)
    if (exists(cache_key, envir = symlink_support_cache)) {
        rm(list = cache_key, envir = symlink_support_cache)
    }
    local_mocked_bindings(
        file.symlink = function(...) FALSE,
        .package = "base"
    )
    expect_warning(supports_symlinks(storage_folder), "Symlinks not supported")
})

# link_or_copy tests
test_that("link_or_copy returns pointer_path when symlinks supported", {
    skip_if(.Platform$OS.type == "windows", "Skipping on Windows")
    blob_path <- tempfile()
    pointer_path <- tempfile()
    file.create(blob_path)
    result <- link_or_copy(blob_path, pointer_path, owned = TRUE, tempdir())
    expect_equal(result, pointer_path)
})

test_that("link_or_copy owned=FALSE copies file and keeps original", {
    blob_path <- tempfile()
    pointer_path <- tempfile()
    file.create(blob_path)
    result <- link_or_copy(blob_path, pointer_path, owned = FALSE, tempdir())
    expect_equal(result, pointer_path)
    expect_true(file.exists(result))
    expect_true(file.exists(blob_path))
})
