terraform {
  backend "s3" {
    bucket = "terraform-state-hp-f71c831f"
    key    = "terraform.tfstate"
    region = "gra"
    endpoints = {
      s3 = "https://s3.gra.io.cloud.ovh.net/"
    }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}


