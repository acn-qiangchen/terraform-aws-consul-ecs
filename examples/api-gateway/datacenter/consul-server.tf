# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Run the Consul dev server as an ECS task.
module "dev_consul_server" {
  name                        = "${var.name}-consul-server"
  source                      = "../../../modules/dev-server"
  ecs_cluster_arn             = var.ecs_cluster_arn
  subnet_ids                  = var.private_subnets
  vpc_id                      = var.vpc.vpc_id
  lb_enabled                  = true
  lb_subnets                  = var.public_subnets
  lb_ingress_rule_cidr_blocks = ["${var.lb_ingress_ip}/32"]
  tls                         = false
  acls                        = false
  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = var.log_group_name
      awslogs-region        = var.region
      awslogs-stream-prefix = "consul-server"
    }
  }
  launch_type = "FARGATE"
}

resource "aws_security_group_rule" "consul_server_ingress" {
  description              = "Access to Consul dev server from default security group"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = var.vpc.default_security_group_id
  security_group_id        = module.dev_consul_server.security_group_id
}

