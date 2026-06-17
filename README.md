# GCP IAM Governance — Infrastructure as Code with Terraform

> **Portfolio project** · Data Engineer & GCP Professional Cloud Architect  
> Terraform-based, fully automated IAM management for GCP environments.

---

1. [Overview](#1-overview)
2. [Key Features](#2-key-features)
3. [Architecture](#3-architecture)
4. [IAM Design](#4-iam-design)
5. [CI/CD Pipeline](#5-cicd-pipeline)
6. [Configuration System](#6-configuration-system)

---

## 1. Overview

This project centralises and automates **Identity and Access Management (IAM)** across one or several GCP projects using **Terraform**. It replaces manual, error-prone IAM configurations with a version-controlled, reviewable, and repeatable Infrastructure-as-Code pipeline.

*Originally, it has been develop to recreate the existing structure, and to stop using manual intervention to manage access.*

**Two user populations are managed, with distinct security models:**
- **Internal users** — company employees granted fine-grained custom roles with conditional access restrictions
- **External users** — partner/consulting firms granted tightly scoped, per-resource access (GCS buckets & BigQuery datasets)

---

## 2. Key Features

| Feature | Implementation |
|---------|---------------|
| **Custom IAM Roles** | Terraform-managed `google_project_iam_custom_role` for both internal and external users |
| **Conditional IAM Bindings** | CEL expressions restrict internal roles from accessing specific sensitive resources |
| **Least-Privilege External Access** | External users can only access their own GCS buckets and BigQuery datasets |
| **Config-driven design** | All user lists and permissions live in flat files (`.txt`, `.json`) — no Terraform edits needed for day-to-day changes |
| **Keyless CI/CD** | Service account authenticates via **Workload Identity Federation** — no long-lived credentials |
| **GitOps workflow** | `terraform plan` on PR, `terraform apply` on merge to main |
| **Remote state** | Terraform state stored in a GCS backend |

---

## 3. Architecture

```
rex-tf/
├── 00-main.tf               # Provider config, GCS backend
├── 01-variables.tf          # Input variables (project_id, region, etc.)
├── 02-locals.tf             # Dynamic data transformation layer
├── 03-iam.tf                # All IAM resources (custom roles + bindings)
├── 99-outputs.tf            # Debug outputs
└── iam_config/
    ├── internal/
    │   ├── custom_roles/
    │   │   ├── members/     # User lists per role (txt)
    │   │   └── permissions/ # GCP permission lists per role (txt)
    │   ├── exceptionnal_full_access/   # Unrestricted access exceptions
    │   └── specific_internal_roles.json
    └── external/
        ├── custom_policies.json.tpl    # Per-client access config (template)
        └── project_lvl_roles.json      # Project-level custom roles for externals
```

### Data flow

```
iam_config/ : flat files & JSON
        │
        ▼
02-locals.tf : transformation, flattening, templating, deduplication
        │
        ▼
03-iam.tf : google_project_iam_custom_role
            google_project_iam_binding   (with / without CEL condition)
            google_project_iam_member
            google_storage_bucket_iam_binding
            google_bigquery_dataset_iam_binding
```

---

## 4. IAM Design

### 4.1 Internal Users

Two custom roles are created programmatically from permission lists:

| Role | Source file |
|------|------------|
| `Custom - Admin` | `permissions/permissions_perf_admin.txt` |
| `Custom - User` | `permissions/permissions_perf_user.txt` |

#### Conditional Access (CEL)

All internal users receive their role **with a IAM condition** that **denies access** to sensitive external resources (specific GCS buckets and BigQuery dataset prefixes):

```hcl
# 02-locals.tf — condition expression
condition = "resource.name != 'projects/_/buckets/${conditional_bucket}' && \
             !resource.name.startsWith('projects/${var.project_id}/datasets/${local.prefix_dataset}')"
```

A small list of **privileged users** is exempt from this condition and receives **unconditional full access**. The `02-locals.tf` layer splits the member list accordingly before binding:

```hcl
# 02-locals.tf — dynamic split of members
custom_role_admin = {
  limited_access = [for member in local.members_role_admin : member if !contains(local.exception_users, member)]
  full_access    = local.exception_users
}
```

The `google_project_iam_binding` resource then uses a `dynamic "condition"` block, applied only to the `limited_access` group — a clean pattern to handle two security tiers with a single resource block.

### 4.2 External Users (Partners & Consulting Firms)

External access follows a **least-privilege, per-client model** driven by a single template file (`custom_policies.json.tpl`):

```json
"client_name": {
    "project_lvl_roles": ["projects/${project_id}/roles/CustomBucketRole"],
    "gcs_role": "roles/storage.objectUser",
    "buckets": ["client-bucket"],
    "datasets": ["client_dataset"],
    "members": ["user:consultant@client.com"]
}
```

Two minimal custom project-level roles are created for all externals:

| Role | Permission | Purpose |
|------|-----------|---------|
| `Custom - External - Bucket` | `storage.buckets.list` | List GCS buckets |
| `Custom - External - BigQuery` | `bigquery.jobs.create` | Run BigQuery jobs |

These are then scoped **per client** at the resource level via `google_storage_bucket_iam_binding` and `google_bigquery_dataset_iam_binding` — ensuring full isolation between clients.

#### Dynamic aggregation in `02-locals.tf`

A key engineering challenge is that multiple clients may share the same role. The locals layer flattens and deduplicates bindings to avoid Terraform conflicts:

```hcl
# Flatten role → members across all clients, then deduplicate
flattened_roles_members = flatten([
  for policy, params in local.custom_policies : [
    for role in params.project_lvl_roles : { role = role, members = params.members }
  ]
])
project_role_for_external = {
  for role, members_lists in local.result : role => distinct(flatten(members_lists))
}
```

---

## 5. CI/CD Pipeline

The deployment is fully automated via **GitHub Actions**, using a dedicated service account with **no static keys** — authentication is handled through **Workload Identity Federation**.

```
Service Account: sa-iam-terraform-cicd@project.iam.gserviceaccount.com
Auth method:     Workload Identity Federation (keyless)
```

Required SA roles (IAM specified):
- BigQuery Admin
- Cloud Quotas Admin
- Project IAM Admin
- Role Viewer
- Storage Admin

### GitOps Workflow

```
Developer                        GitHub                              GCP
   │                                │                                 │
   ├─ git push (feature branch) ───►│                                 │
   │                                ├─ terraform plan ───────────────►│
   │                                │◄─ plan output (displayed in PR) ┤
   ├─ merge to main ───────────────►│                                 │
   │                                ├─ terraform apply ──────────────►│
   │                                │◄─ IAM applied ──────────────────┤
```

| Event | Action |
|-------|--------|
| Pull Request opened / updated | `terraform plan` — output posted as PR comment |
| Merge to `main` | `terraform apply` — IAM changes deployed to GCP |

> [!NOTE]
> Push to `main` is branch-protected. All changes go through a reviewed PR.

---

## 6. Configuration System

The project is designed so that **routine operations (adding/removing users) require zero Terraform knowledge**. Config changes are made exclusively in the `iam_config/` directory.

1. `git pull` on main
2. `git switch -c new_branch`
3. config your new IAM
4. add, commit and push 

### Adding an internal user

Edit `iam_config/internal/custom_roles/members/internal_members_user.txt`:
```
user:firstname.lastname@company.com   ← add in alphabetical order
```

### Adding an external client

Edit `iam_config/external/custom_policies.json.tpl`:
```json
"new_client": {
    "project_lvl_roles": ["projects/${project_id}/roles/CustomBucketRole"],
    "gcs_role": "roles/storage.objectUser",
    "buckets": ["new-client-bucket"],
    "members": ["user:contact@new-client.com"]
}
```

Then: **branch → commit → PR → review plan → merge**. Done.

---

## 7. Improvment
This project is contextual and has been build on an existing IAM where all was done on GCP console.

The first and main improvement would be to add **groups**, it would add a finer control and a better management of resources acces.

---

*Built with Terraform · Google Cloud IAM · GitHub Actions · Workload Identity Federation*