# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "consul_server_lb_address" {
  value = "http://${module.dc1.dev_consul_server.lb_dns_name}:8500"
}


output "api_gateway_lb_url" {
  value = "http://${aws_lb.this.dns_name}:8443"
}

output "rate_limiting_info" {
  value = {
    endpoint = "http://${aws_lb.this.dns_name}:8443/"
    rate_limit = "0.1 requests/second with burst of 3"
    description = "Service-level rate limiting applied to echo-app service"
  }
}