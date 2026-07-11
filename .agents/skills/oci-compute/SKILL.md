---
name: oci-compute
description: OCI Compute — instances, shapes, OKE, Container Instances, Functions, and Autoscaling
license: MIT
allowed-tools: shell, read_file, write_file, glob, grep
metadata:
  triggers: oci, oracle cloud, oci compute, compute, vm, vms, instances, oke, container instances, functions, autoscaling
  version: 1.0.0
  updated: 2026-06-26
---

# OCI Compute

## Always Free Tier

You are constrained to just the Always Free tier for OCI Compute resources. This includes:
- 2 AMD-based VMs (VM.Standard.A1.Flex) with 1 OCPU and 1 GB RAM each
OR
- 4 Arm-based VMs (VM.Standard.A1.Flex) with 1 OCPU and 6 GB RAM each (can be combined for 4 OCPUs and 24 GB RAM total)

For networking always make sure to enable IPv6.

## Instance Shapes

OCI shapes define CPU, memory, and network for compute instances.

### Shape Families
| Family | Use Case | Notes |
|--------|----------|-------|
| `VM.Standard.E4.Flex` | General purpose (AMD EPYC) | Most cost-effective flex shape |
| `VM.Standard.E5.Flex` | General purpose (AMD EPYC 4th gen) | Newer, higher performance |
| `VM.Standard.A1.Flex` | Arm (Ampere Altra) | Cheapest per OCPU — Always Free eligible |
| `VM.Standard3.Flex` | General purpose (Intel) | Intel Xeon |
| `VM.GPU.A10.1` | ML/AI inference | NVIDIA A10, 24 GB VRAM |
| `VM.GPU.A100.2` | ML/AI training | 2x NVIDIA A100 80 GB |
| `BM.GPU.A100-v2.8` | Large-scale training | 8x A100, bare metal |
| `VM.DenseIO2.16` | NVMe storage | Local NVMe, fast I/O |
| `BM.HPC2.36` | HPC | RDMA networking, bare metal |
| `VM.Optimized3.Flex` | High-frequency compute | Intel, higher clock speed |

### Flex Shape Config
```bash
# List available shapes with OCPU/memory limits
oci compute shape list --compartment-id $C --all | \
  jq '.data[] | select(.shape | startswith("VM.Standard")) | {shape, ocpuOptions, memoryOptions}'

# Launch flex instance
oci compute instance launch \
  --compartment-id $C \
  --availability-domain "kWVD:US-ASHBURN-AD-1" \
  --shape "VM.Standard.E4.Flex" \
  --shape-config '{"ocpus":4,"memoryInGBs":32}' \
  --image-id $IMAGE_ID \
  --subnet-id $SUBNET_ID \
  --display-name "flex-vm" \
  --assign-public-ip true
```

## Finding Images

```bash
# List Oracle platform images
oci compute image list --compartment-id $C \
  --operating-system "Oracle Linux" \
  --operating-system-version "9" \
  --shape "VM.Standard.E4.Flex" \
  --sort-by TIMECREATED --sort-order DESC \
  --limit 5 --output table

# List Ubuntu images
oci compute image list --compartment-id $C \
  --operating-system "Canonical Ubuntu" \
  --operating-system-version "22.04" \
  --shape "VM.Standard.E4.Flex" \
  --sort-by TIMECREATED --sort-order DESC --limit 3

# Get the latest image OCID
LATEST_IMAGE=$(oci compute image list --compartment-id $C \
  --operating-system "Oracle Linux" \
  --operating-system-version "9" \
  --sort-by TIMECREATED --sort-order DESC \
  --query 'data[0].id' --raw-output)
```

## Boot Volumes

```bash
# Increase boot volume size (must stop instance first)
oci compute instance action --instance-id $INST_ID --action STOP
oci bv boot-volume update --boot-volume-id $BV_ID --size-in-gbs 200

# Create custom image from instance
oci compute image create \
  --compartment-id $C \
  --instance-id $INST_ID \
  --display-name "my-golden-image-$(date +%Y%m%d)"

# Clone boot volume
oci bv boot-volume create \
  --availability-domain "kWVD:US-ASHBURN-AD-1" \
  --compartment-id $C \
  --source-details '{"type":"bootVolume","id":"'$BV_ID'"}'
```


## Gotchas & Tips

- **Flex shapes** — `ocpus` and `memoryInGBs` must be within shape limits. Memory-to-CPU ratio must stay between 1–64 GB per OCPU for E4.Flex.
- **Always Free A1** — 4 OCPUs / 24 GB RAM total across all A1 instances in a tenancy (in Always Free). Very generous for hobbyists.
- **OKE VCN-native pods** — `OCI_VCN_IP_NATIVE` CNI assigns pod IPs from VCN CIDR, enabling direct routing without overlay. Requires pod subnet CIDR planning upfront.
- **OKE cluster endpoint** — use `PRIVATE_ENDPOINT` for production (bastion or VPN required for kubectl access). `PUBLIC_ENDPOINT` is convenient but exposes API server.
- **Functions cold start** — Fn functions cold start takes 3–10 seconds. Use provisioned concurrency for latency-sensitive workloads (available via OCI CLI).
- **Instance pool + LB** — attach instance pool to a load balancer backend set so new instances auto-register: add `--load-balancers` to pool create.
- **Boot volume performance** — default boot volumes run at "balanced" VPU. Upgrade to "higher performance" (VPU=20) for production databases. Flex VPU costs extra.
- **Custom images cross-region** — use `oci compute image copy` to replicate golden images to other regions. Same OCID won't work across regions.