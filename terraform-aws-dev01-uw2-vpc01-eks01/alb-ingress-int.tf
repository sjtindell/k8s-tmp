locals {
  log_bucket_int  = "internal-alb01-eks01-logs"
  domain_name_int = "internal-alb01.eks01.vpc01.uw2.dev01.aws.zuora"
}

module "security_group_alb_int" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "alb-int-sg-${local.cluster_name}"
  description = "Security group for example usage with ALB"
  vpc_id      = local.vpc_id

  ingress_cidr_blocks = ["10.0.0.0/16"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

module "log_bucket_alb_int" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 1.0"

  bucket                         = local.log_bucket_int
  acl                            = "log-delivery-write"
  force_destroy                  = true
  attach_elb_log_delivery_policy = true

  tags = local.tags
}

resource "aws_acm_certificate" "alb_int" {
  domain_name = local.domain_name_int

  certificate_authority_arn = "arn:aws:acm-pca:us-west-2:364736210010:certificate-authority/3ef9979e-516d-4cc1-8628-3deb2bb3a635"

  subject_alternative_names = [
    "*.${local.domain_name_int}"
  ]

  tags = merge(
    local.tags,
    {
      Name = "wildcard-${local.domain_name_int}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

module "alb_ingress_int" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = "int-alb01-eks01"

  load_balancer_type = "application"
  internal = true

  vpc_id          = local.vpc_id
  subnets         = ["subnet-0018c6fd3a0ece6a1", "subnet-00ac589cd29907d98", "subnet-04f38e1ebe6bc4d6b"]
  security_groups = [module.security_group_alb_int.security_group_id]

  access_logs = {
    bucket = local.log_bucket_int
  }

  target_groups = [
    {
      name_prefix      = "int-"
      backend_protocol = "HTTP"
      backend_port     = 32081
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
      certificate_arn = aws_acm_certificate.alb_int.arn
    }
  ]

  tags = local.tags
}

data "aws_route53_zone" "private" {
  name         = "uw2.dev01.aws.zuora"
  private_zone = true
}

resource "aws_route53_record" "alb_int" {
  zone_id = data.aws_route53_zone.private.zone_id
  name    = local.domain_name_int
  type    = "CNAME"
  ttl     = "300"
  records = [module.alb_ingress_int.lb_dns_name]
}
