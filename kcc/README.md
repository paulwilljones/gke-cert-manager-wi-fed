# kcc

## Setup

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
