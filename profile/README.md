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
[![React](https://img.shields.io/badge/React-19-61DAFB?logo=react&logoColor=black)](https://react.dev/)
[![OAuth 2.1](https://img.shields.io/badge/OAuth_2.1-PKCE-000000?logo=auth0&logoColor=white)](https://oauth.net/2.1/)
[![release](https://img.shields.io/badge/release-v0.2.0-blue)](https://github.com/stampede-io/STAM-platform/releases/tag/v0.2.0)

</div>

---

## The Problem

When 10,000 fans rush to buy tickets the moment they drop, traditional architectures crumble. Double-bookings, lost payments, and silent failures erode trust. STAMPEDE solves this at the database level — not with hope, but with a **partial unique index** that makes overselling physically impossible.

## Architecture

```
                          Browser — React 19 SPA
                          PKCE auth, tokens in memory
                                     │
                                     ▼
                  ┌───────────────────────────────────┐
                  │           API Gateway             │
                  │      Spring Cloud Gateway         │
                  │  JWT via JWKS · Redis rate limit  │
                  │  correlationId · CORS             │
                  └──┬────────┬─────────┬─────────┬───┘
                     │        │         │         │
        ┌────────────┘        │         │         └────────────┐
        ▼                     ▼         ▼                      ▼
┌───────────────┐   ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Identity    │   │    Catalog    │  │    Booking    │  │    Payment    │
│               │   │               │  │   ★ core ★    │  │               │
│ OAuth 2.1     │   │ CQRS read     │◀─┤ oversell guard│  │ Stripe test   │
│ PKCE · RBAC   │   │ availability  │  │ event store   │  │ idempotency   │
│ refresh       │   │ projection    │  │ saga orch.    │  │ keys          │
│ rotation      │   │ Redis cache   │  │ outbox        │  │               │
└───────┬───────┘   └───┬───────┬───┘  └───┬───────┬───┘  └───┬───────┬───┘
        │               │       │          │       │          │       │
        │               │       └──── Feign + circuit breaker │       │
        │               │          (the only sync hop)        │       │
        │               │                                     │       │
        ▼               ▼                  ▼                  ▼       │
┌──────────────────────────────────────────────────────────────────┐  │
│   PostgreSQL 16 × 5 — one database per service, no shared schema │  │
└──────────────────────────────────────────────────────────────────┘  │
                                                                      │
┌──────────────────────────────────────────────────────────────────┐  │
│   Redis 7 — booking TTL holds · catalog cache · gateway buckets  │  │
└──────────────────────────────────────────────────────────────────┘  │
                                                                      │
   identity.audit    reservations.events    payments.commands ────────┘
        │                     │                      │   payments.events
        ▼                     ▼                      ▼
┌──────────────────────────────────────────────────────────────────┐
│              Apache Kafka (KRaft) — replayable event log         │
│           transactional outbox · CQRS projections · saga         │
└─────────────────────────────┬────────────────────────────────────┘
                              │ reservations.events
                              ▼
                     ┌────────────────┐
                     │  Notification  │
                     │ idempotent     │
                     │ consumer → SMTP│
                     └────────────────┘
```

The gateway → service edges are HTTP routing. Between the business services themselves, every edge is Kafka — with one exception: **booking → catalog** is a synchronous OpenFeign call for seat validation, wrapped in a Resilience4j circuit breaker so a catalog outage degrades booking instead of taking it down.

> The browser → gateway hop is proven end to end (STAM-440): a Playwright spec with no mocks drives the real SPA through the real gateway — PKCE login, seat map, a hold — and the gateway's BFF token handler keeps the refresh token out of the browser entirely (see the platform ADR-0005).

## Core Guarantees

| Guarantee | How |
|---|---|
| **Zero oversells** | Partial unique index on `reservation_seats (show_id, seat_id) WHERE status IN ('HELD','CONFIRMED')` — the database itself rejects the second live claim. Proven by `ContentionIT` (50 concurrent threads, exactly one HTTP 201) and by the k6 flash-sale DB check. |
| **Crash-safe booking** | Saga orchestrator persisted in `saga_instances`, plus a recovery sweep that re-drives any saga stuck past its deadline. `kill -9` mid-saga, restart, it converges — see `SagaRecoveryIT`. |
| **No lost events** | Transactional outbox — business state and the outbox row commit in the same DB transaction; a separate publisher ships to Kafka. This gives **at-least-once** delivery: nothing is lost if the process dies between commit and publish. |
| **No duplicate side effects** | At-least-once plus **idempotent consumers** (`processed_events` in catalog and notification, `idempotency_keys` in payment) de-duplicates redelivered events. The read-model projection and payment state converge exactly once; email delivery is best-effort de-dup, not transactional. The outbox alone gives neither. |
| **No lost payments** | Three compensation paths, all covered by integration tests: payment failed, hold expired, late auth after expiry. |
| **Replayable read models** | Kafka retains events by policy, not by consumption. Reset a consumer group to offset zero and the projection rebuilds — see `SeatAvailabilityReplayTest`. |

## Repository Map

| Repo | Purpose |
|---|---|
| [`STAM-catalog`](https://github.com/stampede-io/STAM-catalog) | Event/venue/show catalog with CQRS read model and Redis caching |
| [`STAM-booking`](https://github.com/stampede-io/STAM-booking) | Seat holds, contention guard, saga orchestrator |
| [`STAM-gateway`](https://github.com/stampede-io/STAM-gateway) | Spring Cloud Gateway — JWT validation, rate limiting, correlation IDs |
| [`STAM-identity`](https://github.com/stampede-io/STAM-identity) | OAuth2.1 Authorization Server — PKCE, refresh token rotation, RBAC |
| [`STAM-payment`](https://github.com/stampede-io/STAM-payment) | Stripe test-mode integration with configurable failure simulation |
| [`STAM-notification`](https://github.com/stampede-io/STAM-notification) | Event-driven email notifications |
| [`STAM-frontend`](https://github.com/stampede-io/STAM-frontend) | React SPA — seat map, hold countdown, PKCE checkout flow |
| [`STAM-platform`](https://github.com/stampede-io/STAM-platform) | Docker Compose dev stack, ADRs, load tests, Terraform and Helm (Sprint 3) |
| [`STAM-gitops`](https://github.com/stampede-io/STAM-gitops) | ArgoCD app-of-apps, environment configs (Sprint 3) |

## Tech Stack

### Shipped

**Backend** — Java 21 · Spring Boot 4.1 · Spring Cloud 2025.1 · Hibernate 7 · Flyway · Testcontainers

**Data** — PostgreSQL 16 · Redis 7 · Apache Kafka (KRaft)

**Frontend** — React 19 · Vite 6 · TypeScript 5.8 · Tailwind 4 · Vitest · Playwright E2E

**Delivery** — Docker · GitHub Actions (org-level reusable workflows) · GHCR

**Security** — OAuth 2.1 + PKCE · rotating refresh tokens with reuse detection · RBAC + BOLA protection · Redis token-bucket rate limiting · Trivy · TruffleHog

### Planned — Sprint 3 and beyond

**Platform** — Kubernetes (kind locally, k3s on Azure) · Terraform · Helm · Sealed Secrets

**Delivery** — ArgoCD · Argo Rollouts (canary 10→50→100%)

**Observability** — Prometheus · Grafana · Loki · OpenTelemetry

## Getting Started

```bash
# Clone all repos sibling-flat
git clone https://github.com/stampede-io/STAM-platform.git
cd STAM-platform && bash scripts/clone-all.sh

# Copy env and start the dev stack
cp compose-dev/.env.example compose-dev/.env
cd compose-dev && docker compose up -d --wait
```

Front door is the gateway on **`http://localhost:8085`**. Services are also exposed directly for debugging: catalog `:8081`, booking `:8082`, payment `:8083`, identity `:8084`, notification `:8086`. Kafka UI on `:8080`, Mailhog inbox on `:8025`.

## Roadmap

- [x] **Sprint 1 — Core + Saga** *(v0.1.0)*: walking skeleton, catalog CRUD, booking contention core, Kafka outbox, CQRS projection, orchestrated saga with compensation and crash recovery, CI pipeline
- [x] **Sprint 2 — Secured End-to-End** *(v0.2.0)*: OAuth 2.1 identity service, API gateway with JWT and rate limiting, Stripe test-mode payments, notification emails, React SPA with PKCE checkout, Playwright E2E
- [ ] **Sprint 3 — Kubernetes Platform** *(v0.3.0)*: kind + k3s, Terraform, Helm umbrella chart, ArgoCD GitOps, Sealed Secrets, Eureka/Config Server removal
- [ ] **Sprint 4 — Hardening**: observability stack, 5,000-VU load test, v1.0.0

## Architecture Decisions

Every significant choice is recorded as an ADR in [`STAM-platform/docs/adr`](https://github.com/stampede-io/STAM-platform/tree/main/docs/adr):
microservices over modular monolith (0001), orchestrated saga over choreography (0002), Kafka over RabbitMQ and SQS (0003), Kubernetes DNS over Eureka (0004).

---

<div align="center">

**Built with obsessive correctness.**

Every claim on this page is backed by a committed test, a k6 report, or a chaos drill.

</div>
