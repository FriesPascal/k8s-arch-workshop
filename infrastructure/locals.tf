locals {
  # all generated cloud resource names have this prefix
  # useful for debugging
  name_prefix = "k8sthw-${var.environment}"

  # all generated cloud resources have these labels
  # useful for "emergency deletion"
  common_labels = {
    "atix.de/repo"        = "kubernetes-the-hard-way"
    "atix.de/environment" = var.environment
  }

  # colocate everything
  datacenter = "nbg1-dc3"

  # network bookkeeping
  dns_record         = "${local.name_prefix}.${data.aws_route53_zone.this.name}"
  network_cidr       = "10.25.0.0/24"
  pod_cidr           = "10.32.128.0/17"
  service_cidr       = "10.32.0.0/17"
  subnet_cidr        = cidrsubnet(local.network_cidr, 0, 0)
  default_gateway_ip = cidrhost(local.subnet_cidr, 1)
  nat_gateway_ip     = cidrhost(local.subnet_cidr, 2)
  local_pod_cidrs = { for i in range(var.worker_count) :
    hcloud_server.workers[i].name => cidrsubnet(local.pod_cidr, 7, i)
  }

  # artifacts are stored here so the pipeline can pick them up later
  artifacts_path = abspath("${path.root}/artifacts")
}

# cloud init data, centralised here as multiple servers use this
locals {
  cloud_init_nat_gateway = <<EOF
#cloud-config
disable_root: true
ssh_pwauth: false
users:
- name: atix
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  ssh_authorized_keys:
    - ${tls_private_key.atix.public_key_openssh}
write_files:
- path: /etc/networkd-dispatcher/routable.d/routing.sh
  content: |
    #!/bin/sh
    # CREATED BY CLOUD-INIT
    echo 1 > /proc/sys/net/ipv4/ip_forward
    ip route add ${local.pod_cidr} via ${local.default_gateway_ip}
    iptables -t nat -A POSTROUTING -s '${local.pod_cidr}' -o eth0 -j MASQUERADE
    iptables -t nat -A POSTROUTING -s '${local.network_cidr}' -o eth0 -j MASQUERADE
  owner: 'root:root'
  permissions: '0755'
- path: /etc/systemd/resolved.conf
  content: |
    # CREATED BY CLOUD-INIT
    [Resolve]
    DNS=185.12.64.2 185.12.64.1
    Domains=atix-training.de
  owner: 'root:root'
  permissions: '0644'
runcmd:
- /etc/networkd-dispatcher/routable.d/routing.sh
- systemctl restart systemd-resolved
EOF

  cloud_init_servers = <<EOF
#cloud-config
disable_root: true
ssh_pwauth: false
users:
- name: atix
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  ssh_authorized_keys:
  - ${tls_private_key.atix.public_key_openssh}
write_files:
- path: /etc/networkd-dispatcher/routable.d/routing.sh
  content: |
    #!/bin/sh
    # CREATED BY CLOUD-INIT
    echo 1 > /proc/sys/net/ipv4/ip_forward
    ip route add default via ${local.default_gateway_ip}
  owner: 'root:root'
  permissions: '0755'
- path: /etc/systemd/resolved.conf
  content: |
    # CREATED BY CLOUD-INIT
    [Resolve]
    DNS=185.12.64.2 185.12.64.1
    Domains=atix-training.de
  owner: 'root:root'
  permissions: '0644'
runcmd:
- /etc/networkd-dispatcher/routable.d/routing.sh
- systemctl restart systemd-resolved
EOF
}

