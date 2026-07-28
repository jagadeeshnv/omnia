No. disk_setup cannot do this task. Here's why:

What disk_setup + fs_setup can do

  • Partition a known, static block device path (e.g., /dev/sdb, /dev/sdc)
  • Format the partition with a filesystem
  • Works only on devices that exist at cloud-init boot time

Why it cannot replace setup_iscsi_storage.sh

The script does work that must happen before any device path is known:

Step                                                                                disk_setup capable?
Enable iscsid daemon                                                                No
Set /etc/iscsi/initiatorname.iscsi                                                  No
iSCSI target discovery (iscsiadm -m discovery)                                      No
iSCSI login (iscsiadm -m node --login)                                              No
Enable multipathd                                                                   No
Identify the correct /dev/mapper/<X> by matching VOLUME_ID                          No
Create GPT partition if absent                                                      Yes (disk_setup)
Format with xfs if no filesystem exists                                             Yes (fs_setup with overwrite: false)
Add fstab entry and mount                                                           Yes (mounts:)
Create bind mounts for mysql/spool subdirs                                          Yes (mounts:)

The hard blocker: disk_setup takes a static device path as the key (/dev/sdb, etc.). The multipath device (/dev/mapper/<name>) is not known until after iSCSI login and multipath scanning —
which is dynamic runtime work that disk_setup has no hook for.

The iSCSI/multipath setup steps (top 6 rows) must remain in runcmd or a script. Once the device is discovered and the path is known, the partition+format+mount portion could theoretically 
use disk_setup+fs_setup+mounts: — but only if you hardcode /dev/mapper/<name> in the config, which defeats the purpose since volume_id matching is what identifies the right device 
dynamically.

Bottom line: disk_setup is for simple, pre-known local block devices. iSCSI over multipath requires daemon setup, target discovery, and dynamic device resolution — none of which cloud-init
modules support. The script stays in runcmd.