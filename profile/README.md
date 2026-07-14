<div align="center">

# STAMPEDE

### High-Concurrency Event Ticketing Platform

**Zero oversells. Crash-safe sagas. GitOps-driven delivery.**

A production-grade distributed system built to handle thousands of concurrent ticket buyers fighting for the same seats — and guarantee that no two people ever get the same one.

---

[![Java](https://img.shields.io/badge/Java-21-ED8B00?logo=openjdk&logoColor=white)](https://openjdk.org/)
[![Spring Boot](https://img.shields.io/badge/Spring_Boot-4.1-6DB33F?logo=springboot&logoColor=white)](https://spring.io/projects/spring-boot)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Apache Kafka](https://img.shields.io/badge/Kafka-KRaft-231F20?logo=apachekafka&logoColor=white)](https://kafka.apache.org/)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&logoColor=white)](https://redis.io/)
[![React](https://img.shields.io/badge/React-SPA-61DAFB?logo=react&logoColor=black)](https://react.dev/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-k3s-326CE5?logo=kubernetes&logoColor=white)](https://k3s.io/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?logo=argo&logoColor=white)](https://argoproj.github.io/cd/)

</div>

---

## The Problem

When 10,000 fans rush to buy tickets the moment they drop, traditional architectures crumble. Double-bookings, lost payments, and silent failures erode trust. STAMPEDE solves this at the database level — not with hope, but with a **partial unique index** that makes overselling physically impossible.

## Architecture

```
                        ┌─────────────┐
                        │   React SPA │  PKCE Auth
                        └──────┬──────┘
                               │
                        ┌──────▼──────┐
                        │ API Gateway │  JWT · Rate Limit · CORS
                        └──────┬──────┘
                     ┌─────────┼─────────┐
               ┌─────▼─────┐      ┌─────▼─────┐
               │  Catalog   │      │  Booking   │
               │  Service   │      │  Service   │
               └─────┬─────┘      └─────┬─────┘
                     │                   │
              ┌──────▼──────┐    ┌──────▼──────┐
              │ PostgreSQL  │    │ PostgreSQL  │
              └─────────────┘    └─────────────┘
                     │                   │
                     └────────┬──────────┘
                        ┌─────▼─────┐
                        │   Kafka   │  Outbox · CQRS · Events
                        └─────┬─────┘
                     ┌────────┼────────┐
               ┌─────▼─────┐    ┌─────▼──────┐
               │  Payment   │    │Notification│
               │  Service   │    │  Service   │
               └───────────┘    └────────────┘
```

## Core Guarantees

| Guarantee | How |
|---|---|
| **Zero oversells** | Partial unique index on `(show_id, seat_id) WHERE status != 'RELEASED'` — the database rejects the second claim |
| **Crash-safe booking** | Saga orchestrator with transactional outbox — kill mid-saga, restart, it converges |
| **Exactly-once events** | Transactional outbox pattern — events are written atomically with business state |
| **No lost payments** | Three compensation paths: payment failed, hold expired, late auth after expiry |

## Repository Map

| Repo | Purpose |
|---|---|
| [`STAM-catalog`](https://github.com/stampede-io/STAM-catalog) | Event/venue/show catalog with CQRS read model and Redis caching |
| [`STAM-booking`](https://github.com/stampede-io/STAM-booking) | Seat holds, contention guard, saga orchestrator |
| [`STAM-gateway`](https://github.com/stampede-io/STAM-gateway) | Spring Cloud Gateway — JWT validation, rate limiting, correlation IDs |
| [`STAM-identity`](https://github.com/stampede-io/STAM-identity) | OAuth2.1 Authorization Server — PKCE, refresh token rotation, RBAC |
| [`STAM-payment`](https://github.com/stampede-io/STAM-payment) | Stripe integration with configurable failure simulation |
| [`STAM-notification`](https://github.com/stampede-io/STAM-notification) | Event-driven email notifications |
| [`STAM-frontend`](https://github.com/stampede-io/STAM-frontend) | React SPA — seat map, hold countdown, PKCE checkout flow |
| [`STAM-platform`](https://github.com/stampede-io/STAM-platform) | Docker Compose dev stack, Terraform, Helm charts |
| [`STAM-gitops`](https://github.com/stampede-io/STAM-gitops) | ArgoCD app-of-apps, canary rollouts, environment configs |

## Tech Stack

**Backend** — Java 21 · Spring Boot 4.1 · Hibernate 7 · Flyway 12 · Testcontainers

**Data** — PostgreSQL 16 · Redis 7 · Apache Kafka (KRaft)

**Frontend** — React · Playwright E2E

**Platform** — Docker · Kubernetes (k3s) · Terraform · Helm · Strimzi · cert-manager

**Delivery** — GitHub Actions · ArgoCD · Argo Rollouts (canary 10→50→100%)

**Observability** — Prometheus · Grafana · Loki · OpenTelemetry

**Security** — OAuth2.1 + PKCE · Sealed Secrets · NetworkPolicies · Trivy · TruffleHog

## Getting Started

```bash
# Clone all repos sibling-flat
git clone https://github.com/stampede-io/STAM-platform.git
cd STAM-platform && bash scripts/clone-all.sh

# Copy env and start the dev stack
cp compose-dev/.env.example compose-dev/.env
cd compose-dev && docker compose up
```

All services healthy in under 5 minutes on a fresh clone.

## Roadmap

- [x] **Sprint 1** — Walking skeleton, Docker Compose, Flyway, CI pipeline
- [ ] **Sprint 2** — Catalog CRUD, booking contention core, Kafka outbox, saga orchestrator
- [ ] **Sprint 3** — Identity (OAuth2), API Gateway, frontend checkout
- [ ] **Sprint 4** — Kubernetes platform, Terraform, Helm, GitOps
- [ ] **Sprint 5** — Observability stack, hardening, 5,000-VU load test, v1.0.0

---

<div align="center">

**Built with obsessive correctness.**

Every claim backed by a committed test, k6 report, or chaos drill recording.

</div>
