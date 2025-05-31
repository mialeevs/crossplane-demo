# CROSSPLANE DEMO

## CROSSPLANE INSTALLATION

For upto date information, check [crossplane.io](https://www.crossplane.io/)

### INSTALL HELM
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

### ADD HELM REPO CHART FOR CROSSPLANE
```bash
# Add the helm chart
helm repo add \
crossplane-stable https://charts.crossplane.io/stable

# Update the repo
helm repo update
```

```bash
# Install crossplane
helm install crossplane \
crossplane-stable/crossplane \
--namespace crossplane-system \
--create-namespace \
--set image.repository=crossplane/crossplane \
--set image.tag=v1.20.0
```

### POD STATUS
```bash
kubectl get po -n crossplane-system

# NAME                                                        READY   STATUS    RESTARTS   AGE
# crossplane-c55946f6d-lgt9b                                  1/1     Running   0          28m
# crossplane-rbac-manager-d9dd6d76-l7ts4                      1/1     Running   0          28m
```

## UPBOUND MARKETPLACE

### Crossplane Externsions and configurations details
[Upbound Marketplace](https://marketplace.upbound.io/)

### AWS
- [Family](https://marketplace.upbound.io/providers/upbound/provider-family-aws/v1.22.0)

```yaml
# AWS Family Provider config

apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-family-aws
spec:
  package: xpkg.upbound.io/upbound/provider-family-aws:v1
```


- [EC2](https://marketplace.upbound.io/providers/upbound/provider-aws-ec2/v1.22.0)

```yaml
# AWS EC2 provider

apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-ec2
spec:
  package: xpkg.upbound.io/upbound/provider-aws-ec2:v1
```

### Crossplane secret with AWS Credentials

```txt
[default]
aws_access_key_id = <>
aws_secret_access_key = <>
```

```bash
kubectl create secret \
generic aws-secret \
-n crossplane-system \
--from-file=creds=./aws-credentials.txt
```