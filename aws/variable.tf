
variable "aws_connection_profile" {
  description = "The name of the AWS connection profile to use."
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "The code of the AWS Region to use."
  type        = string
  default     = "ap-northeast-1"
}

variable "databricks_connection_profile" {
  description = "The name of the Databricks connection profile to use."
  type        = string
  default     = "DEFAULT"
}


variable "databricks_account_username" {}
variable "databricks_account_password" {
  sensitive = true
}
variable "databricks_account_id" {}

variable "tags" {
  default = {}
}

variable "cidr_block" {
  default = "10.99.0.0/16"
}


variable "read_write_s3_buckets" {
  description = "bucket name list of read_only_access: ex) [\"s3-bucket1\", \"s3-bucket2\"]"
  type        = list(string)
  default     = ["s3-bucket1", "s3-bucket2"]
  #default     = []
}

variable "read_only_s3_buckets" {
  description = "bucket name list of read_only_access: ex) [\"s3-bucket-readonly1\", \"s3-bucket-readonly2\"]"
  type        = list(string)
  #default     = ["s3-bucket-readonly1", "s3-bucket-readonly2"]
  default     = []

}

variable "user_prefix" {
  default = "test123"
}

resource "random_string" "naming" {
  special = false
  upper   = false
  length  = 6
}

locals {
  prefix = "${var.user_prefix}${random_string.naming.result}"
}

