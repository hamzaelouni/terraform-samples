### providers example
## azure resource manager
provider "azurerm" {
  #if i didn't specify the version, tf will download the latest version from tf registry
  version = "3.0"
  features {}
}

provider "aws" {
  version = "4.0"
  region  = "us-east-1"
}