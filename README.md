# Workload Identity Federation for GKE

## `gcloud`

```sh
gcloud container clusters create example \
    --location europe-west2-a \
    --spot \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=9 \
    --num-nodes=3 \
    --enable-autoprovisioning \
    --min-cpu 1 \
    --min-memory 1 \
    --max-cpu 10 \
    --max-memory 64 \
    --workload-pool=jetstack-paul.svc.id.goog
```

```sh
kubectl create sa my-ksa
```

```sh
gcloud projects add-iam-policy-binding projects/jetstack-paul \
    --role=roles/storage.objectViewer \
    --member=principal://iam.googleapis.com/projects/993897508389/locations/global/workloadIdentityPools/jetstack-paul.svc.id.goog/subject/ns/default/sa/my-ksa \
    --condition=None
```

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
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

```sh
gcloud storage buckets create gs://gke-wif
```

```sh
kubectl exec -it pods/test-pod --namespace=default -- gcloud storage objects list gs://gke-wif
```

> TODO Add condition to mitigate identity sameness

```sh
gcloud projects add-iam-policy-binding projects/jetstack-paul \
    --role=roles/storage.objectViewer \
    --member=principal://iam.googleapis.com/projects/993897508389/locations/global/workloadIdentityPools/jetstack-paul.svc.id.goog/subject/ns/default/sa/my-ksa \
    --condition='title=gke-wif-cluster,expression=resource.type=="container.googleapis.com/Clusters" && resource.name.startsWith("projects/jetstack-paul/zones/europe-west2-a/clusters/example")'
```

## Terraform

[README](./terraform/README.md)

## Config Connector

[README](./kcc/README.md)
