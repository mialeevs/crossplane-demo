# CROSSPLANE DEMO

## CROSSPLANE INSTALLATION

crossplane.io(https://www.crossplane.io/)

### INSTALL HELM
```bash
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