locals {
  # -- IAM configuration files
  path_conf = "${path.module}/iam_config"

  permissions_perf_admin  = split("\n", trimspace(file("${local.path_conf}/internal/custom_roles/permissions/permissions_perf_admin.txt")))
  permissions_perf_user   = split("\n", trimspace(file("${local.path_conf}/internal/custom_roles/permissions/permissions_perf_user.txt")))
  members_role_admin      = split("\n", trimspace(file("${local.path_conf}/internal/custom_roles/members/internal_members_admin.txt")))
  members_role_user       = split("\n", trimspace(file("${local.path_conf}/internal/custom_roles/members/internal_members_user.txt")))
  exception_users         = split("\n", trimspace(file("${local.path_conf}/internal/exceptionnal_full_access/internal_exception_principals.txt")))
  specific_internal_roles = jsondecode(file("${local.path_conf}/internal/specific_internal_roles.json"))

  # -- List members (with conditionnal access and without) for binding custom role
  custom_role_admin = {
    limited_access = [
      for member in local.members_role_admin : member if !contains(local.exception_users, member)
    ]
    full_access = local.exception_users
  }

  custom_role_user = {
    limited_access = [
      for member in local.members_role_user : member if !contains(local.exception_users, member)
    ]
    full_access = local.exception_users
  }

  # -- Create condition for internal's roles
  conditional_bucket = "exemple_bucket"
  prefix_dataset = "exemple_prefix"
  condition = "resource.name != 'projects/_/buckets/${conditional_bucket}' && !resource.name.startsWith('projects/${var.project_id}/datasets/${local.prefix_dataset}')"

  # -- Get custom project lvl roles for externals
  custom_project_lvl_roles = jsondecode(file("${local.path_conf}/external/project_lvl_roles.json"))

  # -- Get the template filled
  custom_policies = jsondecode(templatefile("${local.path_conf}/external/custom_policies.json.tpl", {
    project_id = var.project_id
  }))

  # -- Get the custom roles and aggregates their respective members (see documentation)
  flattened_roles_members = flatten([
    for policy, params in local.custom_policies : [
      for role in params.project_lvl_roles : {
        role    = role
        members = params.members
      }
    ]
  ])
  result = {
    for item in local.flattened_roles_members : item.role => item.members...
  }
  project_role_for_external = {
    for role, members_lists in local.result :
      role => distinct(flatten(members_lists))
  }

  # -- Aggregate members for even bucket
  flattened_bucket_members = flatten([
    for policy, params in local.custom_policies : [
      for bucket in try(params.buckets, []) : {
        bucket  = bucket
        members = params.members
      }
    ]
  ])
  raw_bucket_members = {
    for item in local.flattened_bucket_members : item.bucket => item.members...
  }
  dict_bucket_members = {
    for bucket, members_lists in local.raw_bucket_members : 
      bucket => distinct(flatten(members_lists))
  }

  # -- Aggregate members for even dataset
  flattened_dataset_members = flatten([
    for policy, params in local.custom_policies : [
      for dataset in try(params.datasets, []) : {
        dataset = dataset
        members = params.members
      }
    ]
  ])
  raw_dataset_members = {
    for item in local.flattened_dataset_members : item.dataset => item.members...
  }
  dict_dataset_members = {
    for dataset, members_lists in local.raw_dataset_members : 
      dataset => distinct(flatten(members_lists))
  }
}
