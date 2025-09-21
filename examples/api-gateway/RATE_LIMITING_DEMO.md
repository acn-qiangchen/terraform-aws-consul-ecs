# 🚦 Consul API Gateway Rate Limiting Demo

This example demonstrates Consul API Gateway's rate limiting capabilities with three different endpoints showcasing various rate limiting configurations.

## 📋 **Rate Limiting Endpoints**

| Endpoint | Rate Limit | Description |
|----------|------------|-------------|
| `/` | None | Normal endpoint with no rate limiting |
| `/limited` | 5 req/min | Moderate rate limiting (5 requests per minute) |
| `/strict` | 2 req/min | Strict rate limiting (2 requests per minute) |

## 🏗️ **How It Works**

The rate limiting is implemented using Consul API Gateway's HTTP Route filters:

```hcl
Filters = {
  RequestRateLimit = {
    RequestsPerUnit = 5      # Number of requests allowed
    Unit           = "MINUTE" # Time window (SECOND, MINUTE, HOUR)
  }
}
```

### **Key Features:**
- **Per-route rate limiting** - Different limits for different paths
- **URL rewriting** - Rate-limited paths are rewritten to the backend service
- **HTTP 429 responses** - Standard "Too Many Requests" when limit exceeded
- **Time-window based** - Limits reset after the specified time window

## 🧪 **Testing Rate Limiting**

### **Method 1: Automated Test Script**

Run the provided test script:

```bash
# Make script executable
chmod +x test-rate-limiting.sh

# Run the test
./test-rate-limiting.sh
```

The script will:
- Test all three endpoints
- Make multiple requests to trigger rate limiting
- Show HTTP response codes and timing
- Demonstrate 429 "Too Many Requests" responses

### **Method 2: Manual Testing**

Get the API Gateway URL:
```bash
terraform output rate_limiting_endpoints
```

Test each endpoint manually:

```bash
# Get the base URL
API_GW_URL=$(terraform output -raw api_gateway_lb_url)

# Test normal endpoint (no limits)
for i in {1..5}; do curl -w "HTTP: %{http_code}\n" $API_GW_URL/; done

# Test limited endpoint (5 req/min)
for i in {1..7}; do curl -w "HTTP: %{http_code}\n" $API_GW_URL/limited; done

# Test strict endpoint (2 req/min)  
for i in {1..4}; do curl -w "HTTP: %{http_code}\n" $API_GW_URL/strict; done
```

### **Expected Results:**

**Normal Endpoint (`/`):**
- ✅ All requests return HTTP 200
- No rate limiting applied

**Limited Endpoint (`/limited`):**
- ✅ First 5 requests return HTTP 200
- ❌ Subsequent requests return HTTP 429 (Too Many Requests)

**Strict Endpoint (`/strict`):**
- ✅ First 2 requests return HTTP 200  
- ❌ Subsequent requests return HTTP 429 (Too Many Requests)

## 📊 **Rate Limiting Configuration Details**

### **HTTP Route Configuration:**

```json
{
  "Rules": [
    {
      "Matches": [{"Path": {"Match": "exact", "Value": "/limited"}}],
      "Filters": {
        "URLRewrite": {"Path": "/"},
        "RequestRateLimit": {
          "RequestsPerUnit": 5,
          "Unit": "MINUTE"
        }
      },
      "Services": [{"Name": "echo-app"}]
    }
  ]
}
```

### **Filter Types Used:**

1. **URLRewrite Filter:**
   - Rewrites `/limited` and `/strict` to `/` for the backend service
   - Allows rate limiting on specific paths while serving the same content

2. **RequestRateLimit Filter:**
   - Enforces request rate limits per time window
   - Returns HTTP 429 when limit exceeded
   - Supports SECOND, MINUTE, HOUR time units

## 🔄 **Rate Limit Reset**

Rate limits are **time-window based**:
- Limits reset after the specified time window (1 minute in this demo)
- Try running tests again after waiting 1 minute to see limits reset
- Each endpoint has independent rate limiting counters

## 🎯 **Use Cases**

This rate limiting functionality is useful for:

- **API Protection** - Prevent abuse and DoS attacks
- **Resource Management** - Control backend load
- **Tiered Access** - Different limits for different user tiers
- **Cost Control** - Limit expensive operations
- **SLA Enforcement** - Ensure fair usage across clients

## 🚀 **Production Considerations**

For production deployments, consider:

- **Client Identification** - Rate limiting per client IP or API key
- **Distributed Rate Limiting** - Coordination across multiple gateway instances
- **Custom Error Responses** - Branded 429 error pages
- **Monitoring & Alerting** - Track rate limit violations
- **Dynamic Limits** - Adjust limits based on system load

## 📈 **Monitoring Rate Limiting**

Monitor rate limiting effectiveness through:
- HTTP 429 response counts
- Request latency patterns
- Backend service load metrics
- Client retry behavior analysis
