# Crossplane

## Setup

In order for Crossplane to create `ProjectIAMMember` resources to manage GCP IAM and GKE Workload Identity Federation, itself requires Workload Identity for the controller to create GCP resources

```sh
gcloud iam service-accounts create crossplane
gcloud projects add-iam-policy-binding jetstack-paul \
  --member=serviceAccount:crossplane@jetstack-paul.iam.gserviceaccount.com \
  --role=roles/owner \
  --condition=None
gcloud iam service-accounts add-iam-policy-binding \
    crossplane@jetstack-paul.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser    \
    --member "serviceAccount:jetstack-paul.svc.id.goog[crossplane-system/crossplane]" \
    --project jetstack-paul
```

> TODO test if this works

```sh
gcloud projects add-iam-policy-binding projects/jetstack-paul \
    --role=roles/owner \
    --member=principal://iam.googleapis.com/projects/993897508389/locations/global/workloadIdentityPools/jetstack-paul.svc.id.goog/subject/ns/crossplane-system/sa/crossplane \
    --condition=None
```

```sh
helm repo add crossplane-stable https://charts.crossplane.io/stable && helm repo update
helm upgrade --install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane
```

Deploy a Crossplane `ControllerConfig`, `Provider` and `ProviderConfig` to use [Workload Identity](https://docs.upbound.io/providers/provider-gcp/authentication/#workload-identity) on GKE in order to create resources in Google Cloud.

```sh
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1alpha1
kind: ControllerConfig
metadata:
  name: gke-controller-config
  namespace: crossplane-system
  annotations:    
    iam.gke.io/gcp-service-account: crossplane@jetstack-paul.iam.gserviceaccount.com
spec:
  serviceAccountName: crossplane
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp-cloudplatform
  namespace: crossplane-system
spec:
  package: xpkg.upbound.io/upbound/provider-gcp-cloudplatform:v1.0.2
  controllerConfigRef:
    name: gke-controller-config
---
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
  namespace: crossplane-system
spec:
  credentials:
    source: InjectedIdentity
  projectID: jetstack-paul
EOF
```

## Create `ProjectIAMCustomRole` and `ProjectIAMMember`

Deploy a Crossplane [`ProjectIAMCustomRole`](https://marketplace.upbound.io/providers/upbound/provider-gcp-cloudplatform/v1.0.2/resources/cloudplatform.gcp.upbound.io/ProjectIAMCustomRole/v1beta1) and [`ProjectIAMMember`](https://marketplace.upbound.io/providers/upbound/provider-gcp-cloudplatform/v1.0.2/resources/cloudplatform.gcp.upbound.io/ProjectIAMMember/v1beta1) that grants the principal the IAM Role

```sh
kubectl apply -f - <<EOF
apiVersion: cloudplatform.gcp.upbound.io/v1beta1
kind: ProjectIAMCustomRole
metadata:
  name: certmanagerxp
spec:
  forProvider:
    permissions:
      - dns.resourceRecordSets.create
      - dns.resourceRecordSets.list
      - dns.resourceRecordSets.get
      - dns.resourceRecordSets.update
      - dns.resourceRecordSets.delete
      - dns.changes.get
      - dns.changes.create
      - dns.changes.list
      - dns.managedZones.list
    title: Cert Manager (Crossplane)
---
apiVersion: cloudplatform.gcp.upbound.io/v1beta1
kind: ProjectIAMMember
metadata:
  name: cert-manager-xp
  namespace: cert-manager
spec:
  forProvider:
    project: jetstack-paul
    member: principal://iam.googleapis.com/projects/993897508389/locations/global/workloadIdentityPools/jetstack-paul.svc.id.goog/subject/ns/cert-manager/sa/cert-manager
    role: projects/jetstack-paul/roles/certmanagerxp
EOF
```

## cert-manager

### helm-provider

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.17.0
  runtimeConfigRef:
    apiVersion: pkg.crossplane.io/v1beta1
    kind: DeploymentRuntimeConfig
    name: provider-helm
---
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: helm-provider
spec:
  credentials:
    source: InjectedIdentity
---
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-helm
spec:
  serviceAccountTemplate:
    metadata:
      name: provider-helm
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-helm-cluster-admin
subjects:
  - kind: ServiceAccount
    name: provider-helm
    namespace: crossplane-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: provider-helm
```

## Helm Release

```yaml
apiVersion: helm.crossplane.io/v1beta1
kind: Release
metadata:
  name: cert-manager
  namespace: cert-manager
spec:
  forProvider:
    chart:
      name: cert-manager
      repository: https://charts.jetstack.io
    namespace: cert-manager
    values:
      installCRDs:
        type: true
      global:
        leaderElection:
          namespace: cert-manager
      extraArgs:
        - --issuer-ambient-credentials
    skipCreateNamespace: false
  providerConfigRef:
    name: helm-provider
```
