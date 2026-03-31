terraform {
  required_version = ">= 1.6"

  required_providers {
    clevercloud = {
      source  = "CleverCloud/clevercloud"
      version = "~> 1.10"
    }
  }
}
