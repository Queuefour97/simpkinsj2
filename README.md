# Name: Jorune Simpkins
# Date: 05/07/2026
# Document: Readme

# Assignment: GCP Cloud Infrastructure Lab — Week 8
## Focus: Instance Groups, Load Balancing & Terraform

---

## Table of Contents
1. [Q & A](#section-1-q--a)
2. [Runbook — Managed Instance Group via GCP Console](#section-2-runbook)
3. [Terraform Concepts](#section-3-terraform-concepts)
4. [Resources Used](#resources-used)

---

## Section 1: Q & A

### What is the difference between high availability and fault tolerance? Which is best to strive for?

**High Availability (HA)** means a system is designed to minimize downtime — if something fails, it recovers quickly (usually in seconds or minutes). The system may briefly go unavailable but bounces back fast. **Fault Tolerance** is a stricter standard: the system continues operating *with zero interruption* even when components fail, often through full redundancy (e.g., two active copies of everything running simultaneously). Neither is universally "best" — fault tolerance is more expensive and complex to build, so the right choice depends on your SLA and budget. For most production systems, high availability is the practical target; fault tolerance is reserved for mission-critical systems where even seconds of downtime are unacceptable (e.g., financial transactions, air traffic control).

---

### Explain the difference between autoscaling and elasticity. What is vertical and horizontal autoscaling? Is one better? Are they feasible on-prem?

**Elasticity** is the *concept* — the ability of a system to expand and contract resources based on demand. **Autoscaling** is the *mechanism* that implements elasticity automatically without human intervention. Think of elasticity as the goal and autoscaling as the tool.

**Vertical autoscaling** (scaling *up/down*) means adding more power to an existing machine — more CPU, more RAM. It's simple but has a physical ceiling and usually requires a restart. **Horizontal autoscaling** (scaling *out/in*) means adding or removing more instances of a machine. It's more complex to set up (requires stateless apps and a load balancer) but scales much further and has no theoretical ceiling in the cloud.

Neither is inherently better — horizontal is preferred in cloud-native architectures because it avoids single points of failure and scales further. On-prem, both are technically feasible but difficult in practice: vertical scaling requires physically installing hardware, and horizontal scaling requires having spare servers ready, provisioning them, and maintaining the extra infrastructure cost even when idle.

---

### Explain the difference between managed and unmanaged instance groups.

A **Managed Instance Group (MIG)** uses an *instance template* to create and manage identical VMs automatically. The MIG handles autoscaling, autohealing (replacing unhealthy instances), rolling updates, and multi-zone distribution. All VMs in the group are interchangeable. An **Unmanaged Instance Group** is simply a flat collection of pre-existing VMs you group together — GCP does not manage their lifecycle, configuration, or health. You add and remove instances manually. Unmanaged groups are useful for legacy setups or when your VMs are intentionally different from each other, but they miss out on all the automation benefits. For any new workload, you almost always want a managed instance group.

---

### Explain the different use cases for health checks used by applications (in instance groups) and health checks used by load balancers. Can they be the same? Are they different API calls? Should they be the same?

**Autohealing health checks** (attached to a MIG) answer the question: *"Is this VM alive enough to keep running?"* They're intentionally lenient — the failure threshold is set high so GCP doesn't prematurely kill and recreate an instance that's just slow to start up. If this check fails repeatedly, the MIG replaces the VM.

**Load balancer health checks** answer a stricter question: *"Is this VM ready to receive user traffic?"* They remove an instance from the serving pool the moment it becomes degraded, even if the VM itself is technically still running.

They *can* be the same health check resource (same API object: `compute.healthChecks`) — they are not different API calls. But they *should not* be configured identically. The autohealing check should have a high failure threshold (be patient before killing a VM), while the load balancer check should be more aggressive (quickly pull a bad instance from rotation). Using two separate, purpose-tuned health check resources is best practice.

---

### Explain in a few sentences what the 3-tier architecture is and how it relates to what you are learning.

**3-tier architecture** divides an application into three logical layers: the **presentation tier** (the frontend — web servers serving HTML/assets to users), the **application tier** (business logic — APIs and app servers that process requests), and the **data tier** (databases and storage). Each tier is isolated, can scale independently, and only communicates with the tier adjacent to it. This maps directly to what we're building: a load balancer sits in front of the presentation tier (our MIG of web servers), which would talk to an app tier, which in turn talks to a database. GCP's Application Load Balancer is explicitly designed for this pattern and their docs include a three-tier web services reference architecture.

---

## Section 2: Runbook

### End Goal

Provision a regional Managed Instance Group (MIG) in GCP that automatically maintains a fleet of identical VMs distributed across multiple zones, with autoscaling based on CPU load and autohealing to replace unhealthy instances without manual intervention. The MIG uses an instance template so every VM is created from an identical configuration, enabling zero-touch scaling and self-healing. The result is a resilient, self-managing compute layer ready to sit behind a load balancer.

---

### Prerequisites

Confirm the following before starting:

- GCP project exists with billing enabled
- You have `Editor` or `Compute Admin` IAM role on the project
- **Compute Engine API** is enabled (`APIs & Services → Enable APIs → Compute Engine API`)
- A **network tag** and matching **firewall rule** allowing port 80 ingress exists (or use `http-server` tag with default VPC which has this built in)
- You know your target **region** (e.g., `us-central1`)

---

### Steps: Create a Managed Instance Group via GCP Console

#### Step 1 — Create an Instance Template

1. **Compute Engine → Instance Templates → Create Instance Template**
2. Set **Name** (e.g., `web-server-template`)
3. Set **Machine type** (e.g., `n2-standard-2`)
4. Under **Boot disk → Change**: select your OS image (e.g., CentOS Stream 10), set disk size (e.g., 100 GB), click **Select**
5. Under **Networking → Network tags**: add `http-server`
6. Under **Advanced → Automation → Startup script**: paste your startup script (see startup script section below)
7. Click **Create**

#### Step 2 — Create the Managed Instance Group

1. **Compute Engine → Instance Groups → Create Instance Group**
2. Select **New managed instance group (stateless)**
3. Set **Name** (e.g., `web-mig`)
4. **Instance template**: select the template from Step 1
5. **Location**: set to **Multiple zones**, select your **Region**
6. Confirm zones are listed (GCP auto-selects; you can customize)
7. Set **Minimum instances**: `2`, **Maximum instances**: `10` (adjust to your needs)

#### Step 3 — Configure Autoscaling

1. **Autoscaling mode**: `On: add and remove instances to the group`
2. **Autoscaling signal**: CPU utilization, target `60%`
3. **Cooldown period**: `60` seconds
4. Leave scale-in controls at default unless you need to prevent rapid scale-down

#### Step 4 — Configure Autohealing

1. Under **Autohealing → Add a health check** (or create new):
   - Protocol: `HTTP`, Port: `80`, Path: `/`
   - Check interval: `10s`, Timeout: `5s`
   - Healthy threshold: `2`, Unhealthy threshold: `3`
2. **Initial delay**: set to `300` seconds minimum — this is how long the MIG waits before enforcing health checks on a new instance. Set this *longer than your startup script takes to complete* or the MIG will repeatedly kill instances that are still booting.

#### Step 5 — Create

1. Review the config summary — verify: multiple zones, autoscaling on, health check attached, initial delay set
2. Click **Create**
3. Monitor under **Instance Groups → [MIG name] → Instances tab** — wait for instances to show `Running` and pass health checks

---

### Verify Multi-Zone Distribution

- **Compute Engine → Instance Groups → [MIG name] → Details tab**: confirm `Location type: Multiple zones`
- **Instances tab**: verify VMs show different zones (e.g., `us-central1-a`, `us-central1-b`, `us-central1-c`)
- CLI alternative: `gcloud compute instance-groups managed list-instances [MIG_NAME] --region=[REGION]` — check the `ZONE` column

---

### Other Critical Configuration Notes

- **Named ports**: If attaching a load balancer later, set a named port on the MIG (`http:80`) under **Edit → Named ports**. The load balancer backend service requires this to route traffic correctly.
- **Update policy**: Under **Edit**, set update policy to `Proactive`, `Max surge: 1`, `Max unavailable: 0` for zero-downtime rolling updates.
- **Initial delay is critical**: If your startup script takes 3 minutes and your initial delay is 60 seconds, the MIG will enter a thrash loop — killing and recreating instances that are actually still initializing. When in doubt, set it higher.
- **Cleanup**: To fully tear down — **Compute Engine → Instance Groups → [MIG name] → Delete** — check the box to also delete managed instances. This stops all VMs and removes the MIG.

---

## Section 3: Terraform Concepts

### Mandatory (Required) Arguments for a GCP VM in Terraform

The `google_compute_instance` resource has these required arguments — `terraform validate` will fail without them:

| Argument | Description |
|---|---|
| `name` | The name of the VM. Must be unique within the project + zone. |
| `machine_type` | Determines CPU and RAM (e.g., `n2-standard-2`). |
| `boot_disk` | Root disk block. Requires nested `initialize_params { image = "..." }` at minimum. |
| `network_interface` | Which VPC to attach to. At minimum: `network = "default"`. |

> `zone` is optional (falls back to the provider default) but should always be set explicitly.

---

### How to Output Internal and External IP Addresses

Internal and external IPs are *computed attributes* — GCP assigns them after the VM is created, then Terraform reads them back. They are not arguments you set.

**How to find them:** Check the [Terraform Registry docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) for `google_compute_instance` → scroll to **Attributes Reference**:

- `network_interface[0].network_ip` → internal IP
- `network_interface[0].access_config[0].nat_ip` → external IP

The external IP only exists if you include an `access_config {}` block inside `network_interface` — that block is what tells GCP to assign an ephemeral public IP.

```hcl
output "internal_ip" {
  description = "The internal (private) IP of the VM"
  value       = google_compute_instance.vm.network_interface[0].network_ip
}

output "external_ip" {
  description = "The external (public) IP of the VM"
  value       = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}
```

---

### Two Non-Required Arguments (with Explanations)

#### 1. `metadata` — startup-script

The `metadata` map passes key-value pairs into the VM at boot time via GCP's metadata server. The guest agent running inside the VM reads certain well-known keys — the most important being `startup-script`, which executes a shell script on first boot. This is how you install and configure software without baking it into a custom OS image. It keeps your instance template generic and your configuration in code.

```hcl -HashiCorp Configuration Language
metadata = {
  startup-script = file("startup.sh")
}
```

#### 2. `tags`

Network tags are string labels on a VM that GCP firewall rules use as selectors. They have no effect on performance — they purely control which firewall rules apply to this VM. Tagging a VM `http-server` causes GCP's default VPC firewall rule (`default-allow-http`) to automatically allow inbound TCP port 80 to that VM. Without this tag (or an equivalent explicit firewall rule), your web server will be unreachable from the internet even if Apache is running correctly.

```hcl - HashiCorp Configuration Language
tags = ["http-server"]
```

---

### How to Find the Correct CentOS Stream 10 Image

GCP images live in image projects. CentOS images are in the `centos-cloud` project.

**Option 1 — gcloud CLI:**
```bash
gcloud compute images list --project=centos-cloud --no-standard-images
# Look for something like: centos-stream-10-v20240xxx
```

**Option 2 — Use the image family** (recommended — always pulls latest):
```hcl
initialize_params {
  image = "projects/centos-cloud/global/images/family/centos-stream-10"
  size  = 100
}
```

Using the family reference means Terraform always uses the most recently published image in that family. Pinning a specific image name works too but requires manual updates when the image is deprecated.

---

### The Difference Between `name`, `id`, and `self_link`

| Attribute | Type | Example Value | Purpose |
|---|---|---|---|
| `name` | **Input argument** (you set it) | `"my-vm"` | Human-readable label. Shown in the Console and used in CLI commands. Not globally unique on its own. |
| `id` | **Computed** (GCP assigns) | `"projects/my-proj/zones/us-central1-a/instances/my-vm"` | Fully-qualified unique identifier. Terraform uses this internally to track and reconcile state. |
| `self_link` | **Computed** (GCP assigns) | `"https://www.googleapis.com/compute/v1/projects/my-proj/zones/us-central1-a/instances/my-vm"` | Full REST API URL for the resource. Used when one GCP resource needs to reference another in config (e.g., attaching a VM to a target pool). |

In practice: set `name` yourself, reference `self_link` when wiring GCP resources together in Terraform, and `id` is mostly used by Terraform's state engine internally.

---

### The Startup Script

This is the startup script used by the VM. It installs Apache, pulls instance metadata, and writes a simple HTML page showing the VM's name and internal IP.

```bash
#!/bin/bash

# $META and $HEADER are defined here to keep the curl commands below readable
META="http://metadata.google.internal/computeMetadata/v1/instance"
HEADER="Metadata-Flavor: Google"

# $NAME and $IP are fetched from GCP's metadata service — every GCP VM
# can query this internal endpoint to learn about itself at runtime
NAME=$(curl -H "$HEADER" "$META/name")
IP=$(curl -H "$HEADER" "$META/network-interfaces/0/ip")

# Use dnf (not apt) — CentOS is RHEL-based
dnf install -y httpd

# Write the HTML page to the default Apache web root
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<body>
  <h1>VM Metadata</h1>
  <h2>Instance Name: $NAME</h2>
  <h2>Internal IP: $IP</h2>
  <h2>Colombian prize included for free!</h2>
  <figure>
    <img src="https://test-1256099743.s3.us-east-2.amazonaws.com/Colombian/imgi_22_551283556_24677511425231259_7293143846320648055_n.jpg" alt="Colombian prize!" style="max-width:600px; width:100%; display:block; margin:1rem 0;">
    <figcaption>Colombian prize!</figcaption>
  </figure>
</body>
</html>
EOF

# Enable and start Apache — the --now flag starts it immediately
# 'enable' makes it persist across reboots
systemctl enable --now httpd
```

---

## Resources Used

| Resource | How It Was Used |
|---|---|
| [GCP Instance Groups Overview](https://cloud.google.com/compute/docs/instance-groups#managed_instance_groups) | Understood managed vs. unmanaged groups; informed Q&A answer and runbook |
| [GCP Load Balancing Overview](https://cloud.google.com/load-balancing?hl=en) | Referenced for load balancer health check behavior vs. autohealing health checks |
| [Application Load Balancer Docs](https://docs.cloud.google.com/load-balancing/docs/application-load-balancer) | Backend service → MIG wiring via named ports |
| [Three-Tier Web Services Architecture](https://docs.cloud.google.com/load-balancing/docs/application-load-balancer#three-tier_web_services) | 3-tier architecture Q&A answer |
| [GCP Infrastructure Reliability Guide](https://docs.cloud.google.com/architecture/infra-reliability-guide/design) | HA vs. fault tolerance definitions and design patterns |
| [Terraform google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | Required args, computed attributes (`network_ip`, `nat_ip`, `self_link`, `id`), argument syntax |
| [Terraform google_compute_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | BAM1 custom VPC resource |
| [Terraform google_compute_instance_template](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | BAM2 instance template resource |
| startup-for-rhel.sh (provided by instructor) | Included as the `startup-script` metadata value; CentOS uses `dnf` not `apt` |
