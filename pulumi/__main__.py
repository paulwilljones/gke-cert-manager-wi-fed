from pulumi_kubernetes_cert_manager import (
    CertManager,
    ReleaseArgs,
    CertManagerGlobalArgs,
    CertManagerGlobalLeaderElectionArgs,
)

import pulumi_gcp as gcp

my_project = gcp.projects.get_project(filter="id:jetstack-paul")

cert_manager_role = gcp.projects.IAMCustomRole(
    "cert-manager",
    project=my_project.projects[0].project_id,
    role_id="certmanagerpulumi",
    title="Cert Manager (Pulumi)",
    permissions=[
        "dns.resourceRecordSets.create",
        "dns.resourceRecordSets.list",
        "dns.resourceRecordSets.get",
        "dns.resourceRecordSets.update",
        "dns.resourceRecordSets.delete",
        "dns.changes.get",
        "dns.changes.create",
        "dns.changes.list",
        "dns.managedZones.list",
    ],
)

project = gcp.projects.IAMMember(
    "project",
    project=my_project.projects[0].project_id,
    role=cert_manager_role.name,
    member=f"principal://iam.googleapis.com/projects/{my_project.projects[0].number}/locations/global/workloadIdentityPools/{my_project.projects[0].project_id}.svc.id.goog/subject/ns/cert-manager/sa/cert-manager",
)

manager = CertManager(
    "cert-manager",
    install_crds=True,
    helm_options=ReleaseArgs(namespace="cert-manager", create_namespace=True),
    extra_args=["--issuer-ambient-credentials"],
    global_=CertManagerGlobalArgs(
        leader_election=CertManagerGlobalLeaderElectionArgs(namespace="cert-manager")
    ),
)
