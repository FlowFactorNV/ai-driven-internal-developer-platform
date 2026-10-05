output "ovh_access_key_id" {
  value = ovh_cloud_project_user_s3_credential.my_s3_credentials.access_key_id
}

output "ovh_secret_access_key" {
  value     = nonsensitive(ovh_cloud_project_user_s3_credential.my_s3_credentials.secret_access_key)
}
/*output "backend_bucket_name" {
  value = ovh_cloud_project_storage.tf_backend_bucket.name
}
*/
