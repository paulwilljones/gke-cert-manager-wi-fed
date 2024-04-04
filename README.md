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
    --autoscaling-profile=optimize-utilization \
    --enable-autoprovisioning \
    --min-cpu 1 \
    --min-memory 1 \
    --max-cpu 10 \
    --max-memory 64 \
    --workload-pool=jetstack-paul.svc.id.goog
```

All the features required are enabled by default on Autopilot

```sh
gcloud container clusters create-auto example-auto \
    --location europe-west2
```

```sh
gcloud projects add-iam-policy-binding projects/jetstack-paul \
    --role=roles/dns.admin \
    --member=principal://iam.googleapis.com/projects/993897508389/locations/global/workloadIdentityPools/jetstack-paul.svc.id.goog/subject/ns/cert-manager/sa/cert-manager \
    --condition=None
```

## cert-manager

```sh
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager \
  --set extraArgs={--issuer-ambient-credentials}
```

```sh
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: cloud-dns
spec:
  acme:
    email: paul.jones@jetstack.io
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: issuer-account-key
    solvers:
    - dns01:
        cloudDNS:
          project: jetstack-paul
EOF
```

```sh
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-com
spec:
  secretName: example-com-tls
  issuerRef:
    name: cloud-dns
  dnsNames:
  - example.paul-gcp.jetstacker.net
EOF
```

> TODO Add condition to mitigate identity sameness

```sh
gcloud projects add-iam-policy-binding projects/jetstack-paul \
    --role=roles/storage.objectViewer \
    --member=principal://iam.googleapis.com/projects/993897508389/locations/global/workloadIdentityPools/jetstack-paul.svc.id.goog/subject/ns/default/sa/my-ksa \
    --condition='title=gke-wif-cluster,expression="request.auth.claims.google.providerId==\"https://container.googleapis.com/v1/projects/jetstack-paul/zones/europe-west2-a/clusters/example\"'
```

## Terraform

[README](./terraform/README.md)

## Config Connector

[README](./kcc/README.md)

## Crossplane

[README](./crossplane/README.md)

## Pulumi

[README](./pulumi/README.md)
