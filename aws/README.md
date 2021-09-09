# TerraformによるDatabricks Workspace on AWSの環境構築

## 必要な環境

* AWS CLIの実行環境
* AWS Credential(上記のAWS CLIの実行のため)
* Databricks Console([accounts.cloud.databricks.com](https://accounts.cloud.databricks.com/))にログインできるユーザー名/パスワード
* Terraform実行環境


## Terraformテンプレート


Tarraformのテンプレートをダウンロードします。
```bash
$ git https://github.com/ktmrmshk/db_terraform_example.git

$ cd db_terraform_example
$ cd aws
$ ls

README.md		variable.tf
main.tf			secret.tfvars.template
```

`variable.tf`のヘッダ部分にある変数を適宜設定します。

```bash
$ vim variable.tf  (もしくはお使いのテキストエディタで編集)

variable "aws_connection_profile" {
  description = "The name of the AWS connection profile to use."
  type = string
  default = "default"
}

variable "aws_region" {
  description = "The code of the AWS Region to use."
  type = string
  default = "ap-northeast-1"
}
...
...
```

続いて、`secret.tfavrs`のテンプレートから以下のDatabricksのアカウント情報を設定ファイルを作成していきます。
パスワードなどを含むファイルになりますので、取り扱いには注意してください。

* `databricks_account_username`: Databricks Consoleにログインする際のメールアドレス
* `databricks_account_password`: Databricks Consoleにログインする際のパスワード
* `databricks_account_id`: DatabircksアカウントのID (Databricks Consoleから確認できます)

```bash
$ cp secret.tfvars.template secret.tfvars
$ vim secret.tfvars  (もしくはお使いのテキストエディタで編集)

databricks_account_username = "your_accout_owner@example.com"
databricks_account_password = "xxxxxxxxxxxxxxxxxxx"
databricks_account_id = "xxxxxxxx-xxxx-xxxxx-xxxxx-xxxxxxxxxxx"
```

以上が設定が必要な項目になりますので、移行はTerraformを実行していきます。

Terraformのの初期化(初回のみ)
```bash
$ terraform init
```

問題なければTerraformを実行して環境を構築します。
この実行によってAWS上にDatabricksのWorkspaceが構築されます。
```bash
$ terraform apply -var-file="secret.tfvars"
```

環境を削除するには以下を実行する(実行には注意してください)
```bash
$ terraform destroy -var-file="secret.tfvars"
```


## 説明

### Variables


デプロイする際の設定値を指定していきます。

`variable.tf`
* `aws_connection_profile`: AWS CLIを使用する際のCredetialのprofile名
* `aws_region`: 構築するAWS Region
* `cidr_block` : 構築する際のVPCに使用するネットワークCIDR
* `read_write_s3_buckets` : Databricksと連携させるS3バケツのリスト(Read Write)
* `read_only_s3_buckets` : Databricksと連携させるS3バケツのリスト(Read Only)
* `user_prefix`: Workspaceのリソース名で使うプレフィックス文字列


### Resources

以下のResourceを構築します。
(手動でデプロイする場合の順に並べてあります)

 1. Cross Account IAM Role
 2. S3 Root Bucket
 3. Custom VPC
 4. Workspace
 5. Bucket for Data writing
 6. Instance Profile for S3 Access from Clusters


## Reference

* Tarraform 
  - [Provision Databricks workspaces with Terraform (E2)](https://docs.databricks.com/dev-tools/terraform/e2-workspace.html)
  - [Databricks - Terraform Provider (docs in databricks.com)](https://docs.databricks.com/dev-tools/terraform/index.html)
  - [Databricks - Terraform Provider (docs in registry.terraform.io)](https://registry.terraform.io/providers/databrickslabs/databricks/latest/docs)

