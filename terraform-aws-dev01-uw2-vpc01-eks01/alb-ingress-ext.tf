locals {
  log_bucket_ext  = "external-alb01-eks01-logs"
  domain_name_ext = trimsuffix("external-alb01.eks01.vpc01.uw2.dev01.aws.zuora.com", ".")
}

module "security_group_alb_ext" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "alb-ext-sg-${local.cluster_name}"
  description = "Security group for example usage with ALB"
  vpc_id      = local.vpc_id

  ingress_cidr_blocks = ["67.164.94.157/32"] # personal laptop
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "log_bucket_alb_ext" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 1.0"

  bucket                         = local.log_bucket_ext
  acl                            = "log-delivery-write"
  force_destroy                  = true
  attach_elb_log_delivery_policy = true

  tags = local.tags
}

module "acm_ingress_ext" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3.0"

  domain_name  = local.domain_name_ext
  zone_id      = "Z02335882N5ND1RPZFN1Y"

  subject_alternative_names = [
    "*.${local.domain_name_ext}"
  ]

  wait_for_validation = true

  tags = merge(
    local.tags,
    {
      Name = "wildcard-${local.domain_name_ext}"
    }
  )
}

module "alb_ingress_ext" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = "ext-alb01-eks01"

  load_balancer_type = "application"

  vpc_id          = local.vpc_id
  subnets         = ["subnet-052fa2fbf9dd970ed", "subnet-0464441b2ea016557", "subnet-00a4fb76699865241"]
  security_groups = [module.security_group_alb_ext.security_group_id]

  access_logs = {
    bucket = local.log_bucket_ext
  }

  target_groups = [
    {
      name_prefix      = "int-"
      backend_protocol = "HTTP"
      backend_port     = 32080
      target_type      = "instance"
      health_check = {
        interval            = 10
        path                = "/ping"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
  ]

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = module.acm_ingress_ext.acm_certificate_arn
    }
  ]

  tags = local.tags
}

data "aws_route53_zone" "public" {
  name         = "uw2.dev01.aws.zuora.com"
}

resource "aws_route53_record" "alb_ext" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = local.domain_name_ext
  type    = "CNAME"
  ttl     = "300"
  records = [module.alb_ingress_ext.lb_dns_name]
}
