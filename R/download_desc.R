download_desc<-function(repo_id, revision = "main",...,files_metadata=FALSE){
    base_url<- mlr3hf_parquet_url()
    url<-glue::glue("{base_url}/{repo_id}/revision/{revision}")
    params<-list()
    if(files_metadata){
        params$blobs<-TRUE
    }
    headers <- hub_headers()
    result<-httr::GET(url, httr::add_headers(.headers = headers), query = params)
    if (httr::http_error(result)) {
        cli::cli_abort(c(
            "Failed to retrieve metadata for {repo_id} at revision {revision}",
            "i" = "Status: {httr::status_code(result)}",
            "i" = "Message: {httr::content(result, as = 'text')}"
        ))}
        httr::content(result)
}