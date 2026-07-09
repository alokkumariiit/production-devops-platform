terraform {
  backend "s3" {
    bucket        = "alok-terraform-state-2026"
    key           = "dev/terraform.tfstate"
    region        = "ap-south-1"
    encrypt       = true
    use_lockfile  = true
  }
}

# terraform {
#   backend "s3" {
#     bucket         = "alok-terraform-state-2026"
#     key            = "dev/terraform.tfstate"
#     region         = "ap-south-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }