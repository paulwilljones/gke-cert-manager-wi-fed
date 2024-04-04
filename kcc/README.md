# kcc

## Setup

Enable Config Connector on existing GKE cluster

```sh
gcloud container clusters update example --location europe-west2-a --update-addons=ConfigConnector=ENABLED
```

> `roles/owner` required for KCC Service Account when applying IAM resources

This setup could change to use Workload Identity Federation, however, the `ConfigConnector` resource requires a `googleServiceAccount`, therefore binding a KSA and GSA is still needed.

```sh
gcloud iam service-accounts create config-connector-example
gcloud projects add-iam-policy-binding jetstack-paul \
    --member="serviceAccount:config-connector-example@jetstack-paul.iam.gserviceaccount.com" \
    --role="roles/owner" \
    --condition=None

gcloud iam service-accounts add-iam-policy-binding \
    config-connector-example@jetstack-paul.iam.gserviceaccount.com \
    --member="serviceAccount:jetstack-paul.svc.id.goog[cnrm-system/cnrm-controller-manager]" \
    --role="roles/iam.workloadIdentityUser" \
    --condition=None
```

```sh
kubectl apply -f - <<EOF
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  name: configconnector.core.cnrm.cloud.google.com
spec:
 mode: cluster
 googleServiceAccount: "config-connector-example@jetstack-paul.iam.gserviceaccount.com"
EOF
```

## `IAMCustomRole` and `IAMPolicyMember`

```sh
kubectl apply -f - <<EOF
apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMCustomRole
metadata:
  annotations:
    cnrm.cloud.google.com/project-id: jetstack-paul
  name: certmanager
spec:
  title: Cert Manager
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
  stage: GA
EOF
```

```sh
kubectl apply -f - <<EOF
apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMPolicyMember
metadata:
  name: cert-manager-kcc
  namespace: cert-manager
  annotations:
    cnrm.cloud.google.com/project-id: jetstack-paul
spec:
  member: principal://iam.googleapis.com/projects/993897508389/locations/global/workloadIdentityPools/jetstack-paul.svc.id.goog/subject/ns/cert-manger/sa/cert-manager
  role: projects/jetstack-paul/roles/certmanager
  resourceRef:
    kind: Project
    external: projects/jetstack-paul
EOF
```
