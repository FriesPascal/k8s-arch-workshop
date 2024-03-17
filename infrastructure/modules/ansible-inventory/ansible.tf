resource "local_file" "inventory" {
  count = (var.write_inventory || var.playbook != "") && var.files_dir != "" ? 1 : 0

  filename             = "${var.files_dir}/inventory.yaml"
  file_permission      = "0644"
  directory_permission = "0755"
  content              = local.yaml
}

data "local_sensitive_file" "requirements" {
  count    = var.requirements != "" ? 1 : 0
  filename = var.requirements
}

data "local_file" "playbook" {
  count    = var.playbook != "" ? 1 : 0
  filename = var.playbook
}

resource "null_resource" "run_playbook" {
  count = var.files_dir != "" && var.playbook != "" ? 1 : 0

  triggers = merge(var.triggers, {
    requirements = try(nonsensitive(sha256(data.local_sensitive_file.requirements[*].content)), null)
    files_dir    = abspath(var.files_dir)
    env          = jsonencode(var.env)
    inventory    = local.yaml
    playbook     = one(data.local_file.playbook[*].content)
  })

  provisioner "local-exec" {
    environment = merge({
      ANSIBLE_HOST_KEY_CHECKING = false
      ANSIBLE_COLLECTIONS_PATHS = "${abspath(var.files_dir)}/collections"
      ANSIBLE_ROLES_PATH        = "${abspath(var.files_dir)}/roles"
      ANSIBLE_LOG_PATH          = "${abspath(var.files_dir)}/ansible.log"
    }, var.env)

    command = <<-EOF
      %{~if var.requirements != ""~}
      ansible-galaxy install -r ${abspath(var.requirements)}
      %{~endif~}
      ansible-playbook -i ${abspath(local_file.inventory[0].filename)} ${abspath(var.playbook)}
      EOF
  }
}
