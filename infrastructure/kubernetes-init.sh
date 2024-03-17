#!/bin/env bash
# install coredns
kubectl apply -f coredns.yaml
# install ingress nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --version 4.7.5 \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=NodePort \
        --set controller.service.nodePorts.http=30080 \
        --set controller.service.nodePorts.https=30443 \
        --set controller.ingressClassResource.default=true \
        --set defaultBackend.enabled=true \
        --set controller.extraArgs.default-ssl-certificate="kube-system/ingress-nginx-default-cert"
# setup local path storage
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true --overwrite
# install cert manager an setup default cert
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml
kubectl delete validatingwebhookconfiguration --all
kubectl delete mutatingwebhookconfiguration --all
kubectl apply -f ingress-cert.yaml
