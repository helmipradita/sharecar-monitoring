# Sharecar Monitoring Stack

Docker Compose-based monitoring stack untuk AWS EC2 DEV & QA Sharecar.

## Requirements

- Docker & Docker Compose
- Linux server (untuk node_exporter host mode)

## Services & Versions

| Service | Image | Version | Port |
|---------|-------|---------|------|
| node_exporter | quay.io/prometheus/node-exporter | v1.9.1 | 9100 |
| postgres_exporter | quay.io/prometheuscommunity/postgres-exporter | latest | 9187 |
| redis_exporter | oliver006/redis_exporter | v1.82.0 | 9121 |
| promtail | grafana/promtail | 3.4.0 | 9080 |
| loki | grafana/loki | 3.4.0 | 3100 |
| prometheus | prom/prometheus | v3.4.0 | 9090 |
| grafana | grafana/grafana | 11.5.2 | 3000 |
| nginx | nginx | 1.27-alpine | 80 |

## Profiles

| Profile | Services |
|---------|-----------|
| full | Semua service (Grafana + Nginx) |
| monitoring | node_exporter + postgres_exporter + redis_exporter + promtail + loki |
| no-grafana | prometheus + node_exporter + promtail + loki |

## Cara Penggunaan

### 1. Setup Environment

Copy dan edit `.env` file:

```bash
cp .env.example .env  # Jika ada example
# Atau edit langsung .env
nano .env
```

Konfigurasi yang penting:
- `SERVER_ENV` - set ke `dev` atau `qa`
- `SERVER_NAME` - nama server (dev-sharecar / qa-sharecar)
- `PG_HOST`, `PG_USER`, `PG_PASSWORD` - RDS PostgreSQL credentials
- `REDIS_HOST` - ElastiCache Redis host

### 2. Jalankan Services

```bash
# Full stack - semua service
docker compose --profile full up -d

# Monitoring only - node_exporter + promtail + loki
docker compose --profile monitoring up -d

# Without Grafana - prometheus + node_exporter + promtail + loki
docker compose --profile no-grafana up -d
```

### 3. Akses Dashboard

- **Grafana**: http://server-ip:6789
- **Default credentials**: admin / (lihat di .env GF_SECURITY_ADMIN_PASSWORD)

### 4. Stop Services

```bash
# Stop containers saja
docker compose --profile full down

# Stop + hapus containers
docker compose --profile full down --remove-orphans

# Stop + hapus containers + networks (tapi volume tetap)
docker compose --profile full down --remove-orphans --network

# Stop + hapus SEMUA (containers + networks + volumes + images)
docker compose --profile full down -v --remove-orphans
```

### Hapus Semua Data (Volumes)

```bash
docker compose down -v --remove-orphans
```

## Profiles

### full
Semua service termasuk Grafana + Nginx reverse proxy.
Gunakan untuk centralized monitoring server (DEV atau QA).

### monitoring
node_exporter + postgres_exporter + redis_exporter + promtail + loki.
Gunakan untuk agent server yang hanya kirim data.

### no-grafana
prometheus + node_exporter + promtail + loki.
Tanpa Grafana.

## Nginx Config

### Approach A
- http://server-ip:6789/ → Grafana
- http://server-ip:6789/prometheus → Prometheus
- http://server-ip:6789/loki → Loki

### Approach B
- http://server-ip:6789/ → Grafana saja
- Prometheus & Loki diakses internal dari Grafana

Ganti `nginx` ke `nginx-b` di docker-compose.yml untuk pakai Approach B.

## Remote Configuration (DEV ↔ QA)

### Jika centralized di DEV:

Di **DEV .env**:
```bash
SERVER_ENV=dev
SERVER_NAME=dev-sharecar
```

Di **QA .env** (untuk remote scrape):
```bash
SERVER_ENV=qa
SERVER_NAME=qa-sharecar
```

Tambahkan ke prometheus.yml untuk scrape QA dari DEV:
```yaml
- job_name: 'qa-server'
  static_configs:
    - targets: ['qa-ec2-ip:9100', 'qa-ec2-ip:9187', 'qa-ec2-ip:9121']
      labels:
        env: 'qa'
```

## Volumes

Data tersimpan di named volumes:
- `sharecar-monitoring-prometheus-data`
- `sharecar-monitoring-loki-data`
- `sharecar-monitoring-grafana-data`

## Network

Docker network: `sharecar-monitoring-network`

## Troubleshooting

### Logs

```bash
# Semua service
docker compose logs -f

# Specific service
docker compose logs -f prometheus
docker compose logs -f grafana
```

### Restart service

```bash
docker compose restart <service-name>
```

### Check status

```bash
docker compose ps
```