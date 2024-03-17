terraform {
  required_providers {
    aws    = { source = "hashicorp/aws" }
    hcloud = { source = "hetznercloud/hcloud" }
    local  = { source = "hashicorp/local" }
    tls    = { source = "hashicorp/tls" }
  }

  #backend "http" {}
}
