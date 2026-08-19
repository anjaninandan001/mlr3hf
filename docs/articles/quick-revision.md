# Quick Revision

## Quick Revision

This vignette provides a quick overview of how to use **mlr3hf**.

Suppose you are working on **neuromorphic computing** and need a dataset
for your machine learning project.

#### Step 1: Search for a Dataset

First, search for relevant datasets on the Hugging Face Hub.

``` r
library(mlr3hf)
library(mlr3)

list_datasets(num_of_datasets = 5, search = "neuromorphic computing")
```

    ##                                                   id  gated downloads
    ##                                               <char> <lgcl>     <int>
    ## 1: Shoriful025/neuromorphic_edge_computing_telemetry  FALSE       244
    ## 2: jason1966/ahsanneural_neuromorphic-computing-logs  FALSE        25

This returns a list of dataset repositories matching your search term.
**Note:** If search dataset can return less that the number of datasets
specified in `num_of_datasets`, it means that there are no more datasets
available for the search term.

#### Step 2: Create an `HFData` Object

Next, create an `HFData` object using a `repo_id` obtained from
[`list_datasets()`](https://anjaninandan001.github.io/mlr3hf/reference/list_datasets.md)
above.

``` r
dt = hfdt(repo_id = "Shoriful025/neuromorphic_edge_computing_telemetry")
```

To retrieve the link to the repository on Hugging Face:

``` r
dt$repo_link
```

    ## [1] "https://huggingface.co/datasets/Shoriful025/neuromorphic_edge_computing_telemetry"

You can also inspect the available dataset configurations and files:

``` r
dt$configs
```

    ## [1] "default"

``` r
dt$siblings
```

    ## [1] ".gitattributes" "main.csv"

#### Step 3: Select a Configuration

Once you know which configuration you want, recreate the object by
specifying it. Here, the configuration is one of the values returned by
`dt$configs` above.

``` r
dt = hfdt(
  repo_id = "Shoriful025/neuromorphic_edge_computing_telemetry",
  config = "default"
)
```

The dataset is downloaded locally, a backend is created, and the dataset
can now be inspected.

To view the column names or load the data:

``` r
dt$colnames
```

    ##  [1] "node_id"                     "timestamp"                  
    ##  [3] "spike_frequency_khz"         "synaptic_weight_mean"       
    ##  [5] "power_consumption_mw"        "inference_latency_ms"       
    ##  [7] "Data_Signal_quality"         "Carrier_frequency_stability"
    ##  [9] "temperature_c"               "thermal_throttling_active"  
    ## [11] "mlr3_row_id"

``` r
dt$data[1:5]
```

    ## Key: <mlr3_row_id>
    ##      node_id            timestamp spike_frequency_khz synaptic_weight_mean
    ##       <char>               <char>               <num>                <num>
    ## 1: NODE-X101 2026-01-23T08:00:01Z               450.2                0.652
    ## 2: NODE-X101 2026-01-23T08:00:02Z               455.8                0.655
    ## 3: NODE-X102 2026-01-23T08:00:03Z               890.4                0.712
    ## 4: NODE-X102 2026-01-23T08:00:04Z               912.1                0.718
    ## 5: NODE-X103 2026-01-23T08:00:05Z               120.5                0.441
    ##    power_consumption_mw inference_latency_ms Data_Signal_quality
    ##                   <num>                <num>               <num>
    ## 1:                 12.4                  1.2                0.98
    ## 2:                 12.8                  1.2                0.97
    ## 3:                 25.6                  0.8                0.94
    ## 4:                 26.2                  0.8                0.92
    ## 5:                  5.2                  4.5                0.99
    ##    Carrier_frequency_stability temperature_c thermal_throttling_active
    ##                          <num>         <num>                    <lgcl>
    ## 1:                       0.999          34.5                     FALSE
    ## 2:                       0.998          34.8                     FALSE
    ## 3:                       0.995          42.1                     FALSE
    ## 4:                       0.992          45.6                     FALSE
    ## 5:                       0.999          31.2                     FALSE
    ##    mlr3_row_id
    ##          <int>
    ## 1:           1
    ## 2:           2
    ## 3:           3
    ## 4:           4
    ## 5:           5

#### Step 4: Create an `mlr3` Task

To create an `mlr3` task, specify a target column — one of the values
returned by `dt$colnames` above.

``` r
task = as_task(
  dt,
  target_names = "temperature_c"
)
```

#### Shortcut: Specify Everything at Once

If you already know the repository, configuration, and target column,
you can create everything directly:

``` r
dt = hfdt(
  repo_id = "Shoriful025/neuromorphic_edge_computing_telemetry",
  config = "default",
  target = "temperature_c"
)

task = as_task(dt)
task
```

    ## 
    ## ── <TaskRegr> (31x10) ──────────────────────────────────────────────────────────
    ## • Target: temperature_c
    ## • Properties: -
    ## • Features (9):
    ##   • dbl (6): Carrier_frequency_stability, Data_Signal_quality,
    ##   inference_latency_ms, power_consumption_mw, spike_frequency_khz,
    ##   synaptic_weight_mean
    ##   • chr (2): node_id, timestamp
    ##   • lgl (1): thermal_throttling_active

Alternatively,
[`tsk()`](https://mlr3.mlr-org.com/reference/mlr_sugar.html) can be used
to create the task directly, without going through an intermediate
`HFData` object:

``` r
task = tsk("hf",
  repo_id = "Shoriful025/neuromorphic_edge_computing_telemetry",
  config = "default",
  target = "temperature_c"
)
task
```

    ## 
    ## ── <TaskRegr> (31x10) ──────────────────────────────────────────────────────────
    ## • Target: temperature_c
    ## • Properties: -
    ## • Features (9):
    ##   • dbl (6): Carrier_frequency_stability, Data_Signal_quality,
    ##   inference_latency_ms, power_consumption_mw, spike_frequency_khz,
    ##   synaptic_weight_mean
    ##   • chr (2): node_id, timestamp
    ##   • lgl (1): thermal_throttling_active

This covers the essential workflow for using `mlr3hf` to search, load,
and convert Hugging Face datasets into `mlr3` tasks.
