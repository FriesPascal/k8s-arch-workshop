# ========================== auth ==========================
# for the sake of simplicity and security:
# - ssh login with passwd auth is disabled, only ssh pubkey auth
# - "root" has no authorized key, root ssh is generally disabled
# - we provide ssh pubkey auth for "atix" user with passwordless sudo
# all of this is setup via cloud-init (see servers section)
resource "tls_private_key" "atix" {
  algorithm = "RSA"
}

resource "local_sensitive_file" "ssh_private_key_atix" {
  content  = tls_private_key.atix.private_key_openssh
  filename = "${local.artifacts_path}/atix"
}

resource "local_file" "ssh_public_key_atix" {
  content  = tls_private_key.atix.public_key_openssh
  filename = "${local.artifacts_path}/atix.pub"
}

# ================= private networking ==========================
resource "hcloud_network" "this" {
  name     = local.name_prefix
  ip_range = local.network_cidr
  labels   = local.common_labels
}

resource "hcloud_network_subnet" "this" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = local.subnet_cidr
}

resource "hcloud_network_route" "default_nat_gateway" {
  network_id  = hcloud_network.this.id
  destination = "0.0.0.0/0"
  gateway     = local.nat_gateway_ip
}

# in order to route pod traffic, we need to set up proper routing
# for packages at the cloud level
resource "hcloud_network_route" "cni" {
  count = var.worker_count

  network_id  = hcloud_network.this.id
  destination = local.local_pod_cidrs[hcloud_server.workers[count.index].name]
  gateway     = tolist(hcloud_server.workers[count.index].network)[0].ip
}


# ================= public networking ==========================
# we prepare a public ipv4 for the nat gateway and set up dns for it
data "aws_route53_zone" "this" {
  name = "atix-training.de"
}

resource "hcloud_primary_ip" "this" {
  name          = local.name_prefix
  type          = "ipv4"
  datacenter    = local.datacenter
  auto_delete   = false
  assignee_type = "server"
}

resource "aws_route53_record" "a" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.dns_record
  type    = "A"
  ttl     = "300"
  records = [hcloud_primary_ip.this.ip_address]
}

resource "aws_route53_record" "cname" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "*.${local.dns_record}."
  type    = "CNAME"
  ttl     = "300"
  records = ["${local.dns_record}."]
}

# ====================== servers =============================
# differentiated by label "atix.de/role"
# "nat-gateway" is both in the internal network and internet
# "controlplanes" and "workers" are only in the internal network
resource "hcloud_server" "nat_gateway" {
  name        = "${local.name_prefix}-nat-gateway"
  image       = "ubuntu-22.04"
  datacenter  = local.datacenter
  server_type = "cpx11"

  labels = merge(local.common_labels, {
    "atix.de/role" = "nat-gateway"
  })

  network {
    network_id = hcloud_network.this.id
    ip         = local.nat_gateway_ip
  }

  public_net {
    ipv4         = hcloud_primary_ip.this.id
    ipv4_enabled = true
    ipv6_enabled = false
  }

  user_data = local.cloud_init_nat_gateway
}

resource "hcloud_server" "controlplanes" {
  # no high availability for now
  count       = 1
  name        = "${local.name_prefix}-controlplane-${count.index}"
  image       = "ubuntu-22.04"
  datacenter  = local.datacenter
  server_type = "cx21"

  labels = merge(local.common_labels, {
    "atix.de/role" = "controlplane"
  })

  network {
    network_id = hcloud_network.this.id
    ip         = cidrhost(local.subnet_cidr, count.index + 8)
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  user_data = local.cloud_init_servers
}

resource "hcloud_server" "workers" {
  count       = var.worker_count
  name        = "${local.name_prefix}-worker-${count.index}"
  image       = "ubuntu-22.04"
  datacenter  = local.datacenter
  server_type = "cx41"

  labels = merge(local.common_labels, {
    "atix.de/role" = "worker"
  })

  network {
    network_id = hcloud_network.this.id
    ip         = cidrhost(local.subnet_cidr, count.index + 16)
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  user_data = local.cloud_init_servers
}

resource "local_file" "haproxy_config" {
  filename = "${local.artifacts_path}/haproxy.cfg"
  content  = <<EOF
global
    chroot                       /var/lib/haproxy
    daemon
    user                         haproxy
    group                        haproxy
    maxconn                      4000
    pidfile                      /var/run/haproxy.pid
    log                          127.0.0.1 local0 debug
    tune.ssl.default-dh-param    2048

defaults
    log         global
    maxconn     4000
    retries     3
    balance     roundrobin
    option      dontlognull
    option      forwardfor
    option      http-server-close
    timeout     http-request 10s
    timeout     queue 1m
    timeout     connect 10s
    timeout     client 1m
    timeout     server 1m
    timeout     http-keep-alive 10s
    timeout     check 10s
    mode        tcp

frontend kubeapi
    bind            :6443
    use_backend     kubeapi
    timeout         client 2h

frontend kubeapps
    bind            :80
    use_backend     kubeapps
    timeout         client 2h

frontend kubeapps-tls
    bind            :443
    use_backend     kubeapps-tls
    timeout         client 2h

backend kubeapi
    timeout    server 2h
    %{~for server in hcloud_server.controlplanes~}
    server     ${server.name} ${tolist(server.network)[0].ip} check port 6443 
    %{~endfor~}

backend kubeapps
    timeout    server 2h
    %{~for server in hcloud_server.workers~}
    server     ${server.name} ${tolist(server.network)[0].ip}:30080 check port 30080
    %{~endfor~}

backend kubeapps-tls
    timeout    server 2h
    %{~for server in hcloud_server.workers~}
    server     ${server.name} ${tolist(server.network)[0].ip}:30443 check port 30443 
    %{~endfor~}
EOF
}

module "inventory" {
  source  = "./modules/ansible-inventory"

  from_yaml = [
    <<EOF
---
all:
  hosts:
    ${hcloud_server.nat_gateway.name}:
      ansible_host: "${aws_route53_record.a.name}"
      ansible_user: "atix"
      ansible_ssh_private_key_file: "${abspath(local_sensitive_file.ssh_private_key_atix.filename)}"
    %{~for server in hcloud_server.controlplanes~}
    ${server.name}:
      ansible_host: "${tolist(server.network)[0].ip}"
      ansible_user: "atix"
      ansible_ssh_private_key_file: "${abspath(local_sensitive_file.ssh_private_key_atix.filename)}"
      ansible_ssh_common_args: "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand=\"ssh -W %h:%p -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no atix@${aws_route53_record.a.name} -i ${abspath(local_sensitive_file.ssh_private_key_atix.filename)} \""
    %{~endfor~}
    %{~for server in hcloud_server.workers~}
    ${server.name}:
      ansible_host: "${tolist(server.network)[0].ip}"
      ansible_user: "atix"
      ansible_ssh_private_key_file: "${abspath(local_sensitive_file.ssh_private_key_atix.filename)}"
      ansible_ssh_common_args: "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand=\"ssh -W %h:%p -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no atix@${aws_route53_record.a.name} -i ${abspath(local_sensitive_file.ssh_private_key_atix.filename)} \""
    %{~endfor~}
  children:
    nat_gateway:
      hosts: 
        ${hcloud_server.nat_gateway.name}: null
      vars:
        haproxy_config_file: "${local_file.haproxy_config.filename}"
    controlplanes:
      hosts:
        %{~for server in hcloud_server.controlplanes~}
        ${server.name}: null
        %{~endfor~}
      vars:
        etcd_ca_cert_file: "${local_file.ca_certs["etcd-ca"].filename}"
        etcd_cert_file: "${local_file.issued_certs["kube-etcd"].filename}"
        etcd_key_file: "${local_sensitive_file.issued_keys["kube-etcd"].filename}"
        etcd_peer_ca_cert_file: "${local_file.ca_certs["etcd-ca"].filename}"
        etcd_peer_cert_file: "${local_file.issued_certs["kube-etcd-peer"].filename}"
        etcd_peer_key_file: "${local_sensitive_file.issued_keys["kube-etcd-peer"].filename}"
        kubernetes_advertise_ip: "${hcloud_primary_ip.this.ip_address}"
        kubernetes_service_cidr: "${local.service_cidr}"
        kubernetes_pod_cidr: "${local.pod_cidr}"
        kubernetes_serving_ca_cert_file: "${local_file.ca_certs["kubernetes-ca"].filename}"
        kubernetes_client_ca_cert_file: "${local_file.ca_certs["kubernetes-ca"].filename}"
        kubernetes_client_ca_key_file: "${local_sensitive_file.ca_keys["kubernetes-ca"].filename}"
        kubernetes_etcd_ca_cert_file: "${local_file.ca_certs["etcd-ca"].filename}"
        kubernetes_etcd_client_cert_file: "${local_file.issued_certs["kube-apiserver-etcd-client"].filename}"
        kubernetes_etcd_client_key_file: "${local_sensitive_file.issued_keys["kube-apiserver-etcd-client"].filename}"
        kubernetes_kubelet_ca_cert_file: "${local_file.ca_certs["kubernetes-ca"].filename}"
        kubernetes_kubelet_client_cert_file: "${local_file.issued_certs["kube-apiserver-kubelet-client"].filename}"
        kubernetes_kubelet_client_key_file: "${local_sensitive_file.issued_keys["kube-apiserver-kubelet-client"].filename}"
        kubernetes_service_account_cert_file: "${local_file.service_account_cert.filename}"
        kubernetes_service_account_key_file: "${local_sensitive_file.service_account_key.filename}"
        kubernetes_serving_cert_file: "${local_file.issued_certs["kube-apiserver"].filename}"
        kubernetes_serving_key_file: "${local_sensitive_file.issued_keys["kube-apiserver"].filename}"
        kubernetes_super_admin_kubeconfig_file: "${local_sensitive_file.kubeconfigs["super-admin"].filename}"
        kubernetes_controller_manager_kubeconfig_file: "${local_sensitive_file.kubeconfigs["controller-manager"].filename}"
        kubernetes_scheduler_kubeconfig_file: "${local_sensitive_file.kubeconfigs["scheduler"].filename}"
    workers:
      hosts:
        %{~for server in hcloud_server.workers~}
        ${server.name}:
          kubernetes_worker_node_name: "${server.name}"
          kubernetes_worker_kubelet_cert_file: "${local_file.issued_certs[server.name].filename}"
          kubernetes_worker_kubelet_key_file: "${local_sensitive_file.issued_keys[server.name].filename}"
          kubernetes_worker_kubelet_kubeconfig_file: "${local_sensitive_file.kubeconfigs[server.name].filename}"
          kubernetes_worker_local_pod_cidr: "${local.local_pod_cidrs[server.name]}"
        %{~endfor~}
      vars:
        kubernetes_worker_pod_cidr: "${local.pod_cidr}"
        kubernetes_worker_service_cidr: "${cidrhost(local.service_cidr, 10)}"
        kubernetes_worker_kubelet_ca_cert_file: "${local_file.ca_certs["kubernetes-ca"].filename}"
        kubernetes_worker_kube_proxy_kubeconfig_file: "${local_sensitive_file.kubeconfigs["kube-proxy"].filename}"
...
EOF
  ]

  files_dir       = "artifacts/"
  write_inventory = true
  playbook        = "${path.module}/playbook.yaml"
  triggers = {
    timestamp = timestamp()
  }
}
