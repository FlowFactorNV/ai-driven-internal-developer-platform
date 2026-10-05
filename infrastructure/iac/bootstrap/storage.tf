/*terraform {
    backend "s3" {
      bucket = "terraform-state-hp-f71c831f"
      key    = "terraform.tfstate"
      region = "gra"

      endpoints = {
        s3 = "https://s3.gra.perf.cloud.ovh.net/"
      }
      skip_credentials_validation = true
      skip_region_validation      = true
      skip_requesting_account_id  = true
      skip_s3_checksum            = true
      use_path_style              = true  
    }
}
*/


resource "ovh_cloud_project_storage" "tf_backend_bucket" {
  service_name = "5f7ea35aa8ec48f1b9c89ba2a7d8e703"
  region_name  = "GRA"
  name         = "terraform-state-hp-f71c831f"
}