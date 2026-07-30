#' Create an HFData object from a Hugging Face dataset
#'
#' Creates an [`HFData`] object for a dataset hosted on the Hugging Face Hub.
#' The returned object can be converted to an mlr3 task using
#' [mlr3::as_task()] or accessed through its active bindings.
#'
#' @param repo_id (`character(1)`)\cr
#'   Repository ID of the dataset on the Hugging Face Hub,
#'   e.g. `"scikit-learn/iris"` or `"ibm-research/duorc"`.
#'
#' @param config (`character(1)`)\cr
#'   Dataset configuration to load. 
#'
#' @param file_name (`character(1)`)\cr
#'   Path to a specific dataset file within the repository. This can be used
#'   instead of `config` to load a particular file.
#'
#' @param target (`character`)\cr
#'   Name(s) of the target column(s). If `NULL`, the target must be specified
#'   later before converting to an mlr3 task.
#'
#' @param primary_key (`character`)\cr
#'   Name of the column that uniquely identify each observation.
#'
#' @param split (`character(1)`)\cr
#'   Dataset split to load, such as `"train"`, `"test"`, or `"validation"`.
#'   If `NULL`, all available splits are loaded.
#'
#' @param ... Additional arguments passed to [`HFData`].
#'
#' @return An [`HFData`] object.
#'
#' @export
htsk <- function(
    repo_id,
    config = NULL,
    file_name = NULL,
    target = NULL,
    primary_key = NULL,
    split = NULL,
    ...
) {
    HFData$new(
        repo_id = repo_id,
        config = config,
        file_name = file_name,
        target = target,
        primary_key = primary_key,
        split = split,
        ...
    )
}
