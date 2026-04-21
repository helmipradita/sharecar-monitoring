# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Docker Compose-based monitoring stack for Sharecar AWS EC2 instances (DEV & QA environments). Collects metrics via Prometheus and logs via Loki/Grafana, with visualizations in Grafana behind an Nginx reverse proxy.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Nginx (Port 6789)                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                 │
│  │  Grafana   │  │ Prometheus │  │    Loki    │                 │
│  │  (3000)    │  │  (9090)    │  │  (3100)    │                 │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘                 │
└────────┼────────────────┼────────────────┼──────────────────────┘
         │                │                │
         └────────────────┴────────────────┴─── sharecar-monitoring-network
                           │
    ┌──────────────────────┼──────────────────────────────────┐
    │                      │                                  │
┌───▼────────┐  ┌─────────▼─────┐  ┌─────────▼─────┐          │
│ Promtail   │  │   Exporters   │  │  Loki Store   │          │
│ (9080)     │  │  node/pg/redis │  │  (volume)    │          │
└────────────┘  │ 9100/9187/9121 │  └───────────────┘          │
                └───────────────┘                             │
┌─────────────────────────────────────────────────────────────┤
│ Host File System (mounted read-only)                        │
│  /var/log/sharecar-core-api/logs  → Promtail                │
│  /var/log/sharecar-mobile-api/logs → Promtail                │
│  /var/log/syslog                  → Promtail                │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

- **Metrics**: Exporters scrape host/PostgreSQL/Redis → Prometheus → Grafana
- **Logs**: Application logs → Promtail → Loki → Grafana
- **Access**: External via Nginx on port 6789 (approach A: paths, approach B: Grafana only)

### Components

| Component | Purpose |
|-----------|---------|
| `node_exporter` | Host system metrics (CPU, memory, disk) |
| `postgres_exporter` | PostgreSQL/RDS metrics |
| `redis_exporter` | ElastiCache Redis metrics |
| `promtail` | Log agent that scrapes host log files and pushes to Loki |
| `loki` | Log aggregation storage |
| `prometheus` | Metrics storage and querying |
| `grafana` | Visualization dashboards |
| `nginx` | Reverse proxy for unified access |

## Docker Compose Profiles

Three profiles control which services run:

| Profile | Services | Use Case |
|---------|----------|----------|
| `full` | All services (Grafana + Nginx) | Centralized monitoring server |
| `monitoring` | Exporters + Promtail + Loki (no Prometheus/Grafana) | Agent-only, forwards data to remote server |
| `no-grafana` | Prometheus + Exporters + Promtail + Loki (no Grafana/Nginx) | Prometheus server without local Grafana |

## Commands

```bash
# Full stack with Grafana
docker compose --profile full up -d

# Monitoring agents only (for remote scrape)
docker compose --profile monitoring up -d

# View logs
docker compose logs -f <service>

# Restart service
docker compose restart <service>

# Stop all (keeps volumes)
docker compose --profile full down

# Destroy everything including volumes/data
docker compose --profile full down -v --remove-orphans
```

## Environment Configuration

Key `.env` variables that must be configured per environment:

- `SERVER_ENV` - `dev` or `qa` (used for Prometheus labels)
- `SERVER_NAME` - e.g., `dev-sharecar`, `qa-sharecar`
- `PG_HOST`, `PG_PORT`, `PG_USER`, `PG_PASSWORD` - RDS PostgreSQL credentials for postgres_exporter
- `REDIS_HOST`, `REDIS_PORT` - ElastiCache endpoint for redis_exporter
- `LOG_PATH_*` - Paths to application logs on host (must exist and be readable)

Prometheus and Promtail use `SERVER_NAME` and `SERVER_ENV` as labels for multi-environment filtering.

## Nginx Configuration

Two approaches available via `docker-compose.yml`:

- **Approach A** (default): `http://server:6789/` routes to Grafana, `/prometheus` to Prometheus, `/loki` to Loki
- **Approach B**: Only Grafana exposed; Prometheus/Loki accessed internally via Grafana datasources

Switch by changing the nginx service from `nginx` to `nginx-b` in compose profiles.

## Remote Scrape (DEV ↔ QA)

For centralized monitoring (e.g., DEV server scraping QA):

1. Set `SERVER_ENV` and `SERVER_NAME` appropriately in each server's `.env`
2. Add remote scrape targets to `prometheus/prometheus.yml`:
```yaml
- job_name: 'qa-server'
  static_configs:
    - targets: ['qa-ec2-ip:9100', 'qa-ec2-ip:9187', 'qa-ec2-ip:9121']
      labels:
        env: 'qa'
```

## Volumes

Named volumes persist data across container restarts:
- `sharecar-monitoring-prometheus-data` - Metrics data
- `sharecar-monitoring-loki-data` - Log data
- `sharecar-monitoring-grafana-data` - Dashboards, users, settings
