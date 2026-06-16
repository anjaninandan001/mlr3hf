mlr3hf_hub_url <- function(){
    getOption("mlr3hf.hub_url",
    Sys.getenv("MLR3HF_HUB_URL", "https://huggingface.co"))
}
mlr3hf_cache_dir <- function(){
    getOption("mlr3hf.cache_dir",
    Sys.getenv("MLR3HF_CACHE_DIR", rappdirs::user_cache_dir("huggingface")))
}

mlr3hf_parquet<- function(){
    getOption("mlr3hf.parquet", TRUE)
}
mlr3hf_parquet_url<- function(){
    getOption("mlr3hf.parquet_url",
    Sys.getenv("MLR3HF_PARQUET_URL", "https://huggingface.co/api/datasets"))
}
mlr3hf_token <- function() {
  token <- getOption("mlr3hf.hf_token", NULL)
  if (!is.null(token) && nzchar(token)) return(token)
# sometimes users use HF_TOKEN and sometimes HUGGING_FACE_HUB_TOKEN, so we check both
  token <- Sys.getenv("HF_TOKEN", unset = "")
  if (nzchar(token)) return(token)

  token <- Sys.getenv("HUGGING_FACE_HUB_TOKEN", unset = "")
  if (nzchar(token)) return(token)
  NULL
}
mlr3hf_retries <- function() {
  getOption("mlr3hf.retries", 3L) 
}
