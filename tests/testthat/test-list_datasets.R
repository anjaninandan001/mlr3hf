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
    expect_type(datasets$gated, "character")
    expect_type(datasets$downloads, "integer")
})
