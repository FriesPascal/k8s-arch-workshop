# Kubernetes the even harder way
Deploy a bare bones Kubernetes cluster in Hetzner Cloud.
Communication in private networks only.

We deploy:
- 1 controlplane server (no HA for now)
- n worker nodes
- static networking using the upstream cni plugins
- haproxy as a loadbalancer for both controlplane and workers

In addition, there is `kubernetes-init.sh` which sets up ingress, dns, persistent storage, and cert management.

## TLDR
1. setup all necessary variables from `variables.tf`
2. do `terraform apply`
3. do `export KUBECONFIG=$PWD/artifacts/kubeconfigs/super-admin.conf`
4. execute `kubernetes-init.sh`
5. have fun and be nice
