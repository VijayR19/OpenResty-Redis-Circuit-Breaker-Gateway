# Redis Circuit Breaker API Gateway (OpenResty)

A lightweight API gateway built with OpenResty (NGINX + Lua) that protects requests from Redis outages using a circuit breaker.

## Features

- OpenResty gateway endpoints:
  - `GET /health` – basic health check
  - `GET /protected` – Redis-protected route behind circuit breaker
  - `GET /stats` – JSON stats (state + counters)
- Circuit breaker:
  - CLOSED: calls Redis
  - OPEN: skips Redis and fails fast (fallback policy)
  - HALF-OPEN: probes Redis after cooldown and recovers automatically
- Observability via response headers:
  - `X-CB-State`
  - `X-CB-Fails`
  - `X-CB-Fallback`
  - `X-Redis`

## Requirements

- Fedora/Linux recommended
- Podman (or Docker)
- Redis/Valkey running locally on `127.0.0.1:6379`

## Installation

1. Clone the repository:
   ```bash
   git clone [https://github.com/your-username/redis-circuit-breaker.git](https://github.com/your-username/redis-circuit-breaker.git)

2. Build and run the Docker image:
    docker build -t redis-circuit-breaker .
    docker run --rm --network host -p 8080:8080 redis-circuit-breaker




