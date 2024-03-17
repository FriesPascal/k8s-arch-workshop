variable "hcloud_token" {
  sensitive   = true
  type        = string
  description = "Token for hcloud project. Needs write access."
}

variable "aws_access_key" {
  sensitive   = true
  type        = string
  description = "AWS access key with write access to the zone atix-training.de."
}

variable "aws_secret_key" {
  sensitive   = true
  type        = string
  description = "AWS secret key with write access to the zone atix-training.de."
}

variable "environment" {
  type        = string
  description = "Part of the name of all generated resources. Set by ATIX pipeline to the branch name."
}

variable "worker_count" {
  type        = number
  default     = 4
  description = "Number of worker nodes to deploy."
}
