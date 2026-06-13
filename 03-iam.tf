#### INTERNALS ####
# -- Create custom roles for internals : User and Admin
resource "google_project_iam_custom_role" "CustomAdmin" {
  project     = var.project_id
  role_id     = "CustomAdmin"
  title       = "Custom - Admin"
  stage       = "BETA"
  description = <<-EOT
  Project IAM Admin
  Actions Admin
  BigQuery Admin
  Logs Writer
  Storage Admin
  Logs Viewer
  Monitoring Admin
  Secret Manager Admin
  ...
  EOT
  permissions = local.permissions_perf_admin
}

resource "google_project_iam_custom_role" "CustomUser" {
  project     = var.project_id
  role_id     = "CustomUser"
  title       = "Custom - User"
  stage       = "BETA"
  description = <<-EOT
  Actions Admin
  BigQuery Admin
  Logs Writer
  Monitoring Editor
  Storage Admin
  Logs Viewer
  Monitoring Viewer
  Secret Manager Secret Accessor
  ...
  EOT
  permissions = local.permissions_perf_user
}

# -- Bind custom roles and internal members (with condition and without for certain members)
resource "google_project_iam_binding" "CustomAdmin" {
  depends_on = [ google_project_iam_custom_role.CustomAdmin ]
  for_each   = local.custom_role_admin
  project    = var.project_id
  role       = google_project_iam_custom_role.CustomAdmin[var.project_id].id
  members    = each.value
  dynamic "condition" {
    for_each = each.key == "limited_access" ? [1] : []
    content {
      title       = "limit access to specific resources"
      description = "Limit access for Admin role on specific resources : buckets (as ${local.conditional_bucket}), datasets (starting with ${local.prefix_dataset})"
      expression  = local.condition
    }
  }
}

resource "google_project_iam_binding" "CustomUser" {
  depends_on = [ google_project_iam_custom_role.CustomUser ]
  for_each   = local.custom_role_user
  project    = var.project_id
  role       = google_project_iam_custom_role.CustomUser[var.project_id].id
  members    = each.value
  dynamic "condition" {
    for_each = each.key == "limited_access" ? [1] : []
    content {
      title       = "limit access to specific resources"
      description = "Limit access for User role on specific resources : buckets (as ${local.conditional_bucket}), datasets (starting with ${local.prefix_dataset})"
      expression  = local.condition
    }
  }
}

# -- Add certain roles to specific internal users
resource "google_project_iam_member" "SpecificInternalRoles" {
  for_each = local.specific_internal_roles
  project  = var.project_id
  role     = each.value.role
  member   = each.value.member
}


#### EXTERNALS ####
# -- Create custom project lvl roles for externals
resource "google_project_iam_custom_role" "ExternalProjectLvl" {
  for_each    = local.custom_project_lvl_roles
  role_id     = each.key
  title       = each.value.role_title
  description = each.value.role_description
  permissions = each.value.role_permissions
}

# -- Bind these custom roles to externals
resource "google_project_iam_binding" "ProjectCustomRoleForExternal" {
  depends_on = [ google_project_iam_custom_role.ExternalProjectLvl ]
  for_each   = local.project_role_for_external
  project    = var.project_id
  role       = each.key
  members    = each.value
}

# -- Bind resource lvl role to externals
resource "google_storage_bucket_iam_binding" "binding" {
  for_each = local.dict_bucket_members
  bucket   = each.key
  role     = "roles/storage.objectUser"
  members  = each.value
}

resource "google_bigquery_dataset_iam_binding" "binding" {
  for_each   = local.dict_dataset_members
  dataset_id = each.key
  role       = "roles/bigquery.dataViewer"
  members    = each.value
}
