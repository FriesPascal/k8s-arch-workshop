#
# Define / merge / extend inventories
#
variable "from_yaml" {
  type        = list(string)
  default     = []
  description = <<-EOF
    List of inventory YAMLs to merge. Each inventory has to start with --- (proper YAML).
    YAML maps will be merged up to a depth of 10, where inventories later in the list have
    higher precedence.
    EOF
}


#
# File management
#
variable "files_dir" {
  type        = string
  default     = ""
  description = <<-EOF
    Where should files (inventory.yaml, installed roles, and
    collections) be written to? This path will also be set as the
    root of ANSIBLE_COLLECTIONS_PATH and ANSIBLE_ROLES_PATH. If
    this is empty, no file will be written and ansible-playbook
    will not be executed.
    EOF
}

variable "write_inventory" {
  type        = bool
  default     = true
  description = <<-EOF
    If set to true, an Ansible inventory will be written to file, even
    if no playbook is run.
    EOF
}

variable "requirements" {
  type        = string
  default     = ""
  description = <<-EOF
    Path to an Ansible `requirements.yaml`. Contents of this file will
    be installed to `var.files_dir/roles` and `var.files_dir/collections`.
    If empty, no action is taken.
    EOF
}

variable "playbook" {
  type        = string
  default     = ""
  description = <<-EOF
    Path to an Ansible `playbook.yaml` to run against the rendered
    inventory.
    EOF
}

variable "env" {
  type        = map(string)
  default     = {}
  description = "Environment variables to be set for Ansible."
}

variable "triggers" {
  type        = map(string)
  default     = {}
  description = <<-EOF
    A map of Ansible triggers (in addition to the contents of inventory,
    requirements and playbook). If any of the values in this map change,
    ansible-playbook is rerun.
    EOF
}
