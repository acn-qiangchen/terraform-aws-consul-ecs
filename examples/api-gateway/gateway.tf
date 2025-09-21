# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "api-gateway"
    }
  }
}

module "api_gateway" {
  source                        = "../../modules/gateway-task"
  family                        = "${var.name}-api-gateway"
  ecs_cluster_arn               = aws_ecs_cluster.this.arn
  subnets                       = module.vpc.private_subnets
  security_groups               = [module.vpc.default_security_group_id]
  log_configuration             = local.log_config
  consul_server_hosts           = module.dc1.dev_consul_server.server_dns
  kind                          = "api-gateway"
  tls                           = false
  additional_task_role_policies = [aws_iam_policy.execute_command.arn]

  acls = false

  lb_create_security_group = false
  enable_transparent_proxy = false

  custom_load_balancer_config = [{
    container_name   = "consul-dataplane"
    container_port   = 8443
    target_group_arn = aws_lb_target_group.this.arn
  }]
}

# Ingress rule for the API Gateway task that accepts traffic from the API gateway's LB
resource "aws_security_group_rule" "gateway_task_ingress_rule" {
  type                     = "ingress"
  description              = "Ingress rule for ${var.name}-api-gateway task"
  from_port                = 8443
  to_port                  = 8443
  protocol                 = "-1"
  source_security_group_id = aws_security_group.load_balancer.id
  security_group_id        = module.vpc.default_security_group_id
}

# API gateway's config entry
resource "consul_config_entry" "api_gateway_entry" {
  depends_on = [module.dc1]
  name       = "${var.name}-api-gateway"
  kind       = "api-gateway"

  config_json = jsonencode({
    Listeners = [
      {
        Name     = "api-gw-http-listener"
        Port     = 8443
        Protocol = "http"
      }
    ]
  })

  provider = consul.dc1-cluster
}
