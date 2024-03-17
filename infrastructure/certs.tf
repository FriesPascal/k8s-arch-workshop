# ==================== CONFIGURATION ===============================
locals {
  # these names coincide with the ca common name (CN)
  # ca certs are valid for 10 years
  ca_names = toset([
    "etcd-ca",
    "kubernetes-ca"
  ])

  # the keys of this map coincide with cert common name (CN)
  # issued certs are valid for 1 year
  cert_configs = merge({
    # etcd
    kube-etcd = {
      signed_by    = "etcd-ca"
      organization = null
      dns_names    = ["localhost"]
      ip_addresses = concat([for server in hcloud_server.controlplanes : tolist(server.network)[0].ip], ["127.0.0.1"])
      allowed_uses = [
        "client_auth",
        "server_auth"
      ]
    }
    kube-etcd-peer = {
      signed_by    = "etcd-ca"
      organization = null
      dns_names    = ["localhost"]
      ip_addresses = concat([for server in hcloud_server.controlplanes : tolist(server.network)[0].ip], ["127.0.0.1"])
      allowed_uses = [
        "client_auth",
        "server_auth"
      ]
    }
    # apiserver
    kube-apiserver = {
      signed_by    = "kubernetes-ca"
      organization = null
      dns_names = [
        "kubernetes",
        "kubernetes.default",
        "kubernetes.default.svc",
        "kubernetes.default.svc.cluster",
        "kubernetes.default.svc.cluster.local",
        aws_route53_record.a.name,
        "localhost"
      ]
      ip_addresses = concat(
        [for server in hcloud_server.controlplanes : tolist(server.network)[0].ip],
        ["127.0.0.1", cidrhost(local.service_cidr, 1), local.nat_gateway_ip]
      )
      allowed_uses = ["server_auth"]
    }
    kube-apiserver-etcd-client = {
      signed_by    = "etcd-ca"
      organization = null
      dns_names    = []
      ip_addresses = []
      allowed_uses = ["client_auth"]
    }
    kube-apiserver-kubelet-client = {
      signed_by    = "kubernetes-ca"
      organization = "system:masters"
      dns_names    = []
      ip_addresses = []
      allowed_uses = ["client_auth"]
    }
    }, {
    # kubelet (per node)
    for server in hcloud_server.workers : server.name => {
      signed_by    = "kubernetes-ca"
      organization = null
      dns_names    = [server.name]
      ip_addresses = [tolist(server.network)[0].ip, "127.0.0.1"]
      allowed_uses = ["server_auth"]
    }
  })
}


# =========== SIGNING KEYS FOR SERVICE ACCOUNT TOKENS ===============
resource "tls_private_key" "service_account" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "service_account" {
  subject { common_name = "service-account-keys" }

  validity_period_hours = 87600
  private_key_pem       = tls_private_key.service_account.private_key_pem
  allowed_uses          = ["cert_signing"]
}

resource "local_sensitive_file" "service_account_key" {
  content  = tls_private_key.service_account.private_key_pem
  filename = "${local.artifacts_path}/certs/service-account-key.pem"
}

resource "local_file" "service_account_cert" {
  content  = tls_self_signed_cert.service_account.cert_pem
  filename = "${local.artifacts_path}/certs/service-account-cert.pem"
}


# ====================== CA CERTIFICATES ===========================
resource "tls_private_key" "ca_keys" {
  for_each  = local.ca_names
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "ca_certs" {
  for_each = local.ca_names

  subject { common_name = each.key }

  validity_period_hours = 87600
  is_ca_certificate     = true
  private_key_pem       = tls_private_key.ca_keys[each.key].private_key_pem
  allowed_uses          = ["cert_signing"]
}

resource "local_sensitive_file" "ca_keys" {
  for_each = local.ca_names

  content  = tls_private_key.ca_keys[each.key].private_key_pem
  filename = "${local.artifacts_path}/certs/${each.key}-key.pem"
}

resource "local_file" "ca_certs" {
  for_each = local.ca_names

  content  = tls_self_signed_cert.ca_certs[each.key].cert_pem
  filename = "${local.artifacts_path}/certs/${each.key}-cert.pem"
}


# ====================== ISSUED CERTIFICATES ===========================
resource "tls_private_key" "issued_keys" {
  for_each = local.cert_configs

  algorithm = "ED25519"
}

resource "tls_cert_request" "issued_reqs" {
  for_each = local.cert_configs

  subject {
    common_name  = each.key
    organization = each.value.organization
  }

  dns_names       = each.value.dns_names
  ip_addresses    = each.value.ip_addresses
  private_key_pem = tls_private_key.issued_keys[each.key].private_key_pem
}

resource "tls_locally_signed_cert" "issued_certs" {
  for_each = local.cert_configs

  validity_period_hours = 8760
  cert_request_pem      = tls_cert_request.issued_reqs[each.key].cert_request_pem
  ca_private_key_pem    = tls_private_key.ca_keys[each.value.signed_by].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca_certs[each.value.signed_by].cert_pem
  allowed_uses          = each.value.allowed_uses
}

resource "local_sensitive_file" "issued_keys" {
  for_each = local.cert_configs

  content  = tls_private_key.issued_keys[each.key].private_key_pem
  filename = "${local.artifacts_path}/certs/${each.key}-key.pem"
}

resource "local_file" "issued_certs" {
  for_each = local.cert_configs

  content  = tls_locally_signed_cert.issued_certs[each.key].cert_pem
  filename = "${local.artifacts_path}/certs/${each.key}-cert.pem"
}
