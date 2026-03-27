# Storage Configuration Design

**Version:** 1.1  
**Date:** 2026-03-27  
**Status:** Design Active

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Configuration Schema](#configuration-schema)
4. [Mount Params (Profiles)](#mount-params-profiles)
5. [Storage Technologies](#storage-technologies)
6. [Usage Examples](#usage-examples)
7. [Priority Resolution](#priority-resolution)
8. [Best Practices](#best-practices)
9. [Validation Rules](#validation-rules)
10. [Design Decision: storage_config.yml vs storage_profile.yml](#design-decision-storage_configyml-vs-storage_profileyml)

---

## Overview

This design provides a flexible, profile-based mount configuration system for Dell storage solutions in HPC environments. It supports:

- **VAST NFS Storage** - High-performance NFS storage for shared filesystems
- **PowerVault iSCSI Storage** - Block storage for persistent data and databases
- **Generic Network Storage** - NFS, CIFS, and other network filesystems
- **Local Storage** - Direct-attached storage and local disks

### Key Features

- ✅ **Profile-based configuration** - Reusable templates for common mount patterns (`mount_params`)
- ✅ **Priority-based resolution** - Explicit values override profile defaults
- ✅ **Vendor-specific optimizations** - VAST and PowerVault tuned profiles
- ✅ **Functional-group targeting** - Mount configurations applied per node functional group prefix
- ✅ **Multi-volume PowerVault** - List-based `powervault_config` supports multiple iSCSI volumes
- ✅ **Dual PowerVault mount modes** - Reference an existing `mounts[]` entry or define inline
- ✅ **Validation enforcement** - Schema validation ensures correct configuration

---

## Architecture

### Configuration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     storage_config.yml                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  mount_params (Profiles)                               │   │
│  │  ├─ vast_nfs                                           │   │
│  │  ├─ vast_nfs_performance                               │   │
│  │  ├─ powervault_iscsi                                   │   │
│  │  ├─ network_storage                                    │   │
│  │  ├─ bind_mounts                                        │   │
│  │  ├─ local_storage                                      │   │
│  │  ├─ scratch_storage                                    │   │
│  │  └─ global                                             │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ▼                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  mounts (Mount Entries)                                │   │
│  │  ├─ vast_home (uses vast_nfs profile)                 │   │
│  │  ├─ powervault_slurm_persist (uses powervault_iscsi)  │   │
│  │  └─ powervault_mysql_bind (uses bind_mounts)          │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ▼                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  powervault_config (Optional, list)                    │   │
│  │  ├─ name: powervault1                                  │   │
│  │  │   ├─ ip / port / iscsi_initiator / volume_id       │   │
│  │  │   └─ mount: <mounts[] entry name>   (Mode A)       │   │
│  │  └─ name: powervault2                                  │   │
│  │      ├─ ip / port / iscsi_initiator / volume_id       │   │
│  │      └─ source / mount_point / mount_params / ...     │   │
│  │                                          (Mode B)      │   │
│  └────────────────────────────────────────────────────────┘   │
│                           ▼                                     │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  swap (Optional, list)                                 │   │
│  │  └─ name / filename / size / maxsize /                 │   │
│  │     functional_group_prefix                            │   │
│  └────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                           ▼
        ┌──────────────────────────────────────┐
        │   Schema Validation                  │
        │   (storage_config.json)              │
        └──────────────────────────────────────┘
                           ▼
        ┌──────────────────────────────────────┐
        │   Cloud-Init Generation              │
        │   (Jinja2 Templates)                 │
        └──────────────────────────────────────┘
                           ▼
        ┌──────────────────────────────────────┐
        │   Node Provisioning                  │
        │   (Per Functional Group)             │
        └──────────────────────────────────────┘
```

---

## Configuration Schema

### File Structure

```yaml
# storage_config.yml

# PowerVault iSCSI configuration (optional, list)
powervault_config:
  - name: "powervault1"
    ip:
      - 172.1.2.3
    port: 3260
    iscsi_initiator: "iqn.2025-01.com.dell:hostname"
    volume_id: "00c0ff4343f1f1f1001c8c4e6901000000"
    # Mode A: reference an existing mounts[] entry by name
    mount: "powervault_slurm_persist"

  - name: "powervault2"
    ip:
      - 172.1.2.4
    port: 3260
    iscsi_initiator: "iqn.2025-01.com.dell:slurmd-node"
    volume_id: "00c0ff4343f1f1f1001c8c4e6901000001"
    # Mode B: define all mount parameters inline
    source: "/dev/mapper/360002ac0000000000000000000000000"
    mount_point: "/scratch"
    mount_params: "powervault_iscsi"
    fs_type: "xfs"
    mnt_opts: "defaults,nofail"
    functional_group_prefix: ["k8s_node"]

# Mount parameter profiles (templates)
mount_params:
  profile_name:
    fs_type: "filesystem_type"
    mnt_opts: "mount_options"
    dump_freq: "0"
    fsck_pass: "0"
    # Optional custom fields (e.g., vast_nfs_ip, perf_ip) — used in mount templates

# Mount entries
mounts:
  - name: "unique_mount_name"          # alphanumeric, underscore, hyphen only
    source: "device_or_network_path"
    mount_point: "/mount/path"
    mount_params: "profile_name"       # Optional — references mount_params profile
    fs_type: "filesystem_type"         # Optional — overrides profile
    mnt_opts: "mount_options"          # Optional — overrides profile
    dump_freq: "0"                     # Optional — overrides profile
    fsck_pass: "0"                     # Optional — overrides profile
    functional_group_prefix: ["prefix1", "prefix2"]  # Required
    # All nodes whose functional group name starts with any listed prefix get this mount.
    # e.g., ["slurm"] matches slurm_control_node, slurm_node, slurm_login, etc.
    # Omit functional_group_prefix to apply the mount to ALL nodes (use with care).

# Swap configuration (optional)
swap:
  - name: "swap_name"
    filename: "/swapfile"
    size: "4G"
    maxsize: "8G"                      # Optional — used when size is "auto"
    functional_group_prefix: ["prefix1"]
```

---

## Mount Params (Profiles)

`mount_params` are reusable templates that define the **how to mount** (technical settings). Mount entries define the **what, where, and who** (source, path, targeting).

### Profile Structure

```yaml
mount_params:
  profile_name:
    fs_type: "filesystem_type"     # Required
    mnt_opts: "mount_options"      # Required
    dump_freq: "0"                 # Required
    fsck_pass: "0"                 # Required
    # Additional custom fields are allowed and are passed through to mount templates.
    # Standard fstab fields (fs_type, mnt_opts, dump_freq, fsck_pass) are used directly
    # by the cloud-init mounts module. Custom fields are available to Jinja2 templates.
```

### Standard Profiles

#### 1. `default` — Standard NFS Defaults

```yaml
default:
  fs_type: "nfs"
  mnt_opts: "defaults,nofail,_netdev,x-systemd.after=cloud-init-network.service"
  dump_freq: "0"
  fsck_pass: "0"
```

**Use Case:** Generic NFS mounts with standard options.

---

#### 2. `vast_nfs` — VAST NFS Standard Configuration

```yaml
vast_nfs:
  fs_type: "nfs4"
  mnt_opts: "defaults,nofail,_netdev,noatime,x-systemd.after=cloud-init-network.service"
  dump_freq: "0"
  fsck_pass: "0"
  vast_nfs_ip: "192.168.1.100"   # Custom field — used in mount source templates
```

**Use Case:** VAST Data NFS exports with standard performance.  
**Features:**
- NFSv4 protocol
- `noatime` for improved performance
- Network dependency handling
- `vast_nfs_ip` available as a template variable for resolving mount source

---

#### 3. `vast_nfs_performance` — VAST NFS High-Performance

```yaml
vast_nfs_performance:
  fs_type: "nfs4"
  mnt_opts: "defaults,nofail,_netdev,noatime,nodiratime,rsize=1048576,wsize=1048576"
  dump_freq: "0"
  fsck_pass: "0"
  perf_ip: "192.168.1.101"       # Custom field — used in mount source templates
```

**Use Case:** VAST Data NFS for high-throughput workloads (scratch, datasets).  
**Features:**
- NFSv4 protocol
- **1MB read/write buffers** (`rsize=1048576,wsize=1048576`)
- `noatime` and `nodiratime` for maximum performance
- Optimized for large sequential I/O

---

#### 4. `powervault_iscsi` — PowerVault iSCSI Block Storage

```yaml
powervault_iscsi:
  fs_type: "xfs"
  mnt_opts: "defaults,_netdev,noatime,x-systemd.requires=iscsi.service"
  dump_freq: "0"
  fsck_pass: "0"
```

**Use Case:** PowerVault iSCSI persistent storage.  
**Features:**
- XFS filesystem (high performance, scalability)
- Requires iSCSI service to be running
- `noatime` for improved performance
- Network device handling

**Note:** Matches `setup_iscsi_storage.sh` default configuration.

---

#### 5. `network_storage` — Generic Network Storage

```yaml
network_storage:
  fs_type: "auto"
  mnt_opts: "defaults,nofail,_netdev,x-systemd.after=cloud-init-network.service"
  dump_freq: "0"
  fsck_pass: "0"
```

**Use Case:** Generic network filesystems (NFS, CIFS, etc.).

---

#### 6. `local_storage` — Local Disk Storage

```yaml
local_storage:
  fs_type: "auto"
  mnt_opts: "defaults,nofail,noatime"
  dump_freq: "0"
  fsck_pass: "2"
```

**Use Case:** Local disks (ext4, xfs, etc.).  
**Note:** `fsck_pass: "2"` enables filesystem check on boot.

---

#### 7. `bind_mounts` — Bind Mounts

```yaml
bind_mounts:
  fs_type: "none"
  mnt_opts: "bind"
  dump_freq: "0"
  fsck_pass: "0"
```

**Use Case:** Bind mounts (e.g., `/mnt/slurm-persist/mysql` → `/var/lib/mysql`).

---

#### 8. `scratch_storage` — High-Performance Scratch

```yaml
scratch_storage:
  fs_type: "xfs"
  mnt_opts: "defaults,nofail,noatime,nodiratime,largeio,inode64"
  dump_freq: "0"
  fsck_pass: "2"
```

**Use Case:** Local high-performance scratch storage.

---

#### 9. `global` — Global Fallback

```yaml
global:
  fs_type: "auto"
  mnt_opts: "defaults,nofail,x-systemd.after=cloud-init-network.service"
  dump_freq: "0"
  fsck_pass: "2"
```

**Use Case:** Fallback when no specific profile matches and no explicit options are provided.

---

## Storage Technologies

### VAST NFS Storage

**Overview:** VAST Data provides high-performance, scale-out NFS storage optimized for HPC workloads.

#### Configuration Format

```yaml
mounts:
  - name: "vast_home"
    source: "192.168.1.100:/home"  # VAST NFS export
    mount_point: "/home"
    mount_params: "vast_nfs"
    functional_group_prefix: ["slurm"]
```

#### Source Format

- **Pattern:** `<VAST_IP>:<export_path>`
- **Example:** `192.168.1.100:/home`
- **Template variable:** `{{ vast_nfs_ip }}:/home` (using `vast_nfs_ip` from `mount_params`)

#### Recommended Profiles

| Use Case | Profile | Reason |
|----------|---------|--------|
| Home directories | `vast_nfs` | Standard performance, shared access |
| Shared applications | `vast_nfs` | Standard performance, read-heavy |
| Datasets (read-only) | `vast_nfs` | Standard performance |
| Scratch space | `vast_nfs_performance` | High throughput, large I/O |
| Checkpoints | `vast_nfs_performance` | High throughput, write-heavy |

#### Performance Tuning

**Standard Configuration (`vast_nfs`):**
- Default NFS buffer sizes
- Suitable for most workloads
- Lower memory overhead

**High-Performance Configuration (`vast_nfs_performance`):**
- 1MB read/write buffers
- Optimized for large sequential I/O
- Higher memory usage
- Best for scratch, checkpoints, large datasets

---

### PowerVault iSCSI Storage

**Overview:** Dell PowerVault provides block-level iSCSI storage for persistent data and databases.

`powervault_config` is a **list**, allowing multiple volumes to be configured independently. Each volume entry supports two mount modes.

#### Mode A: Reference an Existing `mounts[]` Entry

Use `mount: <name>` to link the PowerVault volume to a fully-defined entry in the `mounts[]` list. The iSCSI setup provisions the device; the mount entry handles fstab/cloud-init configuration.

```yaml
powervault_config:
  - name: "powervault1"
    ip:
      - 172.1.2.3
    port: 3260
    iscsi_initiator: "iqn.2025-01.com.dell:scontrol-node"
    volume_id: "00c0ff4343f1f1f1001c8c4e6901000000"
    mount: "powervault_slurm_persist"    # references mounts[] entry by name

mounts:
  - name: "powervault_slurm_persist"
    source: "UUID=<uuid-from-blkid>"
    mount_point: "/mnt/slurm-persist"
    mount_params: "powervault_iscsi"
    functional_group_prefix: ["slurm_control_node"]
```

#### Mode B: Inline Mount Definition

Define all mount parameters directly on the `powervault_config` entry. Use this when the volume does not need a separate `mounts[]` entry.

```yaml
powervault_config:
  - name: "powervault2"
    ip:
      - 172.1.2.4
    port: 3260
    iscsi_initiator: "iqn.2025-01.com.dell:slurmd-node"
    volume_id: "00c0ff4343f1f1f1001c8c4e6901000001"
    source: "/dev/mapper/360002ac0000000000000000000000000"
    mount_point: "/scratch"
    mount_params: "powervault_iscsi"
    fs_type: "xfs"
    mnt_opts: "defaults,nofail"
    functional_group_prefix: ["k8s_node"]
```

#### Source Format

- **Pattern:** `UUID=<uuid>` or `/dev/mapper/<multipath_device>`
- **Example:** `UUID=12345678-1234-1234-1234-123456789abc`
- **Note:** UUID is preferred over device paths for persistence across reboots.

#### Setup Script Integration

The `setup_iscsi_storage.sh` script automatically:

1. Discovers iSCSI targets from controller IPs
2. Logs in to all discovered targets
3. Configures multipath for redundancy
4. Selects the correct volume using `volume_id`
5. Creates GPT partition table
6. Formats partition with XFS
7. Mounts to `/mnt/slurm-persist` using UUID
8. Creates subdirectories: `mysql/`, `spool/`
9. Sets up bind mounts in `/etc/fstab`

#### Recommended Workflow

```
PowerVault Setup (setup_iscsi_storage.sh)
     ↓
/mnt/slurm-persist (XFS on /dev/mapper/mpatha1)
     ↓
     ├─ mysql/  → bind mount to /var/lib/mysql
     └─ spool/  → bind mount to /var/spool
```

#### Bind Mount Ordering

Bind mounts that depend on a parent PowerVault mount **must appear after** the parent in the `mounts[]` list. The list is processed in order — if the parent is not yet mounted, the bind mount will fail.

```yaml
mounts:
  # 1. Parent mount first
  - name: "powervault_slurm_persist"
    source: "UUID=<uuid-from-blkid>"
    mount_point: "/mnt/slurm-persist"
    mount_params: "powervault_iscsi"
    functional_group_prefix: ["slurm_control_node"]

  # 2. Bind mounts after parent
  - name: "powervault_mysql_bind"
    source: "/mnt/slurm-persist/mysql"
    mount_point: "/var/lib/mysql"
    mount_params: "bind_mounts"
    functional_group_prefix: ["slurm_control_node"]
```

---

## Usage Examples

### Example 0: Atomic Mount (All Fields Explicit, No Profile)

```yaml
mounts:
  - name: "atomic_nfs_data"
    source: "UUID=<uuid-from-blkid>"
    mount_point: "/mnt/atomic"
    fs_type: "nfs"
    mnt_opts: "defaults,nofail,_netdev,x-systemd.after=cloud-init-network.service"
    dump_freq: "0"
    fsck_pass: "0"
    functional_group_prefix: ["slurm_node"]
```

**Result:** All fields explicit; no profile lookup. Mount applies to all nodes whose functional group starts with `slurm_node`.

---

### Example 1: PowerVault iSCSI — Mode A (Profile Reference via `mounts[]`)

```yaml
powervault_config:
  - name: "powervault1"
    ip:
      - 172.1.2.3
    port: 3260
    iscsi_initiator: "iqn.2025-01.com.dell:scontrol-node"
    volume_id: "00c0ff4343f1f1f1001c8c4e6901000000"
    mount: "powervault_slurm_persist"

mounts:
  - name: "powervault_slurm_persist"
    source: "UUID=<uuid-from-blkid>"
    mount_point: "/mnt/slurm-persist"
    mount_params: "powervault_iscsi"
    functional_group_prefix: ["slurm_control_node_x86_64"]
```

**Result:**
- Filesystem: XFS
- Mount options: `defaults,_netdev,noatime,x-systemd.requires=iscsi.service`
- Applied to: Slurm control nodes on x86_64 architecture only

---

### Example 2: PowerVault Bind Mount — MySQL Data Directory

```yaml
mounts:
  - name: "powervault_mysql_bind"
    source: "192.1.2.3:/mnt/mysql"
    mount_point: "/var/lib/mysql"
    mount_params: "bind_mounts"
    functional_group_prefix: ["slurm_control_node"]
```

**Result:**
- Filesystem: none (bind)
- Mount options: `bind`
- Applied to: All Slurm control nodes (all architectures)

---

### Example 3: VAST NFS — Home Directories

```yaml
mounts:
  - name: "vast_home"
    source: "{{ vast_nfs_ip }}:/home"   # vast_nfs_ip resolved from vast_nfs profile
    mount_point: "/home"
    mount_params: "vast_nfs"
    functional_group_prefix: ["slurm"]
```

**Result:**
- Filesystem: NFSv4
- Mount options: `defaults,nofail,_netdev,noatime,x-systemd.after=cloud-init-network.service`
- Applied to: All nodes whose functional group starts with `slurm` (control, compute, login, etc.)

---

### Example 4: VAST NFS — High-Performance Scratch

```yaml
mounts:
  - name: "vast_scratch"
    source: "192.168.1.100:/scratch"
    mount_point: "/scratch"
    mount_params: "vast_nfs_performance"
    functional_group_prefix: ["k8s_node"]
```

**Result:**
- Filesystem: NFSv4
- Mount options: `defaults,nofail,_netdev,noatime,nodiratime,rsize=1048576,wsize=1048576`
- Applied to: All nodes whose functional group starts with `k8s_node`
- Performance: 1MB read/write buffers

---

### Example 5: Explicit Override of Profile Fields

```yaml
mounts:
  - name: "vast_apps_readonly"
    source: "192.168.1.100:/apps"
    mount_point: "/opt/apps"
    fs_type: "nfs4"                             # EXPLICIT — overrides profile
    mnt_opts: "defaults,nofail,_netdev,ro"      # EXPLICIT — overrides profile
    mount_params: "network_storage"
    # dump_freq and fsck_pass still come from network_storage profile
    functional_group_prefix: ["slurm"]
```

**Result:**
- Filesystem: NFSv4 (explicit, profile value ignored)
- Mount options: `defaults,nofail,_netdev,ro` (explicit, read-only)
- Dump frequency: `0` (from `network_storage` profile)
- Fsck pass: `0` (from `network_storage` profile)

---

### Example 6: Swap Configuration

```yaml
swap:
  - name: "compute_swap"
    filename: "/swapfile"
    size: "2G"
    maxsize: "4G"
    functional_group_prefix: ["slurm_node"]
```

**Result:** A 2G swap file (up to 4G) created at `/swapfile` on all nodes whose functional group starts with `slurm_node`.

---

## Priority Resolution

When a mount entry references a profile via `mount_params`, field values are resolved using this priority order:

### Priority Order (Highest to Lowest)

```
1. Explicit value in mount entry          ← HIGHEST PRIORITY
2. Value from mount_params profile (if specified)
3. Auto-selected profile based on fs_type
4. Global fallback profile (global)
5. Hardcoded system defaults              ← LOWEST PRIORITY
```

### Resolution Examples

#### Example 1: Full Profile Usage

```yaml
mount_params:
  vast_nfs:
    fs_type: "nfs4"
    mnt_opts: "defaults,nofail,_netdev,noatime"
    dump_freq: "0"
    fsck_pass: "0"

mounts:
  - name: "vast_home"
    source: "192.168.1.100:/home"
    mount_point: "/home"
    mount_params: "vast_nfs"
    functional_group_prefix: ["slurm_node"]
```

**Resolution:**
- `fs_type`: `"nfs4"` ← from `vast_nfs` profile
- `mnt_opts`: `"defaults,nofail,_netdev,noatime"` ← from `vast_nfs` profile
- `dump_freq`: `"0"` ← from `vast_nfs` profile
- `fsck_pass`: `"0"` ← from `vast_nfs` profile

---

#### Example 2: Partial Override

```yaml
mount_params:
  vast_nfs:
    fs_type: "nfs4"
    mnt_opts: "defaults,nofail,_netdev,noatime"
    dump_freq: "0"
    fsck_pass: "0"

mounts:
  - name: "vast_apps"
    source: "192.168.1.100:/apps"
    mount_point: "/opt/apps"
    fs_type: "nfs4"                         # ← EXPLICIT
    mnt_opts: "defaults,nofail,_netdev,ro"  # ← EXPLICIT
    mount_params: "vast_nfs"
    functional_group_prefix: ["slurm_node"]
```

**Resolution:**
- `fs_type`: `"nfs4"` ← **EXPLICIT (priority 1)** — profile value ignored
- `mnt_opts`: `"defaults,nofail,_netdev,ro"` ← **EXPLICIT (priority 1)** — profile value ignored
- `dump_freq`: `"0"` ← from `vast_nfs` profile (priority 2)
- `fsck_pass`: `"0"` ← from `vast_nfs` profile (priority 2)

---

#### Example 3: No Profile — All Fields Explicit

```yaml
mounts:
  - name: "atomic_data"
    source: "192.168.1.100:/data"
    mount_point: "/data"
    fs_type: "nfs4"
    mnt_opts: "defaults,nofail,_netdev"
    dump_freq: "0"
    fsck_pass: "0"
    functional_group_prefix: ["slurm_node"]
```

**Resolution:** All four fstab fields are explicit (priority 1). No profile lookup is performed.

---

## Best Practices

### Profile Design

✅ **DO:**
- Create profiles for common storage patterns
- Use descriptive profile names (`vast_nfs`, `powervault_iscsi`)
- Add custom fields (e.g., `vast_nfs_ip`) for template variables
- Document profile purpose and use cases
- Keep profiles simple and focused on a single storage technology

❌ **DON'T:**
- Include `functional_group_prefix` in profiles — it belongs in mount entries
- Create too many near-identical profiles
- Use generic names like `profile1`, `profile2`

---

### Mount Configuration

✅ **DO:**
- Use profiles (`mount_params`) for standard configurations
- Override specific fields when needed (e.g., force `ro`)
- Use UUID for PowerVault sources — more reliable than device paths
- Specify `functional_group_prefix` on every mount entry
- Use descriptive, alphanumeric mount names (no spaces)
- Order bind mounts **after** their parent mount in the list

❌ **DON'T:**
- Duplicate mount options across many entries — use profiles
- Use device paths (`/dev/sda1`) for PowerVault — use UUID
- Omit `functional_group_prefix` unless you intentionally want all-nodes application
- Place bind mounts before their parent in the `mounts[]` list

---

### functional_group_prefix Targeting

The `functional_group_prefix` field uses prefix matching against node functional group names:

| Prefix | Matches |
|--------|---------|
| `["slurm"]` | `slurm_control_node`, `slurm_node`, `slurm_login`, `slurm_control_node_x86_64`, ... |
| `["slurm_control_node"]` | `slurm_control_node`, `slurm_control_node_x86_64`, `slurm_control_node_aarch64` |
| `["slurm_control_node_x86_64"]` | `slurm_control_node_x86_64` only |
| `["k8s"]` | `k8s_node`, `k8s_control_node`, `k8s_worker`, ... |
| `["slurm", "k8s"]` | All Slurm nodes AND all K8s nodes |

Use the most specific prefix needed. Broader prefixes like `["slurm"]` apply to all Slurm node types across all architectures.

---

### Storage Selection

| Requirement | Recommended Storage | Profile |
|-------------|---------------------|---------|
| Shared home directories | VAST NFS | `vast_nfs` |
| Shared applications | VAST NFS | `vast_nfs` |
| High-throughput scratch | VAST NFS | `vast_nfs_performance` |
| Large datasets | VAST NFS | `vast_nfs_performance` |
| Persistent databases | PowerVault iSCSI | `powervault_iscsi` |
| Slurm state files | PowerVault iSCSI | `powervault_iscsi` |
| Service bind mounts | PowerVault subdirectory | `bind_mounts` |
| Local scratch | Local disk | `scratch_storage` |
| Generic network FS | NFS/CIFS | `network_storage` |

---

### Performance Optimization

#### VAST NFS

**Standard Workloads (`vast_nfs`):**
- Home directories
- Shared applications
- Small file I/O
- Metadata-heavy operations

**High-Performance Workloads (`vast_nfs_performance`):**
- Scratch space
- Checkpointing
- Large sequential I/O
- Streaming data

**Buffer Size Tuning:**
```yaml
# Standard: default buffers (typically 32KB–128KB)
mnt_opts: "defaults,nofail,_netdev,noatime"

# High-performance: 1MB buffers
mnt_opts: "defaults,nofail,_netdev,noatime,nodiratime,rsize=1048576,wsize=1048576"
```

#### PowerVault iSCSI

**Filesystem Choice:**
- ✅ **XFS** (recommended) — High performance, scalability, large files
- ⚠️ **ext4** — Good compatibility, lower performance at scale

**Mount Options:**
```yaml
# Recommended
mnt_opts: "defaults,_netdev,noatime,x-systemd.requires=iscsi.service"

# Additional options for databases
mnt_opts: "defaults,_netdev,noatime,nobarrier,x-systemd.requires=iscsi.service"
```

---

## Validation Rules

### Required Fields

#### Mount Entry (`mounts[]`)

- ✅ `name` — Unique identifier (alphanumeric, `_`, `-`; no spaces)
- ✅ `source` — Device or network path
- ✅ `mount_point` — Absolute path starting with `/`
- ✅ `functional_group_prefix` — List of functional group prefixes
- ✅ **At least one of:**
  - `mount_params` (references a `mount_params` profile), **OR**
  - `mnt_opts` (explicit mount options)

#### PowerVault Entry (`powervault_config[]`)

- ✅ `name` — Unique identifier for this volume
- ✅ `ip` — List of controller IPv4 addresses (min 1)
- ✅ `iscsi_initiator` — IQN string
- ✅ `volume_id` — Hex WWN string
- ⬜ `port` — Optional; defaults to `3260`
- ✅ **Exactly one of:**
  - `mount: <name>` (Mode A — references a `mounts[]` entry), **OR**
  - Inline fields: `source`, `mount_point`, `mount_params` / `mnt_opts`, `functional_group_prefix` (Mode B)

#### Swap Entry (`swap[]`)

- ✅ `name` — Unique identifier
- ✅ `filename` — Absolute path for the swap file
- ✅ `size` — Human-readable size (`2G`, `512M`, `auto`)
- ⬜ `maxsize` — Optional; used only when `size: auto`
- ✅ `functional_group_prefix` — List of functional group prefixes

#### Profile (`mount_params`)

- ✅ `fs_type` — Filesystem type
- ✅ `mnt_opts` — Mount options
- ✅ `dump_freq` — Dump frequency
- ✅ `fsck_pass` — Fsck pass number
- ⬜ Custom fields (e.g., `vast_nfs_ip`, `perf_ip`) — Optional; passed to Jinja2 templates

---

### Field Validation

#### `name` (mount or swap)
- Pattern: `^[a-zA-Z0-9_-]+$`
- Length: 1–64 characters
- Must be unique across all entries in the same list

#### `source`
- Minimum length: 1 character
- Examples:
  - `/dev/sda1`
  - `UUID=12345678-1234-1234-1234-123456789abc`
  - `192.168.1.100:/export/share`
  - `{{ vast_nfs_ip }}:/home` (Jinja2 template resolved at generation time)

#### `mount_point`
- Pattern: `^/[a-zA-Z0-9/_.-]*$`
- Must start with `/`

#### `fs_type`
- Allowed values: `auto`, `ext2`, `ext3`, `ext4`, `xfs`, `btrfs`, `nfs`, `nfs4`, `cifs`, `tmpfs`, `cephfs`, `vfat`, `ntfs`, `none`

#### `mnt_opts`
- Pattern: `^[a-zA-Z0-9,=._-]+$`
- Examples: `defaults,nofail,_netdev`, `bind`, `defaults,nofail,noatime`

#### `dump_freq`
- Pattern: `^[0-2]$`
- Usually `0` (no dump)

#### `fsck_pass`
- Pattern: `^[0-9]$`
- Common values:
  - `0` — No fsck (network filesystems, bind mounts)
  - `1` — Root filesystem
  - `2` — Other local filesystems

#### `functional_group_prefix`
- Array of strings
- Pattern per element: `^[a-zA-Z0-9_-]+$`
- Must be unique within array
- Prefix-matched against node functional group names at provisioning time

#### `volume_id` (PowerVault)
- Pattern: `^[a-fA-F0-9]+$`

#### `iscsi_initiator` (PowerVault)
- Pattern: `^iqn\.[a-zA-Z0-9.-]+(?::[a-zA-Z0-9._:-]+)?$`

#### `size` (swap)
- Pattern: `^(auto|[0-9]+[BKMGT]?)$`
- Examples: `2G`, `512M`, `auto`

---

### Conditional Validation

#### Mount Entry Must Have Profile OR Explicit Options

```json
{
  "anyOf": [
    { "required": ["mount_params"] },
    { "required": ["mnt_opts"] }
  ]
}
```

**Valid:**
```yaml
# Has mount_params profile
- name: "mount1"
  source: "..."
  mount_point: "..."
  mount_params: "vast_nfs"
  functional_group_prefix: ["slurm"]

# Has mnt_opts explicit
- name: "mount2"
  source: "..."
  mount_point: "..."
  mnt_opts: "defaults,nofail"
  functional_group_prefix: ["slurm"]

# Has both — explicit wins for mnt_opts, profile fills the rest
- name: "mount3"
  source: "..."
  mount_point: "..."
  mount_params: "vast_nfs"
  mnt_opts: "defaults,nofail,ro"   # overrides profile's mnt_opts
  functional_group_prefix: ["slurm"]
```

**Invalid:**
```yaml
# Missing both mount_params and mnt_opts
- name: "mount_invalid"
  source: "..."
  mount_point: "..."
  functional_group_prefix: ["slurm"]
```

---

## Quick Reference

### Profile Selection Guide

| Storage Type | Use Case | Profile | Key Features |
|--------------|----------|---------|--------------|
| **VAST** | Home directories | `vast_nfs` | NFSv4, standard perf |
| **VAST** | Shared apps | `vast_nfs` | NFSv4, standard perf |
| **VAST** | Scratch space | `vast_nfs_performance` | NFSv4, 1MB buffers |
| **VAST** | Large datasets | `vast_nfs_performance` | NFSv4, 1MB buffers |
| **PowerVault** | Persistent storage | `powervault_iscsi` | XFS, iSCSI service dep |
| **PowerVault** | Database bind | `bind_mounts` | Bind from persistent mount |
| **Generic** | Network FS | `network_storage` | Auto-detect FS |
| **Local** | Local disk | `local_storage` | Auto-detect FS |
| **Local** | Scratch | `scratch_storage` | XFS, optimized |

---

### Common Mount Options

| Option | Description | Use Case |
|--------|-------------|----------|
| `defaults` | Use default options | All mounts |
| `nofail` | Don't fail boot if mount fails | Network mounts |
| `_netdev` | Network device (wait for network) | Network mounts |
| `noatime` | Don't update access time | Performance |
| `nodiratime` | Don't update directory access time | Performance |
| `ro` | Read-only | Shared apps, datasets |
| `rw` | Read-write | Default |
| `bind` | Bind mount | Subdirectory mounts |
| `rsize=1048576` | 1MB read buffer | High-perf NFS |
| `wsize=1048576` | 1MB write buffer | High-perf NFS |
| `x-systemd.requires=iscsi.service` | Require iSCSI service | PowerVault |
| `x-systemd.after=cloud-init-network.service` | Wait for cloud-init network | Network mounts |

---

### Filesystem Types

| Type | Description | Use Case |
|------|-------------|----------|
| `nfs` | NFS version 3 | Legacy NFS |
| `nfs4` | NFS version 4 | Modern NFS (VAST) |
| `xfs` | XFS filesystem | PowerVault, local disks |
| `ext4` | ext4 filesystem | Local disks |
| `cifs` | SMB/CIFS | Windows shares |
| `none` | No filesystem | Bind mounts |
| `auto` | Auto-detect | Generic mounts |

---

## Troubleshooting

### Common Issues

#### Issue: Mount fails with "mount.nfs: Connection timed out"

**Cause:** Network not ready or VAST server unreachable.

**Solution:**
- Ensure `_netdev` and `x-systemd.after=cloud-init-network.service` in mount options
- Verify VAST server IP is correct and reachable
- Check firewall rules (NFS ports: 2049, 111)

---

#### Issue: PowerVault mount fails with "No such device"

**Cause:** iSCSI service not running or multipath device not ready.

**Solution:**
- Ensure `x-systemd.requires=iscsi.service` in mount options
- Verify `powervault_config` is correctly configured
- Check iSCSI discovery: `iscsiadm -m discovery -t sendtargets -p <IP>`
- Check multipath devices: `multipath -ll`

---

#### Issue: Bind mount fails with "mount point does not exist"

**Cause:** Source directory does not exist (parent mount not yet mounted, or list ordering issue).

**Solution:**
- Ensure the parent mount entry appears **before** the bind mount in `mounts[]`
- Create the source directory: `mkdir -p /mnt/slurm-persist/mysql`
- Check that the parent PowerVault mount is healthy

---

#### Issue: Validation error "must have either mount_params or mnt_opts"

**Cause:** Mount entry is missing both a profile reference and explicit mount options.

**Solution:**
- Add `mount_params: "profile_name"`, **OR**
- Add `mnt_opts: "mount_options"`

---

#### Issue: Mount name fails validation

**Cause:** Mount `name` contains spaces or special characters (e.g., `"Atomic mount"`).

**Solution:**
- Use only alphanumeric characters, underscores, and hyphens: `"atomic_mount"`

---

## References

### Related Files

- **Configuration:** `input/storage_config.yml`
- **Schema:** `common/library/module_utils/input_validation/schema/storage_config.json`
- **Cloud-Init Template:** `discovery/roles/configure_ochami/templates/cloud_init/ci-group-*.yaml.j2`
- **PowerVault Setup Script:** Embedded in cloud-init template (`setup_iscsi_storage.sh`)
- **Cluster Configuration:** `input/omnia_config.yml` (references mount names via `mounts:` list)

---

## Design Decision: storage_config.yml vs storage_profile.yml

This section documents the evaluation of two proposed input designs for filling the cloud-init `mounts:` module in oChaMI per-group cloud-init data, and explains the rationale for choosing `storage_config.yml`.

---

### Goal

oChaMI provisions nodes by pushing per-group cloud-init payloads. Each payload's `mounts:` module requires a flat list of fstab tuples:

```yaml
mounts:
  - [source, mount_point, fs_type, mnt_opts, dump_freq, fsck_pass]
  - [source, mount_point, fs_type, mnt_opts, dump_freq, fsck_pass]
```

The design must be **simple and minimal** — the template engine should be able to produce this list for any given functional group without complex logic, missing fields, or ambiguous conventions.

---

### Resolution Path Comparison

#### `storage_config.yml` — 1-hop resolution

```
functional_group name  (e.g. slurm_node_x86_64)
       │
       ▼
  scan mounts[] where functional_group_prefix prefix-matches the group name
       │
       ▼  (one direct pass)
  for each matched mount entry:
    resolve [source, mount_point, fs_type, mnt_opts, dump_freq, fsck_pass]
    via: explicit field  →  mount_params profile  →  global default
       │
       ▼
  flat list of tuples  ──►  cloud-init mounts:
```

One loop. One dict merge per entry. No construction, no inference.

#### `storage_profile.yml` — 4-hop resolution

```
functional_group name  (e.g. slurm_compute_x86_64)
       │
       ▼
  mounts[cluster][functional_group]  →  profile name(s)
       │
       ▼
  storage_profiles[profile][backend_ref]  →  path map
       │
       ▼
  storage_config[section][backend_ref]  →  ip(s), options, protocol
       │
       ▼
  construct source = ip + server_path
  mount_point = client_path          ← direction undocumented
  fs_type = inferred from protocol   ← not explicit
  mnt_opts = options from backend    ← no per-path override possible
  dump_freq = ???                    ← missing entirely
  fsck_pass = ???                    ← missing entirely
       │
       ▼
  flat list of tuples  ──►  cloud-init mounts:
```

Four hops, path direction ambiguity, two required fstab fields absent.

---

### Field-by-Field Comparison

| cloud-init field | `storage_config.yml` | `storage_profile.yml` |
|---|---|---|
| `source` | Explicit on mount entry | Constructed: `ip + server_path` from `storage_config` |
| `mount_point` | Explicit on mount entry | Ambiguous: `"/home": "/home"` — which is server, which is client? |
| `fs_type` | Explicit or from `mount_params` profile | Must be inferred from `protocol` field |
| `mnt_opts` | Explicit or from `mount_params` profile | `options` from backend config; no per-path overrides |
| `dump_freq` | Explicit or from profile | **Not present anywhere in the file** |
| `fsck_pass` | Explicit or from profile | **Not present anywhere in the file** |
| Node targeting | `functional_group_prefix` per mount | `mounts[cluster][fg_name]` → profile → backend (3 levels) |
| Resolution hops | **1 (direct match + profile merge)** | **4 (cluster → fg → profile → backend)** |
| Template complexity | Low — filter loop + dict merge | High — nested loops, type dispatch, fallback inference |

---

### Issues Found in Each Approach

#### `storage_config.yml` — Fixable Issues

| Issue | Severity | Fix |
|---|---|---|
| `mount_params` key diverges from JSON schema (`mount_default_fields`) | High | Update schema to match file |
| `omnia_config.yml` references `nfs_slurm`, `nfs_home` — neither exists as a mount `name` | High | Add matching named entries or align names |
| `"Atomic mount"` name contains a space — fails schema pattern | Medium | Rename to `atomic_mount` |
| `functional_group_prefix` omitted on one entry — undefined all-nodes behavior | Medium | Document or enforce requirement |
| Bind mount ordering not enforced — depends on list position | Low | Document ordering requirement |
| `vast_nfs_ip`, `perf_ip` custom fields in profiles — schema `additionalProperties: false` rejects them | Medium | Relax schema for custom fields |

All issues are mechanical — wrong key names, missing entries, schema not updated after design evolved.

#### `storage_profile.yml` — Structural Issues

| Issue | Severity | Fix |
|---|---|---|
| Path map direction `"/home": "/home"` undocumented — server:client or client:server? | **Critical** | No fix without redesign |
| PowerVault entries are scalars (`pv1_volume1: "/var/lib/mysql"`) vs NFS entries are maps — structurally inconsistent | **Critical** | No fix without redesign |
| `dump_freq` and `fsck_pass` absent — cannot generate valid fstab tuple | **Critical** | Requires new fields added throughout |
| `slurm_common_profile` is null — silently applies nothing | High | Validate against null profiles |
| `slurm_login_x86_64` is null — login nodes silently get no mounts | High | Validate against null node assignments |
| `nfs1` and `nfs2` are identical copies — `slurm_compute_profile_aarch64` resolves to same paths as base | Medium | Copy-paste error |
| `ps1` uses `ips:` (list), `ps2` uses `ip:` (scalar) — inconsistent field names | Medium | Standardize field name |
| Multi-profile list (`- slurm_compute_profile\n- slurm_compute_profile_aarch64`) has no merge strategy — `/home` collision | High | Define merge semantics |
| `/tmp` mounted from VAST NFS in compute and compiler profiles — network `/tmp` is a reliability risk in HPC | Medium | Design smell |

The structural issues (path direction, missing fstab fields, inconsistent value types) cannot be fixed by adding fields — they require reconceiving the profile format.

---

### Why `storage_config.yml` Wins for This Use Case

**1. Shape matches the output.** Each `mounts[]` entry is already one fstab tuple. The Jinja2 template is a filter — no construction or inference. `storage_profile.yml` requires building the tuple from scattered pieces across three separate data structures.

**2. All six fstab fields are present.** `source`, `mount_point`, `fs_type`, `mnt_opts`, `dump_freq`, `fsck_pass` are either explicit on the entry or resolved from `mount_params`. `storage_profile.yml` is missing `dump_freq` and `fsck_pass` entirely.

**3. `functional_group_prefix` is the right targeting primitive.** oChaMI groups nodes by functional group name. Prefix matching (`["slurm"]` matches `slurm_node_x86_64`, `slurm_control_node_aarch64`, etc.) handles architecture variants without enumerating every combination. `storage_profile.yml`'s cluster → role mapping adds indirection that only matters if clusters are topologically distinct — which is already handled by `omnia_config.yml`.

**4. `mount_params` profiles provide reuse without indirection.** The VAST RDMA flags (`rsize`, `wsize`, `noatime`) live in one profile and are inherited by all referencing mounts. This is the same reuse benefit `storage_profile.yml` claims for its role profiles, but without the extra lookup hop.

**5. `storage_profile.yml`'s multi-cluster advantage is already covered.** `omnia_config.yml` manages cluster topology. Each cluster entry references mount names from `storage_config.yml`. Cluster-level scoping belongs in the cluster config, not the storage config.

---

### Conclusion

> **`storage_config.yml` is the chosen design.** It directly satisfies the requirement of filling the cloud-init `mounts:` module per functional group with minimal template complexity and zero ambiguity. The issues found are all fixable with targeted corrections to key names and schema alignment. `storage_profile.yml`'s issues are structural and cannot produce valid fstab tuples without a fundamental redesign.

---

## Changelog

### Version 1.1 (2026-03-27)

- Renamed `mount_default_fields` → `mount_params` throughout (matches `storage_config.yml`)
- Renamed `mount_default_field` → `mount_params` on mount entries
- Renamed `roles` → `functional_group_prefix` on mount and swap entries
- Updated `powervault_config` from single object to **list** (supports multiple volumes)
- Documented dual PowerVault mount modes: Mode A (`mount:` reference) and Mode B (inline fields)
- Added custom fields (`vast_nfs_ip`, `perf_ip`) to `vast_nfs` and `vast_nfs_performance` profiles
- Added `nfs_bind_mounts` profile reference in examples
- Added Example 0 (atomic mount with all explicit fields)
- Added Example 6 (swap configuration)
- Added `functional_group_prefix` targeting reference table
- Added bind mount ordering requirement and warning
- Added troubleshooting entry for invalid mount names (spaces)
- Updated Architecture diagram to reflect list-based `powervault_config` and `swap`
- Updated all validation rules to match current field names and structures

### Version 1.0 (2026-03-20)

- Initial design document
- Added VAST NFS profiles (`vast_nfs`, `vast_nfs_performance`)
- Added PowerVault iSCSI profile (`powervault_iscsi`)
- Removed `roles` field from profiles (roles only in mount entries)
- Changed `mount_default_fields` from array to mapping structure
- Added conditional validation (`mount_default_field` OR `mnt_opts` required)
- Updated examples to reflect VAST and PowerVault storage
- Aligned PowerVault examples with `setup_iscsi_storage.sh` implementation

---

## Contact

For questions or issues, please contact the Omnia development team.

---
