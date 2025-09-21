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
echo "• $API_GW_URL/           - No rate limiting"
echo "• $API_GW_URL/limited    - 5 requests per minute"
echo "• $API_GW_URL/strict     - 2 requests per minute"
echo

# Test 1: Normal endpoint (no rate limiting)
echo -e "${BLUE}=== Test 1: Normal endpoint (no rate limiting) ===${NC}"
for i in {1..3}; do
    make_request "/" "Normal endpoint - Request $i"
    sleep 1
done

# Test 2: Limited endpoint (5 requests per minute)
echo -e "${BLUE}=== Test 2: Limited endpoint (5 requests per minute) ===${NC}"
echo -e "${YELLOW}Making 7 requests quickly to trigger rate limiting...${NC}"
for i in {1..7}; do
    make_request "/limited" "Limited endpoint - Request $i"
    sleep 0.5
done

# Test 3: Strict endpoint (2 requests per minute)
echo -e "${BLUE}=== Test 3: Strict endpoint (2 requests per minute) ===${NC}"
echo -e "${YELLOW}Making 4 requests quickly to trigger rate limiting...${NC}"
for i in {1..4}; do
    make_request "/strict" "Strict endpoint - Request $i"
    sleep 0.5
done

echo -e "${BLUE}=== Rate Limiting Demo Complete ===${NC}"
echo
echo -e "${YELLOW}Summary:${NC}"
echo "• Normal endpoint: All requests should succeed"
echo "• Limited endpoint: First 5 requests succeed, then 429 (Too Many Requests)"
echo "• Strict endpoint: First 2 requests succeed, then 429 (Too Many Requests)"
echo
echo -e "${YELLOW}Note: Rate limits reset after the time window (1 minute)${NC}"
echo -e "${YELLOW}Try running the script again after a minute to see limits reset${NC}"
