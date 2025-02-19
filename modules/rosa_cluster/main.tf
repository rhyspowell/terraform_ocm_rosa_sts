locals {
  path = coalesce(var.path, "/")
  sts_roles = {
    role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role${local.path}${var.account_role_prefix}-Installer-Role",
    support_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role${local.path}${var.account_role_prefix}-Support-Role",
    instance_iam_roles = {
      master_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role${local.path}${var.account_role_prefix}-ControlPlane-Role",
      worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role${local.path}${var.account_role_prefix}-Worker-Role"
    },
    operator_role_prefix = var.operator_role_prefix,
    oidc_config_id       = var.oidc_config_id
  }
  worker_node_replicas = try(var.worker_node_replicas, var.multi_az ? 3 : 2) 
}

# Declare the data sources
/*data "aws_availability_zones" "available" {
  state = "available"
}*/

data "aws_caller_identity" "current" {
}


resource "rhcs_cluster_rosa_classic" "rosa_sts_cluster" {
  name                  = var.cluster_name
  cloud_region          = var.aws_region
  multi_az              = var.multi_az
  replicas              = local.worker_node_replicas
  aws_account_id        = data.aws_caller_identity.current.account_id
  availability_zones    = var.availability_zones
  tags                  = var.additional_tags
  version               = var.rosa_openshift_version
  proxy                 = var.proxy
  compute_machine_type  = var.machine_type
  autoscaling_enabled   = var.autoscaling_enabled
  min_replicas          = var.min_replicas
  max_replicas          = var.max_replicas
  #ToDo set cluster  service-cidr, pod-cidr, host prefix
  sts                   = local.sts_roles
  properties = {
    rosa_creator_arn    = data.aws_caller_identity.current.arn
  }  
  #Private link settings
  private               = var.enable_private_link
  aws_private_link      = var.enable_private_link
  aws_subnet_ids        = var.private_subnet_ids
  machine_cidr          = var.enable_private_link ? var.vpc_cidr_block : null  

}

resource "rhcs_cluster_wait" "rosa_cluster" {
  cluster = rhcs_cluster_rosa_classic.rosa_sts_cluster.id
  # timeout in minutes
  timeout = 60
}
