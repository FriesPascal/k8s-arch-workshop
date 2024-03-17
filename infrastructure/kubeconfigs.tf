# ==================== CONFIGURATION ===============================
locals {
  kubeconfigs = merge({
    super-admin = {
      user          = "kubernetes-super-admin"
      group         = "system:masters"
      use_localhost = false
    }
    controller-manager = {
      user          = "system:kube-controller-manager"
      group         = null
      use_localhost = true
    }
    scheduler = {
      user          = "system:kube-scheduler"
      group         = null
      use_localhost = true
    }
    kube-proxy = {
      user          = "system:kube-proxy"
      group         = "system:node-proxier"
      use_localhost = false
    }
    }, {
    for server in hcloud_server.workers : server.name => {
      user          = "system:node:${server.name}"
      group         = "system:nodes"
      use_localhost = false
    }
  })
}


# ====================== ISSUED KUBECONFIGS ===========================
resource "tls_private_key" "kubeconfig_keys" {
  for_each = local.kubeconfigs

  algorithm = "ED25519"
}

resource "tls_cert_request" "kubeconfig_reqs" {
  for_each = local.kubeconfigs

  subject {
    common_name  = each.value.user
    organization = each.value.group
  }

  private_key_pem = tls_private_key.kubeconfig_keys[each.key].private_key_pem
}

resource "tls_locally_signed_cert" "kubeconfig_certs" {
  for_each = local.kubeconfigs

  validity_period_hours = 8760
  cert_request_pem      = tls_cert_request.kubeconfig_reqs[each.key].cert_request_pem
  ca_private_key_pem    = tls_private_key.ca_keys["kubernetes-ca"].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca_certs["kubernetes-ca"].cert_pem
  allowed_uses          = ["client_auth"]
}

resource "local_sensitive_file" "kubeconfigs" {
  for_each = local.kubeconfigs

  filename = "${local.artifacts_path}/kubeconfigs/${each.key}.conf"
  content  = <<EOF
apiVersion: v1
kind: Config
users:
- name: default
  user:
    client-certificate-data: ${base64encode(tls_locally_signed_cert.kubeconfig_certs[each.key].cert_pem)}
    client-key-data: ${base64encode(tls_private_key.kubeconfig_keys[each.key].private_key_pem)} 
clusters:
- name: default
  cluster:
    server: https://${each.value.use_localhost ? "127.0.0.1" : aws_route53_record.a.name}:6443
    certificate-authority-data: ${base64encode(tls_self_signed_cert.ca_certs["kubernetes-ca"].cert_pem)} 
contexts:
- name: default
  context:
    user: default
    cluster: default
current-context: default
EOF
}
