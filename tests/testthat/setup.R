library(vcr)
library(webmockr)
vcr::vcr_configure(
  dir = "fixtures",
  filter_sensitive_data = list("<<hf_token>>" = Sys.getenv("HF_TOKEN"))
)