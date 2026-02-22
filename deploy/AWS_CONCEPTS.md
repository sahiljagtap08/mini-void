# AWS Concepts — Plain English

## The mental model

Think of AWS like renting a data center, piece by piece.
You don't own servers. You rent capacity and AWS manages the hardware.

---

## Docker Image vs Container vs Server

```
Image     = a blueprint. Your code + dependencies, frozen in time.
Container = a running instance of that blueprint. Like a process.
Server    = the machine running your containers.
```

One image can run as 1 container or 1000 containers.
Same blueprint, many copies.

With ECS Fargate, you never see or manage the server.
AWS picks a machine, runs your container on it, you just pay per second.

---

## What is an ECS Cluster?

A cluster is just a **logical boundary** — a named group that holds your services.

It is NOT a server. It does NOT mean many microservices.

Think of it like a folder:
```
cluster: mini-void-cluster
  └── service: mini-void-service
        └── task: 1 running container (your app)
```

You have one image → one service → one task (for now).
The cluster is just the container for all of that.

---

## Task vs Service

```
Task Definition = the recipe. "Run THIS image with THIS much CPU and RAM."
Task            = one running container, created from that recipe.
Service         = a manager that says "keep N tasks alive at all times."
```

If your task crashes, the service restarts it automatically.
If you want 3 copies for traffic, set desired count = 3.

---

## What is a VPC?

VPC = Virtual Private Cloud.

It's your **private network** inside AWS.
Every AWS account gets a default VPC automatically.

Think of it like your home WiFi network — but in the cloud.
Only things inside the VPC can talk to each other by default.

---

## What is a Subnet?

A subnet is a **slice** of your VPC network.

```
VPC: 10.0.0.0/16  (your whole network)
  ├── Subnet A: 10.0.1.0/24  (us-east-1a)
  ├── Subnet B: 10.0.2.0/24  (us-east-1b)
  └── Subnet C: 10.0.3.0/24  (us-east-1c)
```

Each subnet lives in one Availability Zone (one physical data center).
Spreading across subnets = your app survives if one data center goes down.

### Public vs Private Subnet

```
Public subnet  = has a route to the internet. Can be reached from outside.
Private subnet = no direct internet access. Internal only.
```

Common pattern:
```
Internet
   ↓
Load Balancer          ← lives in PUBLIC subnet
   ↓
App containers         ← live in PRIVATE subnet
   ↓
Database               ← lives in PRIVATE subnet
```

For our mini app we put everything in a public subnet to keep it simple.
In production, your app and DB go in private subnets.

---

## What is API Gateway?

API Gateway is NOT the same as public/private subnets.
That's a networking concept. API Gateway is a separate AWS service.

API Gateway = a managed HTTP router in front of your app.
It handles: rate limiting, auth, request validation, routing to Lambda or ECS.

You don't need it for ECS. It's mainly used with Lambda (serverless functions).
For ECS, you use a Load Balancer instead.

---

## Is ECS autoscaling?

Yes — but you configure it.

By default: 1 task, fixed. If it crashes, the service restarts it.

You can add:
- **Service Auto Scaling**: add more tasks when CPU > 70%
- **Target Tracking**: keep average CPU at 50%, scale up/down automatically

We're not doing this yet. One task is fine for Level 1.

---

## Is ECS like Kubernetes?

Yes. Same idea, different implementation.

```
Kubernetes (k8s)    = open source, runs anywhere, very powerful, very complex
ECS                 = AWS-only, simpler, managed by AWS, less to configure
```

Concepts that map between them:

| Kubernetes     | ECS               |
|----------------|-------------------|
| Pod            | Task              |
| Deployment     | Service           |
| Node           | EC2 / Fargate     |
| Cluster        | Cluster           |
| Namespace      | Cluster (roughly) |
| kubectl        | aws ecs CLI       |

Kubernetes gives you more control and portability.
ECS gives you less overhead and native AWS integration.

For a solo founder or small team on AWS: ECS is the right call.
Kubernetes is overkill until you have a platform team.

---

## The full picture of what we deployed

```
Internet
   │
   ▼
Security Group (firewall — allows port 8000)
   │
   ▼
Fargate Task (your container, public IP assigned)
   │
   ├── Reads OPENAI_API_KEY from SSM (secure storage)
   ├── Writes brain.db to /app/data/
   └── Serves your FastAPI app on port 8000

All of this lives inside:
  VPC → Subnet → ECS Cluster → Service → Task
```

---

## What each AWS service costs (roughly)

| Service       | Cost                                      |
|---------------|-------------------------------------------|
| Fargate       | ~$0.01/hr for 0.25 vCPU + 512MB          |
| ECR           | $0.10/GB stored (your image is ~200MB)   |
| SSM Parameter | Free for standard parameters              |
| CloudWatch    | Free tier covers basic logs              |

Mini void running 24/7 = ~$7/month.
