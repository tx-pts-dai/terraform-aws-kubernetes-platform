################################################################################
# Amazon S3 Files storage
#
# The bucket and the IAM role the S3 Files service assumes are account-scoped and
# owned by the account stack (tx-pts-dai/dai-infrastructure:stacks/account). This
# creates the cluster's own file system on that shared bucket, its mount targets,
# their security group, and the StorageClass that provisions from them.
#
# Clusters sharing an account share the bucket, and each cluster's file system is
# scoped to a <cluster-name>/ prefix. That prefix is the isolation boundary: the
# account role is granted the whole bucket, so nothing in IAM keeps one cluster
# out of another's data.
#
# The file system id is also published to SSM and as an output, for applications
# that want their own StorageClass instead of the shared one.

locals {
  s3files_name        = "s3files-${local.id}"
  s3files_bucket_name = coalesce(var.s3files_bucket_name, "s3files-${local.account_id}")

  # S3 Files is built on EFS, which permits only one mount target per
  # Availability Zone (CreateMountTarget otherwise returns MountTargetConflict),
  # so reduce the private subnets to one per AZ.
  s3files_subnets_by_az = {
    for id, subnet in data.aws_subnet.s3files : subnet.availability_zone => id...
  }

  s3files_subnet_ids = [for az, ids in local.s3files_subnets_by_az : sort(ids)[0]]
}

data "aws_subnet" "s3files" {
  for_each = toset(var.enable_s3files_storage ? var.vpc.private_subnets : [])

  id = each.value
}

# No egress rules: mount targets answer NFS, they never originate connections.
module "s3files_security_group" {
  source = "./modules/security-group"

  create = var.enable_s3files_storage

  name        = local.s3files_name
  description = "NFS access to the cluster's Amazon S3 Files mount targets"

  vpc_id = var.vpc.vpc_id

  ingress_rules = {
    nfs = {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 2049
      to_port     = 2049
      description = "NFS from within the VPC"
      cidr_blocks = [var.vpc.vpc_cidr]
    }
  }

  tags = local.tags
}

# bucket, role_arn and prefix all force replacement. Replacement destroys the
# access points that bound PVs resolve through, so their volumes stop working,
# and a changed prefix additionally leaves the old data behind under the old key.
# These three have to be right the first time.
resource "aws_s3files_file_system" "this" {
  count = var.enable_s3files_storage ? 1 : 0

  bucket   = "arn:aws:s3:::${local.s3files_bucket_name}"
  role_arn = "arn:aws:iam::${local.account_id}:role/${var.s3files_role_name}"
  prefix   = "${module.eks.cluster_name}/"

  tags = merge(local.tags, {
    Name = local.s3files_name
  })
}

resource "aws_s3files_mount_target" "this" {
  for_each = toset(local.s3files_subnet_ids)

  file_system_id  = aws_s3files_file_system.this[0].id
  subnet_id       = each.value
  security_groups = [module.s3files_security_group.id]
}

# Created here rather than through GitOps because the file system id is only
# known at apply time. A StorageClass takes it as a plain string, so a manifest
# in Git could only carry it if someone copied it across by hand.
#
# parameters is immutable in Kubernetes and ForceNew in the provider, so any
# change here destroys and recreates the class. On its own that is safe for bound
# volumes, which resolve through their access point and never re-read the class.
# A new file system id is not: see the replacement note above.
resource "kubernetes_storage_class_v1" "s3files" {
  count = var.enable_s3files_storage ? 1 : 0

  metadata {
    name = "s3files"
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"

  parameters = {
    provisioningMode = "s3files-ap"
    fileSystemId     = aws_s3files_file_system.this[0].id
    directoryPerms   = "700"
    subPathPattern   = "$${.PVC.namespace}/$${.PVC.name}"
  }

  depends_on = [aws_s3files_mount_target.this]
}
