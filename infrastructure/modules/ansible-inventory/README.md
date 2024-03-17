# Terraform module for building an Ansible inventory and running Ansible roles

## Summary

This module:
- manages a data structure containing an Ansible inventory
- renders this inventory as an `inventory.yaml`
- locally installs roles and collections from a specified `requirements.yaml` and runs a specified `playbook.yaml` against the generated inventory


## Quickstart

To use this module, consider the following minimal working example:

```
provider "local" {}

module "inventory" {
  source  = "git.atix.de/terraform/ansible-inventory/local"
  version = "~> 3.0"

  from_yaml = [
    <<-EOF
    ---
    all:
      hosts:
        localhost:
    	  ansible_host: "127.0.0.1"
          ansible_user: "root"
      children:
        some_group:
    	  vars:
    	  hosts:
    	    localhost:
    ...
    EOF
  ]

  files_dir = "${path.root}/tmp"
  triggers  = { time = timestamp() }

  requirements = "${path.root}/requirements.yaml"
  playbook     = "${path.root}/playbook.yaml"
}
```

## Documentation

- module inputs are declared and explained in `variables.tf`
- module outputs are declared and explained in `outputs.tf`
- required providers (and their versions) are in `versions.tf`
