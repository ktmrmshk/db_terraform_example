
// ========= Providers ==========
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }

    databricks = {
      source  = "databrickslabs/databricks"
      version = "0.3.7"
    }
  }
}


provider "aws" {
  profile = var.aws_connection_profile
  region  = var.aws_region
}

provider "databricks" {
  alias    = "mws"
  host     = "https://accounts.cloud.databricks.com"
  username = var.databricks_account_username
  password = var.databricks_account_password
}


// ======== Resources ==========


// --- 1. Cross Account IAM Role ----

data "databricks_aws_assume_role_policy" "this" {
  external_id = var.databricks_account_id
}

resource "aws_iam_role" "cross_account_role" {
  name               = "${local.prefix}-crossaccount"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  tags               = var.tags
}


data "databricks_aws_crossaccount_policy" "this" {}

resource "aws_iam_role_policy" "this" {
  name   = "${local.prefix}-policy"
  role   = aws_iam_role.cross_account_role.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}

resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  account_id       = var.databricks_account_id
  role_arn         = aws_iam_role.cross_account_role.arn
  credentials_name = "${local.prefix}-creds"
  depends_on       = [aws_iam_role_policy.this]
}





// --- 2. S3 Root Bucket ---

resource "aws_s3_bucket" "root_storage_bucket" {
  bucket = "${local.prefix}-rootbucket"
  acl    = "private"
  versioning {
    enabled = false
  }
  force_destroy = true
  tags = merge(var.tags, {
    Name = "${local.prefix}-rootbucket"
  })
}

resource "aws_s3_bucket_public_access_block" "root_storage_bucket" {
  depends_on = [
    aws_s3_bucket.root_storage_bucket,
    aws_s3_bucket_policy.root_bucket_policy
  ]

  bucket             = aws_s3_bucket.root_storage_bucket.id
  ignore_public_acls = true
}

data "databricks_aws_bucket_policy" "this" {
  bucket = aws_s3_bucket.root_storage_bucket.bucket
}

resource "aws_s3_bucket_policy" "root_bucket_policy" {
  bucket = aws_s3_bucket.root_storage_bucket.id
  policy = data.databricks_aws_bucket_policy.this.json
}

resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  bucket_name                = aws_s3_bucket.root_storage_bucket.bucket
  storage_configuration_name = "${local.prefix}-storage"
}



// ---- 3. Custom VPC -----

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.70.0"

  name = local.prefix
  cidr = var.cidr_block
  azs  = data.aws_availability_zones.available.names
  tags = var.tags

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  create_igw           = true

  public_subnets = [cidrsubnet(var.cidr_block, 3, 0)]
  private_subnets = [cidrsubnet(var.cidr_block, 3, 1),
  cidrsubnet(var.cidr_block, 3, 2)]

  default_security_group_egress = [{
    cidr_blocks = "0.0.0.0/0"
  }]

  default_security_group_ingress = [{
    description = "Allow all internal TCP and UDP"
    self        = true
  }]
}

resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${local.prefix}-network"
  security_group_ids = [module.vpc.default_security_group_id]
  subnet_ids         = module.vpc.private_subnets
  vpc_id             = module.vpc.vpc_id
}





// ---- 4. Workspace ----

resource "databricks_mws_workspaces" "this" {
  provider        = databricks.mws
  account_id      = var.databricks_account_id
  aws_region      = var.aws_region
  workspace_name  = local.prefix
  deployment_name = local.prefix

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
}

// export host to be used by other modules
output "databricks_host" {
  value = databricks_mws_workspaces.this.workspace_url
}

// initialize provider in normal mode
provider "databricks" {
  // in normal scenario you won't have to give providers aliases
  alias = "created_workspace"
  host  = databricks_mws_workspaces.this.workspace_url

  username = var.databricks_account_username
  password = var.databricks_account_password
}

// create PAT token to provision entities within workspace
resource "databricks_token" "pat" {
  provider         = databricks.created_workspace
  comment          = "Terraform Provisioning"
  lifetime_seconds = 86400
}

// export token for integration tests to run on
output "databricks_token" {
  value     = databricks_token.pat.token_value
  sensitive = true
}

provider "databricks" {
  alias = "created_workspace_with_pat"
  host = databricks_mws_workspaces.this.workspace_url
  token =  databricks_token.pat.token_value
}




// ------ 5. Bucket for Data writing --------

resource "aws_s3_bucket" "data_storage_bucket" {
  bucket = "${local.prefix}-data"
  acl    = "private"
  versioning {
    enabled = false
  }
  force_destroy = true
  tags = merge(var.tags, {
    Name = "${local.prefix}-databucket"
  })
}

resource "aws_s3_bucket_public_access_block" "data_storage_bucket" {
  depends_on = [
    aws_s3_bucket.data_storage_bucket,
  ]

  bucket                  = aws_s3_bucket.data_storage_bucket.id
  ignore_public_acls      = true
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
}




// ------- 6. Instance Profile for S3 Access from Cluster


data "aws_iam_policy_document" "assume_role_for_ec2" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "read_write_bucket" {
  count = length(var.read_write_s3_buckets) == 0 ? 0 : 1

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = formatlist("arn:aws:s3:::%s", var.read_write_s3_buckets)
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObjectAcl"
    ]
    resources = formatlist("arn:aws:s3:::%s/*", var.read_write_s3_buckets)
  }
}


data "aws_iam_policy_document" "read_only_bucket" {
  count = length(var.read_only_s3_buckets) == 0 ? 0 : 1

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = formatlist("arn:aws:s3:::%s", var.read_only_s3_buckets)
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = formatlist("arn:aws:s3:::%s/*", var.read_only_s3_buckets)
  }
}



resource "aws_iam_role" "role_for_s3_access" {
  name               = "${local.prefix}-shared-ec2-role-for-s3"
  description        = "Role for shared access"
  assume_role_policy = data.aws_iam_policy_document.assume_role_for_ec2.json
  

  dynamic "inline_policy" {
    for_each = data.aws_iam_policy_document.read_only_bucket
    iterator = ite

    content {
      name   = "read_only_bucket"
      policy = ite.value.json
    }
  }
  
  dynamic "inline_policy" {
    for_each = data.aws_iam_policy_document.read_write_bucket
    iterator = ite
    
    content {
      name   = "read_write_bucket"
      policy = ite.value.json
    }
  }
}

data "aws_iam_policy_document" "pass_role_for_s3_access" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.role_for_s3_access.arn]
  }
}

resource "aws_iam_policy" "pass_role_for_s3_access" {
  name   = "shared-pass-role-for-s3-access"
  path   = "/"
  policy = data.aws_iam_policy_document.pass_role_for_s3_access.json
}



resource "aws_iam_role_policy_attachment" "cross_account" {
  policy_arn = aws_iam_policy.pass_role_for_s3_access.arn
  role       = aws_iam_role.cross_account_role.name
}

resource "aws_iam_instance_profile" "shared" {
  name = "shared-instance-profile"
  role = aws_iam_role.role_for_s3_access.name
}

// export host to be used by other modules
output "databricks_instance_profile" {
  value = aws_iam_instance_profile.shared.arn
}


resource "databricks_instance_profile" "this" {
  provider         = databricks.created_workspace_with_pat
  instance_profile_arn = aws_iam_instance_profile.shared.arn
}



## 
## resource "databricks_cluster" "this" {
##   provider         = databricks.created_workspace
##
##   cluster_name            = "Shared Autoscaling"
##   spark_version           = "6.6.x-scala2.11"
##   node_type_id            = "i3.xlarge"
##   autotermination_minutes = 20
##   autoscale {
##     min_workers = 1
##     max_workers = 5
##   }
##   aws_attributes {
##     instance_profile_arn    = databricks_instance_profile.this.id
##     availability            = "SPOT"
##     zone_id                 = "ap-northeast-1"
##     first_on_demand         = 1
##     spot_bid_price_percent  = 100
##   }
## }
