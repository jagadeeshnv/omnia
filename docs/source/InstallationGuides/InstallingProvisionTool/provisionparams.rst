Input Parameters for Provision Tool
=====================================

Fill in all provision-specific parameters in ``omnia/input/provision_config.yml``


+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Name                             | Default, Accepted Values        | Required? | Additional Information                                                                                                                                                                                                                                                                                                          |
+==================================+=================================+===========+=================================================================================================================================================================================================================================================================================================================================+
| public_nic                       |                                 | TRUE      | The NIC/ethernet card that is connected to the public internet.                                                                                                                                                                                                                                                                 |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| admin_nic                        |                                 | TRUE      | The NIC/ethernet card that is used for shared LAN over Management (LOM)   capability.                                                                                                                                                                                                                                           |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| admin_nic_subnet                 |                                 | TRUE      | The intended subnet for shared LOM capability.                                                                                                                                                                                                                                                                                  |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| pxe_nic                          |                                 | TRUE      | This NIC used to obtain routing information.                                                                                                                                                                                                                                                                                    |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| pxe_nic_start_range              |                                 | TRUE      | The start of the DHCP  range used   to assign IPv4 addresses                                                                                                                                                                                                                                                                    |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| pxe_nic_end_range                |                                 | TRUE      | The end of the DHCP  range used to   assign IPv4 addresses                                                                                                                                                                                                                                                                      |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ib_nic_subnet                    |                                 | FALSE     | If provided, Omnia will assign static IPs to IB NICs on the compute nodes   within the provided subnet.                                                                                                                                                                                                                         |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| bmc_nic_subnet                   |                                 | FALSE     | If provided, Omnia will assign static IPs to IB NICs on the compute nodes   within the provided subnet.                                                                                                                                                                                                                         |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| pxe_mapping_file_path            |                                 | FALSE     | The mapping file consists of the MAC address and its respective IP   address and hostname. If static IPs are required, create a csv file in the   format MAC,Hostname,IP. A sample file is provided here:   omnia/examples/host_mapping_file_os_provisioning.csv. If not provided, ensure   that ``pxe_switch_ip`` is provided. |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| pxe_switch_ip                    |                                 | FALSE     | PXE switch that will be connected to all iDRACs for provisioning                                                                                                                                                                                                                                                                |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| pxe_switch_snmp_community_string | public                          | FALSE     | The SNMP community string used to access statistics, MAC addresses and   IPs stored within a router or other device.                                                                                                                                                                                                            |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| node_name                        | node                            | TRUE      | The intended node name for nodes in the cluster.                                                                                                                                                                                                                                                                                |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| domain_name                      | omnia.test                      | TRUE      | DNS domain name to be set for iDRAC.                                                                                                                                                                                                                                                                                            |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| provision_os                     | rocky,rhel                      | TRUE      | The operating system image that will be used for provisioning compute   nodes in the cluster.                                                                                                                                                                                                                                   |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| iso_file_path                    | /home/Rocky-8.6-x86_64-dvd1.iso | TRUE      | The path where the user places the ISO image that needs to be provisioned   in target nodes.                                                                                                                                                                                                                                    |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| timezone                         | GMT                             | TRUE      | The timezone that will be set during provisioning of OS. Available   timezones are provided in provision/roles/xcat/files/timezone.txt.                                                                                                                                                                                         |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| language                         | en-US                           | TRUE      | The language that will be set during provisioning of the OS                                                                                                                                                                                                                                                                     |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| default_lease_time               | 86400                           | TRUE      | Default lease time in seconds that will be used by DHCP.                                                                                                                                                                                                                                                                        |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| provision_password               |                                 | TRUE      | Password used while deploying OS on bare metal servers. The Length of the   password should be at least 8 characters. The password must not contain -,\,   ',".                                                                                                                                                                 |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| postgresdb_password              |                                 | TRUE      | Password used to authenticate into the PostGresDB used by xCAT.                                                                                                                                                                                                                                                                 |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| primary_dns                      |                                 | FALSE     | The primary DNS host IP queried by Cobbler to provide Internet access to   Compute Node (through DHCP routing)                                                                                                                                                                                                                  |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| secondary_dns                    |                                 | FALSE     | The secondary DNS host IP queried by Cobbler to provide Internet access   to Compute Node (through DHCP routing)                                                                                                                                                                                                                |
+----------------------------------+---------------------------------+-----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+