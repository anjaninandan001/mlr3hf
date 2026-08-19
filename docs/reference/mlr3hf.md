# mlr3hf: Hugging Face datasets for mlr3

Provides integration between Hugging Face datasets and the mlr3
ecosystem. Datasets can be downloaded from the Hugging Face Hub and
converted directly into [mlr3
Tasks](https://mlr3.mlr-org.com/reference/Task.html).

## mlr3 Integration

The package registers the `"hf"` task in
[`mlr3::mlr_tasks`](https://mlr3.mlr-org.com/reference/mlr_tasks.html).

    task = tsk(
      "hf",
      repo_id = "scikit-learn/iris",
      config = "default",
      target = "species"
    )

Alternatively, users can create an `HFData` object and convert it using
[`as_task()`](https://mlr3.mlr-org.com/reference/as_task.html).

## Caching

Downloaded datasets are cached locally to avoid repeated downloads.

## Documentation

See the package vignettes for examples of loading datasets, converting
them to mlr3 tasks, and working with large datasets.

## See also

Useful links:

- <https://anjaninandan001.github.io/mlr3hf/>

## Author

**Maintainer**: Sebastian Fischer
<sebastian.fischer@stat.uni-muenchen.de>

Authors:

- Toby Hocking <toby.hocking@r-project.org>

- Anjani Nandan <anjaninandan599@gmail.com>
