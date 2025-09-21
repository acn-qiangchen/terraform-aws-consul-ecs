# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Single echo app service - simplified for PoC
resource "aws_ecs_service" "echo_app" {
  name            = "${var.name}-echo-app"
  cluster         = aws_ecs_cluster.this.arn
  task_definition = module.echo_app.task_definition_arn
  desired_count   = 2  # Run 2 instances for load balancing demo
  network_configuration {
    subnets = module.vpc.private_subnets
  }
  launch_type            = "FARGATE"
  propagate_tags         = "TASK_DEFINITION"
  enable_execute_command = true
}

module "echo_app" {
  source                   = "../../modules/mesh-task"
  family                   = "${var.name}-echo-app"
  port                     = "3000"
  log_configuration        = local.echo_apps_log_config
  acls                     = false
  tls                      = false
  enable_transparent_proxy = false
  consul_server_hosts      = module.dc1.dev_consul_server.server_dns
  additional_task_role_policies = [aws_iam_policy.execute_command.arn]
  
  consul_service_name = "echo-app"
  
  container_definitions = [
    {
      name             = "echo-app"
      image            = "k8s.gcr.io/ingressconformance/echoserver:v0.0.1"
      essential        = true
      logConfiguration = local.echo_apps_log_config
      environment = [
        {
          name  = "SERVICE_NAME"
          value = "echo-app"
        }
      ]
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
    }
  ]
}


// Service defaults for echo app
resource "consul_config_entry" "echo_app_defaults" {
  kind     = "service-defaults"
  name     = "echo-app"
  provider = consul.dc1-cluster

  config_json = jsonencode({
    Protocol = "http"
  })
}

// API gateway http route information for echo service
resource "consul_config_entry" "api_gw_http_route_echo" {
  depends_on = [consul_config_entry.echo_app_defaults, consul_config_entry.api_gateway_entry]

  name = "${var.name}-echo-http-route"
  kind = "http-route"

  config_json = jsonencode({
    Rules = [
      {
        Matches = [
          {
            Path = {
              Match = "prefix"
              Value = "/"
            }
          }
        ]
        Services = [
          {
            Name = "echo-app"
          }
        ]
      }
    ]

    Parents = [
      {
        Kind        = "api-gateway"
        Name        = "${var.name}-api-gateway"
        SectionName = "api-gw-http-listener"
      }
    ]
  })

  provider = consul.dc1-cluster
}

locals {
  echo_apps_log_config = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.log_group.name
      awslogs-region        = var.region
      awslogs-stream-prefix = "echo-apps"
    }
  }
}