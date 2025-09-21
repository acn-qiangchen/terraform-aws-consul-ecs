#!/bin/bash

# Rate Limiting Test Script for Consul API Gateway
# This script demonstrates different rate limiting scenarios

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get API Gateway URL from Terraform output
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform command not found${NC}"
    exit 1
fi

echo -e "${BLUE}Getting API Gateway URL from Terraform...${NC}"
API_GW_URL=$(terraform output -raw api_gateway_lb_url 2>/dev/null)

if [ -z "$API_GW_URL" ]; then
    echo -e "${RED}Error: Could not get API Gateway URL. Make sure Terraform has been applied.${NC}"
    exit 1
fi

echo -e "${GREEN}API Gateway URL: $API_GW_URL${NC}"
echo

# Function to make request and show response
make_request() {
    local path=$1
    local description=$2
    
    echo -e "${YELLOW}Testing: $description${NC}"
    echo -e "${BLUE}URL: $API_GW_URL$path${NC}"
    
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}\nTIME:%{time_total}" "$API_GW_URL$path" 2>/dev/null)
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    time_total=$(echo "$response" | grep "TIME:" | cut -d: -f2)
    body=$(echo "$response" | sed '/HTTP_CODE:/,$d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Success (HTTP $http_code) - Time: ${time_total}s${NC}"
        echo "Response: $(echo "$body" | jq -r '.service // "N/A"' 2>/dev/null || echo "Raw response")"
    elif [ "$http_code" = "429" ]; then
        echo -e "${RED}✗ Rate Limited (HTTP $http_code) - Time: ${time_total}s${NC}"
        echo "Response: Rate limit exceeded"
    else
        echo -e "${YELLOW}? Unexpected (HTTP $http_code) - Time: ${time_total}s${NC}"
        echo "Response: $body"
    fi
    echo
}

echo -e "${BLUE}=== Consul API Gateway Rate Limiting Demo ===${NC}"
echo

echo -e "${YELLOW}Available endpoints:${NC}"
echo "• $API_GW_URL/           - Service-level rate limiting (0.1 req/sec, burst 3)"
echo

# Test 1: Burst requests (should allow first 3, then rate limit)
echo -e "${BLUE}=== Test 1: Burst requests (0.1 req/sec, burst 3) ===${NC}"
echo -e "${YELLOW}Making 6 requests quickly to trigger rate limiting after burst...${NC}"
for i in {1..6}; do
    make_request "/" "Rate limited endpoint - Request $i"
    sleep 0.2
done

# Test 2: Slow requests (should work within rate limit)
echo -e "${BLUE}=== Test 2: Slow requests (respecting rate limit) ===${NC}"
echo -e "${YELLOW}Making requests with 12-second intervals (within 0.1 req/sec limit)...${NC}"
for i in {1..3}; do
    make_request "/" "Slow request - Request $i"
    if [ $i -lt 3 ]; then
        echo -e "${BLUE}Waiting 12 seconds for rate limit window...${NC}"
        sleep 12
    fi
done

echo -e "${BLUE}=== Rate Limiting Demo Complete ===${NC}"
echo
echo -e "${YELLOW}Summary:${NC}"
echo "• Burst test: First 3 requests should succeed (burst), then 429 (Too Many Requests)"
echo "• Slow test: All requests should succeed when respecting 0.1 req/sec rate limit"
echo
echo -e "${YELLOW}Note: Rate limit is 0.1 requests/second with burst of 3${NC}"
echo -e "${YELLOW}This means you can make 3 requests quickly, then must wait ~10 seconds between requests${NC}"
