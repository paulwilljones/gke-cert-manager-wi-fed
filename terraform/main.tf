terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.23.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.27.0"
    }
  }
}

provider "google" {
}

data "google_client_config" "provider" {}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.example.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.example.master_auth[0].cluster_ca_certificate,
  )
}

resource "kubernetes_namespace" "my_tf" {
  metadata {
    name = "my-tf"
  }
}
resource "kubernetes_service_account" "my_ksa" {
  metadata {
    name      = "my-ksa"
    namespace = kubernetes_namespace.my_tf.metadata[0].name
  }
}

data "google_project" "project" {
  project_id = "jetstack-paul"
}

data "google_iam_role" "role" {
  name = "roles/storage.objectViewer"
}

data "google_container_cluster" "example" {
  name     = "example"
  project  = data.google_project.project.project_id
  location = "europe-west2-a"
}

resource "google_project_iam_member" "project" {
  project = "jetstack-paul"
  role    = data.google_iam_role.role.name
  member  = "principal://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/${data.google_project.project.project_id}.svc.id.goog/subject/ns/${kubernetes_service_account.my_ksa.metadata[0].namespace}/sa/${kubernetes_service_account.my_ksa.metadata[0].name}"
  #   condition {
  #     title      = "gke-wif-tf"
  #     expression = "request.auth.claims.google.providerId==\"${data.google_container_cluster.example.self_link}\""
  #   }
}
