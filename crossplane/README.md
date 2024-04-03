# Crossplane

## Setup

In order for Crossplane to create `ProjectIAMMember` resources to manage GCP IAM and GKE Workload Identity Federation, itself requires Workload Identity for the controller to create GCP resources

```sh
gcloud iam service-accounts add-iam-policy-binding \
    crossplane-gsa@jetstack-paul.iam.gserviceaccount.com \
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
    iam.gke.io/gcp-service-account: crossplane-gsa@jetstack-paul.iam.gserviceaccount.com
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

## Create `ProjectIAMMember`

Deploy a Crossplane [`ProjectIAMMember`](https://marketplace.upbound.io/providers/upbound/provider-gcp-cloudplatform/v1.0.2/resources/cloudplatform.gcp.upbound.io/ProjectIAMMember/v1beta1) that grants the principal the IAM Role

```sh
apiVersion: v1
kind: Namespace
metadata:
  name: my-xp
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-ksa
  namespace: my-xp
---
apiVersion: cloudplatform.gcp.upbound.io/v1beta1
kind: ProjectIAMMember
metadata:
  name: project-iam-member
  namespace: my-xp
spec:
  forProvider:
    project: jetstack-paul
    member: principal://iam.googleapis.com/projects/993897508389/locations/global/workloadIdentityPools/jetstack-paul.svc.id.goog/subject/ns/my-xp/sa/my-ksa
    role: roles/storage.objectViewer
```

Deploy a test pod using the Kubernetes Service Account that has the require IAM permissions

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: my-xp
spec:
  serviceAccountName: my-ksa
  containers:
  - name: test-pod
    image: google/cloud-sdk:slim
    command: ["sleep","infinity"]
  nodeSelector:
    iam.gke.io/gke-metadata-server-enabled: "true"
EOF
```

Test that the pod can access the GCS bucket objects

```sh
kubectl exec -it -n my-xp pod/test-pod -- gcloud storage objects list gs://gke-wif
```
