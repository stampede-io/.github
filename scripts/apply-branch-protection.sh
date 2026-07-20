#!/usr/bin/env bash
# STAM-99: Apply branch protection to `main` on all stampede-io repos.
# Requires: gh CLI, authenticated with an account that has admin on stampede-io.
# Usage: ./apply-branch-protection.sh

set -euo pipefail

ORG="stampede-io"

# repos that run the shared CI workflow. The required status check context is
# "ci / build": GitHub names a reusable-workflow check "{caller job} / {reusable
# job}", and every repo's ci.yml calls the shared workflow from a job named `ci`,
# whose `build` job does the work. This must match exactly or merges block.
CI_REPOS=(STAM-gateway STAM-identity STAM-catalog STAM-booking STAM-payment STAM-notification STAM-frontend)
CI_CHECK_CONTEXT="ci / build"

# repos with no CI workflow yet — protection without a required status check
NO_CI_REPOS=(STAM-platform STAM-gitops)

protect_with_ci() {
  local repo="$1"
  echo "Protecting ${ORG}/${repo} (main) — required check: ${CI_CHECK_CONTEXT}"
  gh api "repos/${ORG}/${repo}/branches/main/protection" \
    --method PUT \
    --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "checks": [{ "context": "${CI_CHECK_CONTEXT}" }]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
}

protect_without_ci() {
  local repo="$1"
  echo "Protecting ${ORG}/${repo} (main) — no required status check yet"
  gh api "repos/${ORG}/${repo}/branches/main/protection" \
    --method PUT \
    --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
}

for repo in "${CI_REPOS[@]}"; do
  protect_with_ci "$repo"
done

for repo in "${NO_CI_REPOS[@]}"; do
  protect_without_ci "$repo"
done

echo "Done. Verify with: gh api repos/${ORG}/<repo>/branches/main/protection"
