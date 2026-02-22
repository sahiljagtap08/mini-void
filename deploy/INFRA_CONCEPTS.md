# Infrastructure Concepts — Plain English

---

## Public Domain

Right now your app has an IP like `http://54.23.11.4:8000`.
That's ugly and changes every time the container restarts.

To get `https://yourdomain.com` you need three things:

```
1. Domain name    → buy from Route 53 (AWS) or Namecheap (~$12/yr)
2. Load Balancer  → gives you a stable DNS name, handles HTTPS
3. SSL cert       → free via AWS Certificate Manager (ACM)
```

The flow:
```
yourdomain.com
      ↓
Route 53 (DNS — translates name → IP)
      ↓
ALB - Application Load Balancer (stable endpoint, handles SSL)
      ↓
ECS Service (your containers, in private subnet)
```

Why a Load Balancer and not just a domain pointing to the IP?
- Container IPs change on every restart
- ALB gives you a stable DNS name that never changes
- ALB terminates HTTPS so your app only deals with plain HTTP internally
- ALB can route to multiple containers when you scale

We're not doing this yet. For Level 1 the raw IP is fine.

---

## Security — Vulnerabilities and Exploits

Security has layers. Think of it like an onion.

### Layer 1 — Network (what can reach your app)
```
Security Group = AWS firewall around your container
```
Right now we allow port 8000 from anywhere (0.0.0.0/0).
In production you close that and only allow the Load Balancer.

```
Bad:   Internet → port 8000 → your app    (direct, exposed)
Good:  Internet → ALB → port 8000 → app   (ALB is the only entry point)
```

### Layer 2 — Secrets (API keys, DB passwords)
Never hardcode secrets. We're already doing this right:
- API key lives in SSM Parameter Store
- .env is in .gitignore
- Container reads it at runtime, never baked into the image

### Layer 3 — Application (your code)
Common vulnerabilities to know:
```
SQL Injection     → malicious input manipulates your DB query
XSS               → malicious script injected into your HTML
Prompt Injection  → malicious input manipulates your LLM prompt
Broken Auth       → no authentication = anyone can use your app
Rate Limiting     → no limits = someone can drain your OpenAI credits
```

For mini-void right now: anyone who finds your IP can call /store and /ask
and burn your OpenAI credits. That's the most immediate risk.

Fix later: add an API key header check before we go public.

### Layer 4 — Dependencies
Your libraries (fastapi, openai, etc.) can have vulnerabilities.
`pip audit` scans them. GitHub Dependabot alerts you automatically.

### Layer 5 — Infrastructure
- Use private subnets for anything sensitive
- Use IAM roles with minimum permissions (least privilege)
- Enable CloudTrail (logs every AWS API call)
- Enable GuardDuty (AWS threat detection)

We'll add these as we grow. Don't boil the ocean on day 1.

---

## Staging vs Production

This is about having two separate environments:

```
staging    = fake production. You break things here. No real users.
production = real users. Real data. You don't break things here.
```

Why separate?
- You don't test new code directly on real users
- A bug in staging is embarassing. A bug in production loses customers.

How it works:
```
Your laptop  →  push code to GitHub
                     ↓
              GitHub Actions runs tests
                     ↓
              Auto-deploy to STAGING
                     ↓
              You test it manually
                     ↓
              You approve → deploy to PRODUCTION
```

In AWS terms, staging and production are just two separate copies of everything:
```
staging:
  ECS cluster: mini-void-staging
  SSM params:  /mini-void/staging/OPENAI_API_KEY
  Domain:      staging.yourdomain.com

production:
  ECS cluster: mini-void-prod
  SSM params:  /mini-void/prod/OPENAI_API_KEY
  Domain:      yourdomain.com
```

Same code, different config, different infrastructure.

---

## What is CI? (Continuous Integration)

CI = every time you push code, automated checks run immediately.

```
You push code to GitHub
        ↓
GitHub Actions wakes up
        ↓
  - installs dependencies
  - runs your tests
  - checks code formatting
  - scans for security issues
        ↓
  PASS → green checkmark, safe to deploy
  FAIL → red X, fix it before it goes anywhere
```

The "continuous" part means this happens on every single push, automatically.
Not manually. Not sometimes. Every time.

Why this matters:
- Catches bugs before they reach users
- Enforces code quality automatically
- Nobody can accidentally push broken code to production

---

## What is CD? (Continuous Deployment / Delivery)

CD = after CI passes, the code is automatically deployed.

```
Continuous Delivery   = CI passes → ready to deploy (you still click a button)
Continuous Deployment = CI passes → deployed automatically, no human needed
```

Most teams use Continuous Delivery for production (human approves)
and Continuous Deployment for staging (fully automatic).

Full CI/CD flow:
```
git push origin main
        ↓
GitHub Actions: run tests          ← CI
        ↓ (if tests pass)
GitHub Actions: deploy to staging  ← CD (automatic)
        ↓ (you review staging)
GitHub Actions: deploy to prod     ← CD (manual approval)
```

---

## The full roadmap in one picture

```
Level 1 (now):
  Local → Docker → ECS → raw IP

Level 2:
  + Load Balancer
  + Custom domain
  + HTTPS

Level 3:
  + Staging environment
  + Production environment
  + GitHub CI (tests run on push)

Level 4:
  + GitHub CD (auto-deploy to staging)
  + Manual approval gate for prod

Level 5:
  + S3 ingestion (upload files, not just paste text)
  + OpenSearch (replace FAISS, production-grade vector search)
  + Rate limiting
  + Auth

Level 6:
  + Monitoring (CloudWatch dashboards)
  + Alerting (PagerDuty or SNS)
  + Cost tracking
```

You are at Level 1.
Each level is earned, not skipped.
