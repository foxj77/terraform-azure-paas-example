terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "sttfstatesnapvideo001"
    container_name       = "tfstate"
    key                  = "snapvideo/dev/terraform.tfstate"
  }
}