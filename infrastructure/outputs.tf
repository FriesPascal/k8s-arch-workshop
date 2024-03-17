output "name_prefix" {
  value       = local.name_prefix
  description = "All generated cloud resource names have this prefix."
}

output "common_labels" {
  value       = local.common_labels
  description = "All generated cloud resources have these labels."
}

output "dns_record" {
  value       = local.dns_record
  description = "Public DNS (A) record to reach the cluster."
}

output "inventory" {
  value       = module.inventory.yaml
  description = "Rendered inventory with all servers as used by ansible."
}
