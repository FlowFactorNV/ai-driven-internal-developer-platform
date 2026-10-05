resource "ovh_cloud_project_user" "user" {
  service_name = var.project_id
  description  = "S3 Project User"
  role_names   = [
    "objectstore_operator"
  ]
}

resource "ovh_cloud_project_user_s3_credential" "my_s3_credentials" {
  service_name = ovh_cloud_project_user.user.service_name
  user_id      = ovh_cloud_project_user.user.id
}
resource "ovh_cloud_project_user_s3_policy" "tf_backend_policy" {
  service_name = var.project_id
  user_id      = ovh_cloud_project_user.user.id
  policy       = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = "arn:aws:s3:::terraform-state-hp-f71c831f"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::terraform-state-hp-f71c831f/*"
      }
    ]
  })
}

