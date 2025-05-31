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

Crossplane and configurations details from [Upbound Marketplace](https://marketplace.upbound.io/)

AWS - [Family](https://marketplace.upbound.io/providers/upbound/provider-family-aws/v1.22.0)