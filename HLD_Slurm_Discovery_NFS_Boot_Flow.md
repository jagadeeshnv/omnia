# High-Level Design (HLD): Slurm Discovery & NFS Boot Flow

**Version:** 1.0  
**Date:** January 2026  
**Author:** Omnia Team  
**Status:** Draft

---

## Table of Contents

1. [Glossary](#1-glossary)
2. [Introduction](#2-introduction)
   - 2.1 [Scope](#21-scope)
   - 2.2 [References](#22-references)
   - 2.3 [Input Configuration](#23-input-configuration)
3. [Solution Architecture](#3-solution-architecture)
   - 3.1 [Architecture Constraints and Assumptions](#31-architecture-constraints-and-assumptions)
   - 3.2 [Architecture Control Flow](#32-architecture-control-flow)
   - 3.3 [Architecture Data Flow Diagram](#33-architecture-data-flow-diagram)
   - 3.4 [Actor / Action Matrix](#34-actor--action-matrix)
   - 3.5 [Architecture Threat Model](#35-architecture-threat-model)
4. [High Level Design of Architectural Components](#4-high-level-design-of-architectural-components)
   - 4.1 [Design Component – NFS Directory Structure](#41-design-component--nfs-directory-structure)
   - 4.2 [Design Component – Slurm Controller Configuration](#42-design-component--slurm-controller-configuration)
   - 4.3 [Design Component – Compute Node Configuration](#43-design-component--compute-node-configuration)
   - 4.4 [Design Component – Cloud-Init Templates](#44-design-component--cloud-init-templates)
   - 4.5 [Design Component – slurm_conf_merge Module](#45-design-component--slurm_conf_merge-module)
   - 4.6 [Design Component – Node Addition and Removal](#46-design-component--node-addition-and-removal)
5. [Unresolved Issues](#5-unresolved-issues)

---

## 1. Glossary

| Term | Definition |
|------|------------|
| **OIM** | Omnia Infrastructure Manager - the management node running Ansible playbooks |
| **Slurm** | Simple Linux Utility for Resource Management - HPC workload manager |
| **slurmctld** | Slurm controller daemon - manages job scheduling and cluster state |
| **slurmd** | Slurm compute daemon - runs on each compute node |
| **slurmdbd** | Slurm database daemon - handles accounting data |
| **Munge** | Authentication service used by Slurm for secure communication |
| **NFS** | Network File System - used for shared configuration storage |
| **PXE** | Preboot Execution Environment - network boot protocol |
| **Cloud-Init** | Industry-standard tool for cloud instance initialization |
| **OpenCHAMI** | Open Composable Heterogeneous Adaptable Management Infrastructure |
| **Configless Mode** | Slurm feature where compute nodes fetch configuration from controller |
| **GRES** | Generic Resources - Slurm mechanism for managing GPUs and other resources |
| **CUDA** | NVIDIA's parallel computing platform |
| **DOCA-OFED** | NVIDIA's data center acceleration drivers |

---

## 2. Introduction

This document describes the High-Level Design for provisioning Slurm clusters in Omnia using NFS-based configuration distribution and PXE boot with cloud-init. The design enables stateless compute nodes that boot via PXE, mount their configuration from NFS, and register with the Slurm controller automatically.

### 2.1 Scope

**In Scope:**
- Slurm cluster provisioning via PXE boot
- NFS-based configuration distribution
- Cloud-init based node initialization
- Munge authentication setup
- Slurm configless mode operation
- Controller and compute node boot sequences
- Support for x86_64 and aarch64 architectures

**Out of Scope:**
- Slurm job submission and execution details
- User management and authentication (LDAP/AD)
- Network fabric configuration (InfiniBand, RoCE)
- Storage provisioning beyond NFS shares
- Monitoring and alerting infrastructure

### 2.2 References

| Document | Description |
|----------|-------------|
| Slurm Documentation | https://slurm.schedmd.com/documentation.html |
| Slurm Configless Mode | https://slurm.schedmd.com/configless_slurm.html |
| Cloud-Init Documentation | https://cloudinit.readthedocs.io/ |
| OpenCHAMI Documentation | https://openchami.org/ |
| Omnia Documentation | https://github.com/dell/omnia |

### 2.3 Input Configuration

The Slurm cluster configuration is defined in `input/omnia_config.yml`. Below are the relevant input parameters:

#### 2.3.1 Slurm Cluster Configuration (`slurm_cluster`)

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `cluster_name` | String | Yes | Name of the Slurm cluster |
| `nfs_storage_name` | String | Yes | Storage name corresponding to the NFS share (must match entry in `storage_config.yml`) |
| `config_sources` | Map/Path | No | Custom Slurm configuration values |

**Example Configuration:**

```yaml
slurm_cluster:
  - cluster_name: slurm_cluster
    nfs_storage_name: nfs_slurm
    config_sources:
      slurm:
        SlurmctldTimeout: 60
        SlurmdTimeout: 150
      cgroup: /custom_conf/cgroup.conf
```

#### 2.3.2 Supported Configuration Files (`config_sources`)

The `config_sources` parameter allows customization of Slurm configuration files. It can also take custom slurm configuration files from any local path. The following configuration files are supported:

| Config File | Description | Output File |
|-------------|-------------|-------------|
| `slurm` | Main Slurm configuration | `slurm.conf` |
| `cgroup` | Cgroup configuration for resource isolation | `cgroup.conf` |
| `gres` | Generic resources (GPU) configuration | `gres.conf` |
| `mpi` | MPI configuration | `mpi.conf` |


#### 2.3.3 Configuration File Location

- **Input File:** `input/omnia_config.yml`
- **Schema Validation:** `common/library/module_utils/input_validation/schema/omnia_config.json`

#### 2.3.4 Related Input Files

| File | Purpose |
|------|---------|
| `input/omnia_config.yml` | Main Slurm and K8s cluster configuration |
| `input/storage_config.yml` | NFS storage definitions (referenced by `nfs_storage_name`) |
| `input/software_config.json` | Software packages to install |

---

## 3. Solution Architecture

### 3.1 Architecture Constraints and Assumptions

**Constraints:**

| ID | Constraint | Impact |
|----|------------|--------|
| C1 | Single Slurm controller | No high availability for slurmctld |
| C2 | Static node definitions in slurm.conf | New nodes require discovery re-run |
| C3 | Per-node NFS directories | NFS directories must be pre-created |
| C4 | Architecture-specific templates | Separate cloud-init for x86_64/aarch64 |
| C5 | NFS server availability | All nodes depend on NFS for boot |

**Assumptions:**

| ID | Assumption |
|----|------------|
| A1 | NFS server is available and accessible from all nodes |
| A2 | DHCP/TFTP/PXE infrastructure is operational |
| A3 | OpenCHAMI service is running and configured |
| A4 | Network connectivity exists between OIM, NFS, and all nodes |
| A5 | Base OS image contains required Slurm packages |
| A6 | Firewall rules allow required ports between components |

### 3.2 Architecture Control Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              OIM (Omnia Infrastructure Manager)             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  Ansible    │  │   OpenCHAMI │  │  NFS Server │  │  PXE/DHCP/TFTP      │ │
│  │  Playbooks  │  │   (Ochami)  │  │             │  │                     │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
└─────────┼────────────────┼────────────────┼────────────────────┼────────────┘
          │                │                │                    │
          ▼                ▼                ▼                    ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │                         Admin Network                                   │
    └─────────────────────────────────────────────────────────────────────────┘
          │                │                │                    │
          ▼                ▼                ▼                    ▼
    ┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────────────┐
    │  Slurm    │    │  Slurm    │    │  Slurm    │    │  Login/Compiler   │
    │ Controller│    │  Node 1   │    │  Node N   │    │      Nodes        │
    └───────────┘    └───────────┘    └───────────┘    └───────────────────┘
```

**Component Descriptions:**

| Component | Role | Key Files |
|-----------|------|-----------|
| **Ansible Playbooks** | Orchestrates discovery, config generation, NFS setup | `discovery/discovery.yml` |
| **slurm_config role** | Creates NFS directories, generates Slurm configs | `discovery/roles/slurm_config/` |
| **configure_ochami role** | Generates cloud-init templates for PXE boot | `discovery/roles/configure_ochami/` |
| **nfs_client role** | Configures NFS mounts on nodes | `discovery/roles/nfs_client/` |
| **NFS Server** | Hosts shared Slurm configuration and state | User-provided or OIM-managed |
| **OpenCHAMI** | Manages node inventory, cloud-init delivery | External service |

### 3.3 Architecture Data Flow Diagram

**Phase 1: Discovery (Pre-Boot)**

```
  ┌─────────────┐
  │ pxe_map.csv |
  └──────┬──────┘
         │
         ▼
  ┌─────────────┐
  │ nodes.yaml  │  ← Node inventory (hostname, IP, group, BMC)
  └──────┬──────┘
         │
         ▼
  ┌─────────────────────────────────────────┐
  │  read_slurm_hostnames.yml               │
  │  - Parse nodes.yaml                     │
  │  - Group by functional_group:           │
  │    • slurm_control_node_*  → ctld_list  │
  │    • slurm_node_*          → cmpt_list  │
  │    • login_node_*          → login_list │
  └──────┬──────────────────────────────────┘
         │
         ▼
  ┌─────────────────────────────────────────┐
  │  create_slurm_dir.yml                   │
  │  - Create NFS directory structure       │
  │  - Generate munge key                   │
  │  - Create slurm.conf, slurmdbd.conf     │
  │  - Copy CUDA, DOCA-OFED packages        │
  └──────┬──────────────────────────────────┘
         │
         ▼
  ┌─────────────────────────────────────────┐
  │  configure_ochami (create_groups.yml)   │
  │  - Generate cloud-init per group        │
  │  - Register with OpenCHAMI              │
  └─────────────────────────────────────────┘
```

**Phase 2: PXE Boot**

```
  ┌─────────────┐
  │  Node BIOS  │
  │  PXE Boot   │
  └──────┬──────┘
         │ DHCP Request
         ▼
  ┌─────────────────────┐
  │  DHCP/TFTP Server   │
  │  - Assign IP        │
  │  - Provide bootloader│
  └──────┬──────────────┘
         │
         ▼
  ┌─────────────────────┐
  │  OpenCHAMI          │
  │  - Serve cloud-init │
  │    based on MAC/IP  │
  └──────┬──────────────┘
         │
         ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  Cloud-Init Execution (on booting node)                         │
  │                                                                 │
  │  1. write_files:                                                │
  │     - /usr/local/bin/configure_dirs_and_mounts.sh               │
  │     - /usr/local/bin/configure_slurmd_setup.sh                  │
  │     - /usr/local/bin/configure_munge_and_pam.sh                 │
  │     - /usr/local/bin/configure_firewall_and_services.sh         │
  │     - /usr/local/bin/check_slurm_controller_status.sh           │
  │                                                                 │
  │  2. runcmd:                                                     │
  │     a. Create directories: /var/log/slurm, /etc/munge, etc.     │
  │     b. Add NFS entries to /etc/fstab                            │
  │     c. mount -a (mount all NFS shares)                          │
  │     d. Wait for controller (check_slurm_controller_status.sh)   │
  │     e. Configure permissions (chown slurm:slurm)                │
  │     f. Start services: munge → slurmd                           │
  └─────────────────────────────────────────────────────────────────┘
```

**Phase 3: Full Cluster Boot Sequence**

```
    OIM              NFS Server       Controller        Compute Node
     │                   │                │                  │
     │  1. discovery.yml │                │                  │
     ├──────────────────►│                │                  │
     │  Create dirs      │                │                  │
     │  Generate configs │                │                  │
     │                   │                │                  │
     │  2. PXE boot      │                │                  │
     │───────────────────┼────────────────┼─────────────────►│
     │                   │                │                  │
     │                   │  3. Mount NFS  │                  │
     │                   │◄───────────────┤                  │
     │                   │                │                  │
     │                   │  4. Start services                │
     │                   │                ├─────────────────►│
     │                   │                │  munge, mariadb  │
     │                   │                │  slurmdbd        │
     │                   │                │  slurmctld       │
     │                   │                │                  │
     │                   │  5. Create marker                 │
     │                   │◄───────────────┤                  │
     │                   │  slurm_controller_track           │
     │                   │                │                  │
     │                   │                │  6. Mount NFS    │
     │                   │◄───────────────┼──────────────────┤
     │                   │                │                  │
     │                   │                │  7. Wait for marker
     │                   ├────────────────┼─────────────────►│
     │                   │                │                  │
     │                   │                │  8. Start slurmd │
     │                   │                │◄─────────────────┤
     │                   │                │  --conf-server   │
     │                   │                │                  │
     │                   │                │  9. Node ready   │
     │                   │                │◄─────────────────┤
```

### 3.4 Actor / Action Matrix

| Actor | Action | Target | Description |
|-------|--------|--------|-------------|
| **Administrator** | Run discovery.yml | OIM | Initiates cluster provisioning |
| **Ansible** | Create NFS directories | NFS Server | Sets up per-node directory structure |
| **Ansible** | Generate slurm.conf | NFS Server | Creates Slurm configuration files |
| **Ansible** | Generate cloud-init | OpenCHAMI | Creates boot templates per node group |
| **Ansible** | Generate munge key | NFS Server | Creates shared authentication key |
| **OpenCHAMI** | Serve cloud-init | Booting Node | Delivers node-specific configuration |
| **DHCP Server** | Assign IP | Booting Node | Provides network configuration |
| **TFTP Server** | Serve bootloader | Booting Node | Delivers PXE boot files |
| **Controller** | Start slurmctld | Self | Initializes job scheduler |
| **Controller** | Create marker file | NFS Server | Signals readiness to compute nodes |
| **Compute Node** | Mount NFS | NFS Server | Accesses configuration and state |
| **Compute Node** | Wait for marker | NFS Server | Ensures controller is ready |
| **Compute Node** | Start slurmd | Self | Registers with controller |
| **slurmd** | Fetch config | slurmctld | Retrieves slurm.conf in configless mode |

### 3.5 Architecture Threat Model

| Threat ID | Threat | Risk Level | Mitigation |
|-----------|--------|------------|------------|
| T1 | Munge key exposure on NFS | High | Restrict NFS access to cluster nodes only; set key permissions to 400 |
| T2 | Unauthorized node registration | Medium | Munge authentication required; network segmentation |
| T3 | NFS server compromise | Critical | Secure NFS server; use NFSv4 with Kerberos if possible |
| T4 | Cloud-init injection | High | Secure OpenCHAMI; validate MAC/IP mappings |
| T5 | Man-in-the-middle on admin network | Medium | Use dedicated admin VLAN; consider TLS for Slurm |
| T6 | Denial of service on NFS | High | NFS server redundancy; monitor availability |
| T7 | Privilege escalation via slurm user | Medium | Minimal slurm user privileges; PAM restrictions |

**Network Ports Required:**

| Service | Port | Direction | Purpose |
|---------|------|-----------|---------|
| slurmctld | 6817/tcp | Controller ← Nodes | Configless config fetch, job control |
| slurmd | 6818/tcp | Nodes ← Controller | Job launch |
| slurmdbd | 6819/tcp | Controller ← DBD | Accounting |
| srun | 60001-63000/tcp | Nodes ↔ Nodes | Interactive jobs |
| MariaDB | 3306/tcp | Controller local | Accounting DB |
| NFS | 2049/tcp | All → NFS Server | Config/state storage |

---

## 4. High Level Design of Architectural Components

### 4.1 Design Component – NFS Directory Structure

**Purpose:** Centralized storage for Slurm configuration, state, and logs accessible by all cluster nodes.

**Directory Layout:**

```
{{ nfs_share_path }}/slurm/
├── munge.key                          # Shared munge key (master copy)
├── ctld_track/
│   └── slurm_controller_track         # Controller ready marker file
│
├── <controller_hostname>/             # Per-controller directories
│   ├── etc/
│   │   ├── slurm/
│   │   │   ├── slurm.conf
│   │   │   ├── slurmdbd.conf
│   │   │   ├── cgroup.conf
│   │   │   └── gres.conf
│   │   ├── munge/munge.key
│   │   └── my.cnf.d/mariadb-server.cnf
│   ├── var/
│   │   ├── lib/mysql/
│   │   ├── log/slurm/
│   │   ├── log/mariadb/
│   │   └── spool/
│
├── <compute_hostname>/                # Per-compute directories
│   ├── etc/
│   │   ├── munge/munge.key
│   │   └── slurm/epilog.d/
│   │       ├── logout_user.sh
│   │       └── slurmd.service
│   └── var/
│       ├── log/slurm/
│       ├── spool/
│       └── lib/slurm/
│
└── <login_hostname>/                  # Per-login directories
    ├── etc/
    │   ├── munge/munge.key
    └── var/
        └── log/slurm/
```

**Key Design Decisions:**

| Decision | Rationale |
|----------|-----------|
| Per-node NFS directories | Isolates node state, simplifies debugging |
| Munge key on NFS | Centralized key distribution, no manual copy |
| Controller marker file | Ensures compute nodes wait for controller readiness |

**Source Files:**
- `discovery/roles/slurm_config/tasks/create_slurm_dir.yml`
- `discovery/roles/slurm_config/vars/main.yml`

### 4.2 Design Component – Slurm Controller Configuration

**Purpose:** Configure and start Slurm controller services (slurmctld, slurmdbd, MariaDB).

**Boot Sequence:**

```
  ┌─────────────────────────────────────────┐
  │  1. Mount NFS Directories               │
  │     /etc/slurm      ← slurm.conf        │
  │     /etc/munge      ← munge.key         │
  │     /var/lib/mysql  ← MariaDB data      │
  │     /var/log/slurm  ← logs              │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────┐
  │  2. 00_munge_setup.sh                   │
  │     - Set munge key permissions (400)   │
  │     - Start munge service               │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────┐
  │  3. 01_mariadb_setup.sh                 │
  │     - Set MySQL directory permissions   │
  │     - Start MariaDB                     │
  │     - Initialize slurm_acct_db          │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────┐
  │  4. 02_slurmdbd_setup.sh                │
  │     - Configure slurmdbd.conf perms     │
  │     - Open firewall port (6819)         │
  │     - Start slurmdbd                    │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────┐
  │  5. 03_slurmctld_setup.sh               │
  │     - Create StateSaveLocation          │
  │     - Open firewall ports (6817, 60001-)│
  │     - Start slurmctld                   │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────┐
  │  6. 04_track_file.sh                    │
  │     - Wait for slurmctld active         │
  │     - Create marker file:               │
  │       /var/log/track/slurm_controller_track │
  └─────────────────────────────────────────┘
```

**slurm.conf Generation:**

**Source:** `discovery/roles/slurm_config/templates/slurm.conf.j2`

```
ClusterName={{ cluster_name }}
SlurmctldHost={{ ctld_list[0] }}
SlurmctldParameters=enable_configless    ← Configless mode enabled

# Static node definitions (generated at discovery time)
NodeName={{ cmpt_list[0] }} RealMemory=... Sockets=... CoresPerSocket=...
NodeName={{ cmpt_list[1] }} ...

PartitionName={{ partition_name }} Nodes={{ cmpt_list | join(',') }}
```

**Source Files:**
- `discovery/roles/configure_ochami/templates/cloud_init/ci-group-slurm_control_node_x86_64.yaml.j2`
- `discovery/roles/slurm_config/templates/slurm.conf.j2`
- `discovery/roles/slurm_config/templates/slurmdbd.conf.j2`

### 4.3 Design Component – Compute Node Configuration

**Purpose:** Configure and start slurmd on compute nodes in configless mode.

**Boot Sequence:**

```
  ┌─────────────────────────────────────────┐
  │  1. configure_dirs_and_mounts.sh        │
  │     - Create: /var/log/slurm, /etc/munge│
  │     - Add to /etc/fstab:                │
  │       • {{ nfs }}/$(hostname)/var/log/slurm  │
  │       • {{ nfs }}/$(hostname)/var/spool      │
  │       • {{ nfs }}/$(hostname)/etc/munge      │
  │       • {{ nfs }}/$(hostname)/etc/slurm/epilog.d │
  │       • {{ nfs }}/ctld_track → /var/log/track │
  │     - mount -a                          │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────┐
  │  2. check_slurm_controller_status.sh    │
  │     - Ping controller IP                │
  │     - Check port 6817 open              │
  │     - Wait for marker file:             │
  │       /var/log/track/slurm_controller_track │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────┐
  │  3. configure_slurmd_setup.sh           │
  │     - Copy slurmd.service to systemd    │
  │     - Set directory ownership (slurm)   │
  │     - Set epilog permissions            │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────┐
  │  4. configure_munge_and_pam.sh          │
  │     - Set munge key perms (400)         │
  │     - Configure PAM for pam_slurm_adopt │
  └──────────────┬──────────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────────┐
  │  5. configure_firewall_and_services.sh  │
  │     - Open firewall: 6818, 60001-63000  │
  │     - systemctl enable/start:           │
  │       • munge                           │
  │       • slurmd (--conf-server mode)     │
  └─────────────────────────────────────────┘
```

**slurmd.service (Configless):**

**Source:** `discovery/roles/slurm_config/templates/slurmd.service.j2`

```ini
[Service]
ExecStart=/usr/sbin/slurmd --conf-server {{ ctld_list[0] }}:6817 -D
```

**Key Design Decisions:**

| Decision | Rationale |
|----------|-----------|
| Configless slurmd | Nodes fetch config from controller, reduces config drift |
| Controller wait script | Prevents slurmd start before controller is ready |
| Cloud-init for provisioning | Stateless PXE boot, no persistent node state |

**Source Files:**
- `discovery/roles/configure_ochami/templates/cloud_init/ci-group-slurm_node_x86_64.yaml.j2`
- `discovery/roles/configure_ochami/templates/slurm/check_slurm_controller_status.sh.j2`
- `discovery/roles/slurm_config/templates/slurmd.service.j2`

### 4.4 Design Component – Cloud-Init Templates

**Purpose:** Generate node-specific initialization scripts delivered via OpenCHAMI during PXE boot.

**Template Files:**

| Template | Target Node Type | Architecture |
|----------|------------------|--------------|
| `ci-group-slurm_control_node_x86_64.yaml.j2` | Slurm Controller | x86_64 |
| `ci-group-slurm_control_node_aarch64.yaml.j2` | Slurm Controller | aarch64 |
| `ci-group-slurm_node_x86_64.yaml.j2` | Compute Node | x86_64 |
| `ci-group-slurm_node_aarch64.yaml.j2` | Compute Node | aarch64 |
| `ci-group-login_node_x86_64.yaml.j2` | Login Node | x86_64 |

**Cloud-Init Sections:**

| Section | Purpose |
|---------|---------|
| `users` | Create slurm user with correct UID/GID |
| `write_files` | Deploy configuration scripts |
| `runcmd` | Execute scripts in sequence |

**Scripts Deployed via write_files:**

| Script | Purpose |
|--------|---------|
| `configure_dirs_and_mounts.sh` | Create directories, configure NFS mounts |
| `configure_slurmd_setup.sh` | Set up slurmd service |
| `configure_munge_and_pam.sh` | Configure munge authentication |
| `configure_firewall_and_services.sh` | Open ports, start services |
| `check_slurm_controller_status.sh` | Wait for controller readiness |

**Source Files:**
- `discovery/roles/configure_ochami/templates/cloud_init/`
- `discovery/roles/configure_ochami/tasks/create_groups.yml`

### 4.5 Design Component – slurm_conf_merge Module

**Purpose:** Custom Ansible module to merge Slurm configuration from multiple sources (inline map or external file) into a unified configuration file.

#### 4.5.1 Module Overview

The `slurm_conf_merge` module provides a flexible way to generate Slurm configuration files by merging:
- Default configuration values from the role
- User-provided configuration as key-value maps
- User-provided configuration from external files

**Module Location:** `discovery/roles/slurm_config/library/slurm_conf_merge.py`

#### 4.5.2 Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `dest` | String | Yes | Destination path for the merged configuration file |
| `defaults` | Map | No | Default configuration key-value pairs |
| `config_sources` | Map/String | No | User configuration as map or path to config file |
| `conf_type` | String | Yes | Configuration type (slurm, cgroup, gres, mpi, etc.) |

#### 4.5.3 Configuration Source Types

The module accepts configuration in two formats:

**Format 1: Inline Map**
```yaml
config_sources:
  slurm:
    SlurmctldTimeout: 60
    SlurmdTimeout: 150
    MaxJobCount: 10000
```

**Format 2: External File Path**
```yaml
config_sources:
  cgroup: /path/to/custom/cgroup.conf
```

#### 4.5.4 Merge Logic

```
  ┌───────────────────────┐     ┌───────────────────────┐
  │   Default Config      │     │   User Config         │
  │   (from role defaults)│     │   (map or file)       │
  └───────────┬───────────┘     └───────────┬───────────┘
              │                             │
              └──────────┬──────────────────┘
                         │
                         ▼
              ┌───────────────────────┐
              │  slurm_conf_merge     │
              │  - Parse defaults     │
              │  - Parse user config  │
              │  - Merge (user wins)  │
              │  - Validate keys      │
              └───────────┬───────────┘
                         │
                         ▼
              ┌───────────────────────┐
              │  Output: merged.conf  │
              │  (dest path)          │
              └───────────────────────┘
```

**Merge Rules:**
1. Start with default configuration values
2. If user provides a **map**: overlay user values (user values override defaults)
3. If user provides a **file path**: read file and merge contents (file values override defaults)
4. Validate configuration keys against allowed keys for the conf_type
5. Write merged configuration to destination

#### 4.5.5 Module Output

| Return Value | Type | Description |
|--------------|------|-------------|
| `changed` | Boolean | Whether the configuration file was modified |
| `dest` | String | Path to the output configuration file |
| `merged_keys` | List | Keys that were merged from user config |
| `msg` | String | Status message |

#### 4.5.6 Example Usage

```yaml
- name: Generate slurm.conf with merged configuration
  slurm_conf_merge:
    dest: "{{ slurm_config_path }}/slurm.conf"
    defaults: "{{ slurm_default_config }}"
    config_sources: "{{ slurm_cluster.config_sources.slurm | default({}) }}"
    conf_type: slurm

- name: Generate cgroup.conf from external file
  slurm_conf_merge:
    dest: "{{ slurm_config_path }}/cgroup.conf"
    defaults: "{{ cgroup_default_config }}"
    config_sources: "{{ slurm_cluster.config_sources.cgroup }}"
    conf_type: cgroup
```

#### 4.5.7 Validation

The module validates configuration keys against predefined lists:

| Config Type | Validation Source |
|-------------|-------------------|
| `slurm` | `slurm_conf_valid_keys` |
| `cgroup` | `cgroup_conf_valid_keys` |
| `gres` | `gres_conf_valid_keys` |
| `mpi` | `mpi_conf_valid_keys` |
| `slurmdbd` | `slurmdbd_conf_valid_keys` |

Invalid keys generate warnings but do not fail the merge (to support future Slurm versions).

**Source Files:**
- `discovery/roles/slurm_config/library/slurm_conf_merge.py`
- `discovery/roles/slurm_config/defaults/main.yml` (valid key lists)

### 4.6 Design Component – Node Addition and Removal

**Purpose:** Define the operational model for adding new nodes to or removing nodes from the Slurm cluster.

#### 4.6.1 Stateless Cluster Deployment Model

The Slurm cluster follows a **stateless deployment model** where there is no separate workflow for adding or deleting individual nodes. The entire cluster state is derived from the `pxe_mapping_file.csv` at deployment time.

**Key Principles:**

| Principle | Description |
|-----------|-------------|
| **Single Source of Truth** | The `pxe_mapping_file.csv` defines the complete cluster membership |
| **Declarative Configuration** | Cluster state is declared, not imperatively modified |
| **Idempotent Deployment** | Running discovery multiple times produces the same result |
| **Graceful Updates** | Changes to a running cluster are handled gracefully |

#### 4.6.2 Node Addition Flow

To add new nodes to the cluster:

1. **Update `pxe_mapping_file.csv`** - Add new node entries with hostname, MAC, IP, and functional group
2. **Re-run Discovery** - Execute `discovery.yml` playbook
3. discovery will check if clsuter is running or not, if running it will issue scontrol reconfigure to update the cluster
4. **Automatic Provisioning** - The following occurs automatically:
   - NFS directories created for new nodes
   - `slurm.conf` regenerated with new `NodeName` entries
   - Cloud-init templates updated and registered with OpenCHAMI
   - `scontrol reconfigure` issued to update running controller
5. **Node Boot** - New nodes PXE boot and join the cluster

```
  ┌───────────────────────┐
  │ Update pxe_mapping_   │
  │ file.csv with new     │
  │ node entries          │
  └───────────┬───────────┘
              │
              ▼
  ┌───────────────────────┐
  │ Run discovery.yml     │
  │ - Creates NFS dirs    │
  │ - Updates slurm.conf  │
  │ - Updates cloud-init  │
  └───────────┬───────────┘
              │
              ▼
  ┌───────────────────────┐
  │ scontrol reconfigure  │
  │ (if cluster running)  │
  └───────────┬───────────┘
              │
              ▼
  ┌───────────────────────┐
  │ New nodes PXE boot    │
  │ and join cluster      │
  └───────────────────────┘
```

#### 4.6.3 Node Removal Flow

To remove nodes from the cluster:

1. **Drain Node** (if cluster running) - `scontrol update NodeName=<node> State=DRAIN`
2. **Update `pxe_mapping_file.csv`** - Remove node entries
3. **Re-run Discovery** - Execute `discovery.yml` playbook
4. **Automatic Cleanup** - The following occurs:
   - `slurm.conf` regenerated without removed nodes
   - Cloud-init templates updated
   - `scontrol reconfigure` issued to update running controller

> **Note:** NFS directories for removed nodes are **not automatically deleted** to preserve logs and state for debugging purposes.

#### 4.6.4 Graceful Handling of Running Clusters

When the cluster is already running and discovery is re-executed:

| Scenario | Behavior |
|----------|----------|
| **New nodes added** | NFS dirs created, slurm.conf updated, `scontrol reconfigure` issued |
| **Nodes removed** | slurm.conf updated, `scontrol reconfigure` issued, NFS dirs preserved |
| **No changes** | Idempotent - no disruptive actions taken |
| **Configuration changes** | slurm.conf regenerated, `scontrol reconfigure` issued |

**Graceful Update Sequence:**

1. Discovery detects running slurmctld
2. Configuration files updated on NFS
3. `scontrol reconfigure` issued to reload configuration
4. Running jobs continue uninterrupted
5. New configuration takes effect for new jobs

#### 4.6.5 Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| No dynamic node registration | Requires discovery re-run | Future: Implement Slurm `-Z` flag |
| NFS directories not auto-cleaned | Disk space accumulation | Manual cleanup or scheduled job |
| Running jobs on removed nodes | Jobs may fail | Drain nodes before removal |

---

## 5. Unresolved Issues

| ID | Issue | Impact | Proposed Resolution | Status |
|----|-------|--------|---------------------|--------|
| U1 | Static node definitions require discovery re-run for new nodes | Operational overhead when scaling cluster | Implement Slurm dynamic node registration using `-Z` flag | Open |
| U2 | Per-node NFS directories create management overhead | Scaling complexity | Consolidate to shared directories with symlinks | Open |
| U3 | No high availability for slurmctld | Single point of failure | Implement slurmctld HA with backup controller | Open |
| U4 | Separate cloud-init templates per architecture | Maintenance burden | Create single parameterized template | Open |
| U5 | Munge key stored on NFS in plaintext | Security concern | Evaluate encrypted storage or key distribution alternatives | Open |
| U6 | No automated node decommissioning | Stale entries in slurm.conf | Implement node lifecycle management | Open |
| U7 | Controller marker file polling | Potential boot delays | Consider event-driven notification mechanism | Open |

---

## Appendix A: File References

| Component | Path |
|-----------|------|
| Main playbook | `discovery/discovery.yml` |
| Slurm config role | `discovery/roles/slurm_config/` |
| NFS directory creation | `discovery/roles/slurm_config/tasks/create_slurm_dir.yml` |
| Hostname parsing | `discovery/roles/slurm_config/tasks/read_slurm_hostnames.yml` |
| slurm.conf template | `discovery/roles/slurm_config/templates/slurm.conf.j2` |
| Cloud-init (compute x86) | `discovery/roles/configure_ochami/templates/cloud_init/ci-group-slurm_node_x86_64.yaml.j2` |
| Cloud-init (controller) | `discovery/roles/configure_ochami/templates/cloud_init/ci-group-slurm_control_node_x86_64.yaml.j2` |
| Controller wait script | `discovery/roles/configure_ochami/templates/slurm/check_slurm_controller_status.sh.j2` |
| Default config values | `discovery/roles/slurm_config/defaults/main.yml` |
