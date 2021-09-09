# TerraformによるDatabricks Workspace on AWSの環境構築

## 必要な環境

* AWS CLIの実行環境
* AWS Credential(上記のAWS CLIの実行のため)
* Databricks Console([accounts.cloud.databricks.com](https://accounts.cloud.databricks.com/))にログインできるユーザー名/パスワード
* Terraform実行環境


## Terraformテンプレート


Tarraformのテンプレートをダウンロードします。
``` 
$ git 

$ cd databricks_mwc_terraform
$ ls

```

`main.mf`のヘッダ部分にある変数を適宜設定します。

```
$ vim main.mf  (もしくはお使いのテキストエディタで編集)

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

Terraformのの初期化(初回のみ)
```
$ terraform init
```

問題なければTerraformを実行して環境を構築する。
この実行によってAWS上にDatabricksのWorkspaceが構築される。
```
$ terraform apply
```

環境を削除するには以下を実行する(実行には注意してください)
```
$ terraform destroy
```


## 説明

### 変数設定

デプロイする際の設定値を指定していきます。

* `aws_connection_profile`: AWS CLIを使用する際のCredetialのprofile名
* `aws_region`: 構築するAWS Region
* `databricks_account_username`: Databricks Consoleにログインする際のメールアドレス
* `databricks_account_password`: Databricks Consoleにログインする際のパスワード
* `databricks_account_id`: DatabircksアカウントのID (Databricks Consoleから確認できます)
* `cidr_block` : 構築する際のVPCに使用するネットワークCIDR
* `read_write_s3_buckets` : Databricksと連携させるS3バケツのリスト(Read Write)
* `read_only_s3_buckets` : Databricksと連携させるS3バケツのリスト(Read Only)
* `user_prefix`: Workspaceのリソース名で使うプレフィックス文字列



## Reference

* Tarraform 
  - [Provision Databricks workspaces with Terraform (E2)](https://docs.databricks.com/dev-tools/terraform/e2-workspace.html)
  - [Databricks - Terraform Provider (docs in databricks.com)](https://docs.databricks.com/dev-tools/terraform/index.html)
  - [Databricks - Terraform Provider (docs in registry.terraform.io)](https://registry.terraform.io/providers/databrickslabs/databricks/latest/docs)

