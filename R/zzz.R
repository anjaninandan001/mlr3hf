#' @import mlr3misc
#' @importFrom mlr3 as_task
#' @importFrom R6 R6Class
#' @importFrom mlr3 tsk
#' @importFrom mlr3 as_data_backend
#' @importFrom mlr3 as_task TaskClassif TaskRegr
#' @importFrom checkmate assert_string assert_flag assert_count assert_choice assert_character assert_int 
NULL
#' mlr3hf: Hugging Face datasets for mlr3
#'
#' Provides integration between Hugging Face datasets and the
#' \pkg{mlr3} ecosystem. Datasets can be downloaded from the
#' Hugging Face Hub and converted directly into
#' \link[mlr3:Task]{mlr3 Tasks}.
#'
#' @section mlr3 Integration:
#'
#' The package registers the `"hf"` task in
#' `mlr3::mlr_tasks`.
#'
#' ```r
#' task = tsk(
#'   "hf",
#'   repo_id = "scikit-learn/iris",
#'   config = "default",
#'   target = "species"
#' )
#' ```
#'
#' Alternatively, users can create an `HFData` object and convert it
#' using `as_task()`.
#'
#' @section Caching:
#'
#' Downloaded datasets are cached locally to avoid repeated downloads.
#'
#' @section Documentation:
#'
#' See the package vignettes for examples of loading datasets,
#' converting them to mlr3 tasks, and working with large datasets.
#'
#' @docType package
#' @name mlr3hf
"_PACKAGE"

.onLoad <- function(libname, pkgname) {
  mlr3::mlr_tasks$add(
    "hf",
    function(
      repo_id,
      config = NULL,
      file_name = NULL,
      split = NULL,
      target = NULL,
      ...
    ) {
      hf <- HFData$new(
        repo_id = repo_id,
        config = config,
        file_name = file_name,
        split = split,
        target = target
      )
      as_task(hf, ...)
    }
  )
}

leanify_package()
