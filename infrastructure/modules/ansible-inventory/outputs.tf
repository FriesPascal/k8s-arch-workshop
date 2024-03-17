output "yaml" {
  value       = local.yaml
  depends_on  = [null_resource.run_playbook]
  description = "Inventory in YAML format."
}
