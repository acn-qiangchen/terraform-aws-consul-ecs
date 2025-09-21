# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "consul_server_lb_address" {
  value = "http://${module.dc1.dev_consul_server.lb_dns_name}:8500"
}


output "api_gateway_lb_url" {
  value = "http://${aws_lb.this.dns_name}:8443"
}

output "rate_limiting_endpoints" {
  value = {
    normal_endpoint = "http://${aws_lb.this.dns_name}:8443/"
    limited_endpoint = "http://${aws_lb.this.dns_name}:8443/limited (5 req/min)"
    strict_endpoint = "http://${aws_lb.this.dns_name}:8443/strict (2 req/min)"
  }
}