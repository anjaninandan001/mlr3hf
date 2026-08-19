# download_desc

it helps in downloading the description

## Usage

``` r
download_desc(repo_id, revision = "main", ..., files_metadata = FALSE)
```

## Arguments

- repo_id:

  repo id of the dataset

- revision:

  revision of the dataset, default is "main"

- ...:

  additional arguments passed to httr::GET

- files_metadata:

  whether to include files metadata, default is FALSE

## Value

list containing description and downloads of the dataset

## Examples

``` r
download_desc("scikit-learn/iris")
#> $`_id`
#> [1] "62b07fc2baa2ce7b3ab338da"
#> 
#> $id
#> [1] "scikit-learn/iris"
#> 
#> $author
#> [1] "scikit-learn"
#> 
#> $sha
#> [1] "0bda0ce801be0fa2f464ff845a9d5ceae99aad7d"
#> 
#> $lastModified
#> [1] "2022-06-20T14:17:01.000Z"
#> 
#> $private
#> [1] FALSE
#> 
#> $gated
#> [1] FALSE
#> 
#> $disabled
#> [1] FALSE
#> 
#> $tags
#> $tags[[1]]
#> [1] "license:cc0-1.0"
#> 
#> $tags[[2]]
#> [1] "size_categories:n<1K"
#> 
#> $tags[[3]]
#> [1] "format:csv"
#> 
#> $tags[[4]]
#> [1] "modality:tabular"
#> 
#> $tags[[5]]
#> [1] "modality:text"
#> 
#> $tags[[6]]
#> [1] "library:datasets"
#> 
#> $tags[[7]]
#> [1] "library:pandas"
#> 
#> $tags[[8]]
#> [1] "library:mlcroissant"
#> 
#> $tags[[9]]
#> [1] "library:polars"
#> 
#> $tags[[10]]
#> [1] "region:us"
#> 
#> 
#> $description
#> [1] "\n\t\n\t\t\n\t\n\t\n\t\tIris Species Dataset\n\t\n\nThe Iris dataset was used in R.A. Fisher's classic 1936 paper, The Use of Multiple Measurements in Taxonomic Problems, and can also be found on the UCI Machine Learning Repository.\nIt includes three iris species with 50 samples each as well as some properties about each flower. One flower species is linearly separable from the other two, but the other two are not linearly separable from each other.\nThe dataset is taken from UCI Machine Learning Repository's… See the full description on the dataset page: https://huggingface.co/datasets/scikit-learn/iris."
#> 
#> $downloads
#> [1] 12437
#> 
#> $likes
#> [1] 12
#> 
#> $cardData
#> $cardData$license
#> [1] "cc0-1.0"
#> 
#> 
#> $siblings
#> $siblings[[1]]
#> $siblings[[1]]$rfilename
#> [1] ".gitattributes"
#> 
#> 
#> $siblings[[2]]
#> $siblings[[2]]$rfilename
#> [1] "Iris.csv"
#> 
#> 
#> $siblings[[3]]
#> $siblings[[3]]$rfilename
#> [1] "README.md"
#> 
#> 
#> $siblings[[4]]
#> $siblings[[4]]$rfilename
#> [1] "database.sqlite"
#> 
#> 
#> 
#> $createdAt
#> [1] "2022-06-20T14:10:10.000Z"
#> 
#> $usedStorage
#> [1] 5309549
#> 
```
