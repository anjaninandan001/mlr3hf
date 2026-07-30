#' @title Hugging Face Dataset Wrapper
#'
#' @description
#' An [R6::R6Class] that wraps a dataset hosted on the Hugging Face Hub and
#' exposes it as an `mlr3` compatible data backend / task. Data is loaded
#' lazily: no download or parsing happens until fields that require access
#' to the underlying data (e.g. `data`, `nrow`, `ncol`, `colnames`) are
#' accessed for the first time. Results are then cached for the lifetime of
#' the object.
#'
#' A dataset can be identified either by a `config` (one of the dataset's
#' predefined configurations, loaded via its parquet export) or by a single
#' `file_name` within the repository. Exactly one of the two must be
#' supplied before data can be retrieved.
#'
#' All active bindings are read-only; attempting to assign to them raises an
#' error. See the Fields section below for details on each one.
#'
#' Note on `clone()`: like every R6 object, `HFData` objects have an
#' inherited `clone(deep = FALSE)` method for copying the object (`deep`
#' controls whether nested R6 fields are also cloned). It is not
#' re-documented here since it isn't defined in this class's source, but
#' behaves exactly as described in [R6::R6Class].
#'
#' @export
#'
HFData <- R6Class(
    "HFData",
    public = list(
        #' @description
        #' Create a new `HFData` object.
        #' @param repo_id (`character(1)`) Repository id on the Hugging Face Hub.
        #' @param config (`character(1)`) Dataset configuration name. Defaults to NULL, meaning no configuration is selected.
        #' @param file_name (`character(1)`) Specific file name within the repository. Defaults to NULL, meaning no configuration is selected.
        #' @param split (`character()`) Dataset split to load. Defaults to NULL, meaning no configuration is selected.
        #' @param target (`character()`) Name of the target column. Defaults to NULL, meaning no configuration is selected.
        #' @param primary_key (`character(1)`) Name of the primary key column. Defaults to NULL, meaning no configuration is selected.
        #' @param task_type (`character(1)`) One of `"auto"`, `"classif"`, `"regr"`.
        #' @param ... Additional arguments, stored for later use.
        #' @return A new `HFData` object.
        initialize = function(
            repo_id,
            config = NULL,
            file_name = NULL,
            split = NULL,
            target = NULL,
            primary_key = NULL,
            task_type = c("auto", "classif", "regr"),
            ...
        ) {
            assert_string(repo_id)
            assert_string(config, null.ok = TRUE)
            assert_string(file_name, null.ok = TRUE)
            assert_character(split, null.ok = TRUE)
            assert_string(target, null.ok = TRUE)
            assert_string(primary_key, null.ok = TRUE)
            private$.repo_id <- repo_id
            private$.config <- config
            private$.file_name <- file_name
            private$.split <- split
            private$.target <- target
            private$.primary_key <- primary_key
            private$.dots <- list(...)
            private$.task_type <- match.arg(task_type)
        },

        #' @description
        #' Print a short summary of the `HFData` object, including its
        #' dimensions, target column, and repository storage size.
        #' @return `self`, invisibly (called for its side effect).
        print = function() {
            catf("<HFData:%s> (%ix%i)", self$repo_id, self$nrow, self$ncol)
            catf(
                " * Storage: %s - This storage is for the whole repository, not for a single file or config",
                self$storage
            )
        }
    ),

    active = list(
        #' @field repo_id (`character(1)`)\cr The Hugging Face repository id, e.g. `"user/dataset"`. Read-only.
        repo_id = function(rhs) {
            assert_ro_binding(rhs)
            private$.repo_id
        },
        #' @field config (`character(1)` | `NULL`)\cr The dataset configuration name, if specified. Read-only.
        config = function(rhs) {
            assert_ro_binding(rhs)
            private$.config
        },
        #' @field file_name (`character(1)` | `NULL`)\cr The specific file name within the repository, if specified. Read-only.
        file_name = function(rhs) {
            assert_ro_binding(rhs)
            private$.file_name
        },
        #' @field split (`character()` | `NULL`)\cr The dataset split (e.g. `"train"`, `"test"`), if specified. Read-only.
        split = function(rhs) {
            assert_ro_binding(rhs)
            private$.split
        },
        #' @field target (`character()` | `NULL`)\cr The name of the target column. Read-only.
        target = function(rhs) {
            assert_ro_binding(rhs)
            private$.target
        },
        #' @field desc (`list()`)\cr The repository description/metadata, downloaded from the Hub on first access. Read-only.
        desc = function(rhs) {
            assert_ro_binding(rhs)
            if (is.null(private$.desc)) {
                private$.desc <- download_desc(private$.repo_id)
            }
            private$.desc
        },
        #' @field storage (`character(1)`)\cr Human-readable size of the storage used by the whole repository (not a single file/config). Read-only.
        storage = function(rhs) {
            assert_ro_binding(rhs)
            if (is.null(private$.storage)) {
                bytes <- self$desc$usedStorage
                private$.storage <- if (bytes >= 1024^3) {
                    sprintf("%.2f GB", bytes / 1024^3)
                } else if (bytes >= 1024^2) {
                    sprintf("%.2f MB", bytes / 1024^2)
                } else if (bytes >= 1024) {
                    sprintf("%.2f KB", bytes / 1024)
                } else {
                    sprintf("%d B", bytes)
                }
            }
            private$.storage
        },
        #' @field data (`data.frame()`)\cr The full dataset as a data frame. Triggers backend creation on first access. Read-only.
        data = function(rhs) {
            assert_ro_binding(rhs)
            backend <- private$.get_backend()
            backend$data(backend$rownames, backend$colnames)
        },
        #' @field nrow (`integer(1)`)\cr Number of rows in the dataset. Read-only.
        nrow = function(rhs) {
            assert_ro_binding(rhs)
            private$.get_backend()$nrow
        },
        #' @field ncol (`integer(1)`)\cr Number of columns in the dataset. Read-only.
        ncol = function(rhs) {
            assert_ro_binding(rhs)
            private$.get_backend()$ncol
        },
        #' @field colnames (`character()`)\cr Column names of the dataset. Read-only.
        colnames = function(rhs) {
            assert_ro_binding(rhs)
            private$.get_backend()$colnames
        },
        #' @field siblings (`character()`)\cr File names of all sibling files in the repository. Read-only.
        siblings = function(rhs) {
            assert_ro_binding(rhs)
            if (is.null(private$.siblings)) {
                private$.siblings <- sapply(self$desc$siblings, function(s) {
                    s$rfilename
                })
            }
            private$.siblings
        },
        #' @field openlink (`character(1)`)\cr URL to the dataset page on the Hugging Face Hub. Read-only.
        openlink = function(rhs) {
            assert_ro_binding(rhs)
            sprintf("https://huggingface.co/datasets/%s", self$repo_id)
        },
        #' @field configs (`character()`)\cr Available dataset configurations, queried from the datasets-server API. Read-only.
        configs = function(rhs) {
            assert_ro_binding(rhs)
            if (is.null(private$.configs)) {
                base_url <- "https://datasets-server.huggingface.co/parquet?dataset="
                api_url <- glue::glue("{base_url}{private$.repo_id}")
                response <- httr::GET(api_url)

                data <- jsonlite::fromJSON(
                    httr::content(response, "text", encoding = "UTF-8"),
                    simplifyDataFrame = TRUE,
                    simplifyVector = TRUE
                )

                parquet_files <- data.frame(
                    config = as.character(data$parquet_files$config)
                )
                private$.configs <- unique(parquet_files$config)
            }
            private$.configs
        },
        #' @field splits (`character()`)\cr Available splits for the selected configuration. Read-only.
        splits = function(rhs) {
            assert_ro_binding(rhs)
            if (is.null(private$.splits)) {
                private$.get_backend()
            }
            private$.splits
        },
        #' @field coltypes (`character()`)\cr Named vector of the (first) class of each column. Read-only.
        coltypes = function(rhs) {
            assert_ro_binding(rhs)
            backend <- private$.get_backend()
            sapply(backend$colnames, function(col) {
                class(backend$data(rows = backend$rownames, cols = col)[[col]])[
                    1
                ]
            })
        },
        #' @field task_type (`character()`)\cr One of `"auto"`, `"classif"`, or `"regr"`. Read-only.
        task_type = function(rhs) {
            assert_ro_binding(rhs)
            private$.task_type
        },
        #' @field feature_names (`character()`)\cr Column names excluding the target column. Read-only.
        feature_names = function(rhs) {
            assert_ro_binding(rhs)
            setdiff(self$colnames, self$target)
        }
    ),

    private = list(
        .repo_id = NULL,
        .config = NULL,
        .file_name = NULL,
        .split = NULL,
        .target = NULL,
        .primary_key = NULL,
        .dots = NULL,
        .desc = NULL,
        .storage = NULL,
        .backend = NULL,
        .siblings = NULL,
        .configs = NULL,
        .splits = NULL,
        .coltypes = NULL,
        .task_type = NULL,

        .get_backend = function() {
            if (!is.null(private$.backend)) {
                return(private$.backend)
            }

            if (is.null(private$.config) && is.null(private$.file_name)) {
                message(paste0(
                    "No dataset configuration or file was specified.\n",
                    "Specify either 'config' or 'file_name':\n",
                    "  config:    HFData$new(repo_id, config = 'default')\n",
                    "  file_name: HFData$new(repo_id, file_name = 'data.csv')\n",
                    "To inspect available options:\n",
                    "  HFData$new(repo_id)$configs\n",
                    "  HFData$new(repo_id)$siblings"
                ))
            }

            if (!is.null(private$.config) && !is.null(private$.file_name)) {
                stopf("Specify only one of 'config' or 'file_name', not both.")
            }

            if (!is.null(private$.config)) {
                path_list <- cache_parquet(
                    private$.repo_id,
                    config = private$.config,
                    split = private$.split
                )
                result <- nano_parquet(
                    path_list,
                    primary_key = private$.primary_key
                )
                private$.backend <- result$backend
                private$.splits <- result$splits
                return(private$.backend)
            }

            if (!is.null(private$.file_name)) {
                path_hfhub <- cache_hfhub(
                    repo_id = private$.repo_id,
                    file_name = private$.file_name
                )
                private$.backend <- backend_hfhub(
                    path_hfhub,
                    primary_key = private$.primary_key
                )
                return(private$.backend)
            }
        }
    )
)

#' @title Coerce an HFData Object to an mlr3 Data Backend
#'
#' @description
#' Converts an [HFData] object into an `mlr3` [DataBackend][mlr3::DataBackend],
#' triggering download and parsing of the underlying dataset if this has not
#' already happened.
#'
#' @param data (`HFData`)\cr The `HFData` object to convert.
#' @param ... Additional arguments (currently unused).
#'
#' @return An `mlr3` [DataBackend][mlr3::DataBackend].
#'
#' @exportS3Method mlr3::as_data_backend
#'

as_data_backend.HFData <- function(data, ...) {
    get_private(data)$.get_backend()
}

#' @title Coerce an HFData Object to an mlr3 Task
#'
#' @description
#' Converts an [HFData] object into an `mlr3` [Task][mlr3::Task], either a
#' [TaskClassif][mlr3::TaskClassif] or a [TaskRegr][mlr3::TaskRegr]. The
#' target column and task type can be taken from the `HFData` object or
#' overridden explicitly.
#'
#' When `task_type = "auto"`, the task type is inferred from the class of
#' the target column: factor and logical columns become classification
#' tasks, numeric and integer columns become regression tasks, and
#' character columns become classification tasks only if they have at most
#' 50 unique values or a unique-value ratio below 10%; otherwise an error is
#' raised asking for an explicit `task_type`.
#'
#' @param x (`HFData`)\cr The `HFData` object to convert.
#' @param target_names (`character()`)\cr Name of the target column. If `NULL`, the `target` stored in `x` is used. Multiple targets are not supported.
#' @param task_type (`character(1)`)\cr One of `"auto"`, `"classif"`, or `"regr"`. Defaults to `"auto"`, in which case the type is inferred from the target column.
#' @param ... Additional arguments (currently unused).
#'
#' @return An [mlr3::TaskClassif] or [mlr3::TaskRegr] object.
#'
#' @exportS3Method mlr3::as_task
#'
as_task.HFData <- function(
    x,
    target_names = NULL,
    task_type = c("auto", "classif", "regr"),
    ...
) {
    task_type <- match.arg(task_type)
    target <- if (!is.null(target_names)) target_names else x$target

    if (length(target) > 1L) {
        stopf(
            "Multiple targets not supported. Got: %s",
            paste0("'", target, "'", collapse = ", ")
        )
    }
    backend <- as_data_backend(x)
    if (!target %in% backend$colnames) {
        stopf("Target '%s' not found in backend.", target)
    }

    col <- backend$data(rows = backend$rownames, cols = target)[[target]]

    if (task_type == "auto") {
        task_type <- if (is.factor(col)) {
            "classif"
        } else if (is.logical(col)) {
            "classif"
        } else if (is.numeric(col) || is.integer(col)) {
            "regr"
        } else if (is.character(col)) {
            n_unique <- length(unique(col))
            n_total <- length(col)
            if (n_unique <= 50 || n_unique / n_total < 0.1) {
                "classif"
            } else {
                stopf(
                    "Target '%s' is character with %d unique values out of %d rows  looks like free text. Please specify task_type explicitly."
                )
            }
        } else {
            stopf(
                "Unable to determine task type for target '%s' (class: %s).",
                target,
                class(col)[1L]
            )
        }
    }

    if (task_type == "classif" && !is.factor(col)) {
        dt <- backend$data(backend$rownames, backend$colnames)
        dt[[target]] <- as.factor(dt[[target]])
        backend <- mlr3::as_data_backend(dt, primary_key = backend$primary_key)
    }

    if (task_type == "classif") {
        mlr3::TaskClassif$new(
            id = x$repo_id,
            backend = backend,
            target = target
        )
    } else {
        mlr3::TaskRegr$new(id = x$repo_id, backend = backend, target = target)
    }
}
