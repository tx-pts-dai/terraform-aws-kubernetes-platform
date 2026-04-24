apiVersion: v1
kind: Secret
metadata:
  name: ${cluster_name}
  namespace: argocd
  labels:
%{ for key, value in labels ~}
    ${key}: "${value}"
%{ endfor ~}
  annotations:
    config/vpc-cidr: "${vpc_cidr}"
type: Opaque
stringData:
  name: "${cluster_name}"
  server: "${cluster_endpoint}"
  config: |
    ${indent(4, argocd_config)}
