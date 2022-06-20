module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "18.2.3"

  cluster_name                    = "kubernetes"
  cluster_version                 = "1.21"
  cluster_endpoint_private_access = false
  cluster_endpoint_public_access  = true

  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
  node_security_group_additional_rules = {
    ingress_self_all_from_self = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_self_all_from_eks = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      source_security_group_id = module.eks.cluster_security_group_id
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    disk_size              = 50
    instance_types         = var.instance_types
  }
  eks_managed_node_groups = {
    default = {
      min_size     = 3
      max_size     = 3
      desired_size = 3
      capacity_type  = "SPOT"
      labels = var.tags
    }
  }
}
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "eks-key"
    },
  )
}
resource "aws_kms_alias" "eks-key-alias" {
  name          = "alias/eks-key"
  target_key_id = aws_kms_key.eks.key_id
}
