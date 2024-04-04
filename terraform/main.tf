terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
  }
}

provider "google" {
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.example.endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.example.master_auth[0].cluster_ca_certificate,
    )
  }
}

data "google_client_config" "provider" {}

data "google_project" "project" {
  project_id = "jetstack-paul"
}

resource "google_project_iam_custom_role" "cert_manager" {
  project     = data.google_project.project.project_id
  role_id     = "certmanagertf"
  title       = "Cert Manager"
  permissions = ["dns.resourceRecordSets.create", "dns.resourceRecordSets.list", "dns.resourceRecordSets.get", "dns.resourceRecordSets.update", "dns.resourceRecordSets.delete", "dns.changes.get", "dns.changes.create", "dns.changes.list", "dns.managedZones.list"]
}

data "google_container_cluster" "example" {
  name     = "example"
  project  = data.google_project.project.project_id
  location = "europe-west2-a"
}

resource "google_project_iam_member" "cert_manager" {
  project = data.google_project.project.project_id
  role    = google_project_iam_custom_role.cert_manager.name
  member  = "principal://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${data.google_project.project.project_id}.svc.id.goog/subject/ns/cert-manager/sa/cert-manager"
  #   condition {
  #     title      = "gke-wif-tf"
  #     expression = "request.auth.claims.google.providerId==\"${data.google_container_cluster.example.self_link}\""
  #   }
}

resource "helm_release" "cert_manager" {
  depends_on       = [google_project_iam_member.cert_manager]
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  set {
    name  = "installCRDs"
    value = "true"
  }
  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }
  set_list {
    name  = "extraArgs"
    value = ["--issuer-ambient-credentials"]
  }
}
