# ZFDR

The purpose of this script is to help clients run DR failovers when using GCVE as a DR target for VMware VMs.

## Expected configuration

The expected configuration is that the end-user will have one of three topologies:

| Production Site  | DR Site |
| ------------- | ------------- |
| On-premises | GCVE  |
| GCVE | On-premises  |
| GCVE | GCVE  |


The goal is to offer a simplified way to manage failover from Production to DR or failback where:
* The backup mechanism is to place VMware VM backups into Google Cloud Storage (GCS) using OnVault images.
* These images are created by a Backup Appliance on the Production site and then imported by a Backup Appliance on the DR site.
* The number of VMs that need to be recovered is neither trivial (such as 6) or massive (such as 600), but somewhere between that.
* At this time everything is coded on the assumption that each VM name is unique.   This may not be totally realistic in the real world, but is a good practical suggestion (since duplicate VM names are confusing)

## Failover and failback

Effectively failover and failback are identical because they are achieved using the same mechanism, so we will only use the term failover.   Where you read failover, failback is performed in exactly the same way.

## CSV file

The expectation is that the user will maintain a CSV file that is essentially the heart of the failover operation.
We can create a CSV from the source side with all the right headings using the export CSV option or we can start by creating a CSV on the source side which will have at least the following headings:
```
sourcevmname
sourcepowerstate
sourcenicname
sourceconnectionstate
sourcemacaddress
sourceipaddress
phase
targetvmname
label
targetnetworkname
targetmacaddress
label
poweronvm
onvault
perfoption
```
Without the CSV file we cannot function, meaning we cannot enter a DR situation and then use this function to a run a failover without it.   We don't want to be creating CSV files during a DR.
In the CSV file we normally need to configure the following columns:

* phase:  in most scenarios we will start the VMs in phases, which means we run through a phase for each set of recoveries.  Which phase a VM belongs in cannot normally be guessed.  It usually needs the Administrator to have a clear understanding of VM creation order.
* targetvmname.   For some cases this will be the source VM name, but for testing, this may not work.  Please ensure this field is set to remove any risk of confusion.
* targetnetworkname:  This is the name of the network where we want the VM to be placed.   Note the VM must be powered on to change the network,
* targetmacaddress:  This is the mac address of the NIC of the new VM.   Leave this blank unless needed.  If set, the VM should always be created in a powered off state since you don't want the VM to 'wake up' and find a new MAC Address.
* label:  This does not need to be set, but is used by the backup appliance to find images.   If we set it, we can use it for identification.  
* poweronvm:  This is the power state of the mounted VM.  If blank, then poweronvm is true.   If the word **false** is in this column, the VM will not be powered on.  
* onvault:  The value you would normally use here is always *true* indicating you want OnVault images to be used.   If you don't specify anything here then the process will look firstly for snapshots.
* -perfoption:   Valid values here are StorageOptimized, Balanced, PerformanceOptimized or MaximumPerformance.  We recommend StorageOptimized since this will bypass the snapshot pool altogether.   This is best if you are going to use storage vMotion (migration) to move the data onto the VMware datastore, since it means that same data wont be written into the snapshot pool.

## Networking
By default after creating a new VM, the VM has the following characteristics and consequent considerations:
* The VM is powered on with a new MAC Address
* The NICs are disconnected. This is done to ensure fixed IP addresses do not result in duplicate IPs on the network.  
* If the same network as the source exists, the VM will be connected to that network, otherwise it will default to **unknown**
Potential issues because of this behaviour:
* The VM NICs will have new MAC addresses.
  * For Linux VMs this can be a major issue.  You may have a situation where the existing eth0 no longer works (as it is bound to the old MAC address) and a new eth1 is created which also doesn't work (because the VMs nic is bound to eth0)
  * If DHCP is being used based on MAC address, then IPs will not be allocated
  * If the host is running licensed software, the software may perceive the host has 'changed' and the software will need to be relicensed.
  * If a fixed MAC address is specified with **targetmacaddress** then the VM will be created in the powered off mode regardless of how **poweronvm** is set
* The VM has the same IP settings as the source, meaning:
  * If the VM had a configured IP, it still will have.  This means if you recover into the production network or one routed to it, you can have duplicate IPs
  * If the VM was set for DHCP it still will be. This means if there is no DHCP server there will be no IPs set.  Also if DHCP uses MAC addresses for allocation and the VMs have new MAC addresses, this can cause issues  
* We can use VMware tool commands to change the IP settings, but this requires host authentication when running the **Invoke-VMScript** command

There can be several scenarios:

* We recover to the same networks which are pre-created, using the same network settings. For each VM we then:
  * Enable the network interface
* We recover to a different network, which is pre-created, using the same network settings. For each VM we then:
  * Set the network
  * Enable the network interface
* We recover to the same networks which are pre-created, using different network settings. For each VM we then:
  * Run an OS command to set the network settings (something this script does not currently support)
  * Set the network
  * Enable the network interface

If we want to retain the same MAC address we need to set this BEFORE the OS boots up.   We do NOT want a situation where the OS starts with a new MAC and then we set the original.   This only makes the situation harder to resolve.

## Installation and setup

### PowerShell Version 7

To install PowerShell 7 in Windows:
https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows

To install PowerShell in Linux:
```
# Register the Microsoft RedHat repository
curl https://packages.microsoft.com/config/rhel/8/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
# Install PowerShell
sudo yum install -y powershell
# Start PowerShell
pwsh
```

### Install all the modules
Run these four commands.  The fourth one presumes your vCenter does not have a signed cert (which is the case for GCVE)  
Minimum version of AGMPowerLib is 0.0.0.43
```
Install-Module AGMPowerCli -Scope CurrentUser
Install-Module AGMPowerLib -Scope CurrentUser
Install-Module VMware.PowerCLI -Scope CurrentUser
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
```
### Login to AGM and vCenter:
Set your password:
```
$mysecret = "password"
```
Connect to the AGM.  The second command is used to confirm you have connected.
```
Connect-agm 10.152.0.5 admin $mysecret -i
Get-AGMVersion
```
Connect to vCenter.  The second command confirms you have connected.
```
Connect-VIServer -Server 172.16.0.6 -User actifio-user@GVE.LOCAL -Password $mysecret
Get-VM
```

## Import Start-GCVERecovery.ps1
We need to import our ps1 file as a module:
```
PS C:\Users\avw\Downloads> Import-Module .\Start-GCVERecovery.ps1
PS C:\Users\avw\Downloads>
```
The **Start-GCVERecovery** function is used to:
* Gather information on the source side
* Run recovery or tests on the target side

When running the function, ideally the user will supply two parameters:
* **-filename XXXX.csv** Which is the name of the CSV file.  We will give the user a chance to set it later if not supplied.
* **-phase Y** Where Y is the current phase we are running.   If no phase is given, the script assumes we are in phase 1.

Every time the function is run it will validate if connections exist to an AGM and a vCenter and complain if these connections do not exist.

### Source side operations

Currently there are the following functions.  More may be added.  
  ```
  1: Login to AGM            Do you need to login to AGM with Connect-AGM?
  2: Login to vCenter        Do you need to login to vCenter with Connect-VIServer?
  3: Export AGM SLTs         Do you want to export your Policy Templates from AGM?  If we have two AGMs, this will help us set up protection on the target side.
  4: Display VMware Config   Do you want to display the config of your current VMs?
  5: Export VMware Config    Do you want to export the config of your current VMs?  This creates a new CSV file.
  ```
  Effectively the order of operations prior a failover is the following:

1. The user creates the CSV file and maintains it.  Particular care is taken to ensure that:
   * The correct phase is set for each VM
   * That the desired target network is set and that the desired target MAC address is set if needed
   * That a meaningful target name is used.   For tests it may be necessary to use a different target name
   * That a useful label is set

### Target side operations

Currently there are the following functions.  More may be added.   
```
 1: Login to AGM            Do you need to login to AGM with Connect-AGM?
 2: Login to vCenter        Do you need to login to vCenter with Connect-VIServer?
 3: Import AGM SLTs         Do you want to import Policy Templates from the source AGM?  Note you need to have a file of exported SLTs to do this
 4: Import OnVault images   Do you want to import (or forget) the latest images from an OnVault pool so they can be used in the DR Site?
 5: Supply/display filename Do you want to set or display your recovery file.
 6: Set the phase           Do you want to set which phase it is.  Current phase is X
 7: List OnVault images     Do you want to see the latest backup date for each VM in the current phase?
 8: Create new VMs          Do you create a new set of VMs based on a phase number?  This will start mount jobs on the Backup Appliance
 9: Monitor jobs            Do you want to monitor jobs running on the Backup Appliance
10: List your mounts        Do you want to list the current mounts in Backup Appliance
11: List your VMware VMs    Do you want to list the VMs in VMware
12: List phase VMware VMs   Do you want to list the VMs in VMware created in this phase.  If you get nothing back, have you run step 6 yet?
13: Set VMware Networking   Do you want to configure VMware VM networking based on a phase number?  This will set network and enable network interface.  It will also change MAC address and power on the VM afterwards.
14: MigrateVMs              Do you want to migrate the VMs in the current phase
15: Unmount your images     Do you want to unmount the VMs we mounted?
16: Delete VMs              Do you want to DELETE the VMs created in the current phase.  This would be done after finishing a test that included a migrate.
17: List running tasks      List any running VMware tasks
```
Effectively the order of operations in a failover is the following:

1. The user logs into vCenter 
1. The user logs into AGM
1. The user imports the OnVault images into the local Backup Appliance 
1. The user sets the name of the CSV

Then for each phase:

1. The user sets the phase 
1. The user starts the creation of the VMs in the current phase
1. The user validates the VMs are created
1. The user changes the network settings inside the VM if needed.
1. The user sets the network for the VMs in the current phase
1. The user validates the VMs are ready and the phase is complete

### Target Side next steps

Having run the mounts and created the VMs we have three scenarios:

1. We were doing a test and are finished.  We are not testing doing a migration of the VMs
  * Use option 15 to unmount the images
1. We are doing a test but are also testing storage migration to the VSAN
  * Use option 14 to migrate your VMs
  * Monitor the migrate with option 17
  * Confirm all migrates are complete with option 11 (the datastore should NOT show the NFS datastore for any migrated VM)
  * When you are finished, delete the VMs with option 16.  DO NOT run this until all migrates are complete or errors may occur (deletions during migrate can get stuck)
  * When the VMs are deleted, run option 15 to remove the mounts
  * In the AGM GUI, any VM that was migrated before being unmounted will show as an unmanaged VM. You will need to delete these.
1. This is permanent or semi-permanent
  * Use option 14 to migrate your VMs
  * Monitor the migrate with option 17
  * Confirm all migrates are complete with option 11
  * When the migrates are done and no VM depends on NFS datastore from backup appliance, run option 15 to remove the mounts
  * Use AGM import wizard to apply templates to any VMs you want to create backups from.   Do not protect a VM prior to migrating it or the snapshot pool may fill up.
 
 ## Other tasks that could be automated

 In the DR side there are two major tasks post DR:

 * Apply template/profile to each VM to start creating backups on the failover site. 
   * We need to consider how to determine which template to use
   * It is recommended that if you plan to migrate the VMs, that you do this before starting backups.
   * Note that a VM can be backed up using VMware snapshots without being migrated, but this generates the following issues:   
      * You may see high Backup Appliance CPU and network traffic as the data is being copied from the NFS datastore to ESX and then back to the Backup appliance.
      * If the Backup Appliance Mount is using the default performance option of **Balanced** then the first snapshot will cause the whole VM to be copied to the Backup Appliance snapshot pool.  If the client created a small snapshot pool this can lead to a pool full condition.
      * During the VMware snapshot, the VM disk files are reported as being on the VSAN, but once the snapshot is completed they report as being on the NFS datastore.  This is just a display bug, but is confusing.
   * Run VMware migration (Storage vMotion) to move the data off the Backup Appliance presented NFS datastore onto the client side datastores.
   * We need to consider pacing of the migrations.  On a e2-standard8 migrating just one VM showed 50% CPU on the backup appliance with network throughput of 250 MBps so it is recommended more CPUs be allocated.  An e2-standard16 is the recommened GCE Instance size for the Sky Appliance since it gives you the highest performance.
   * The script at present offers serial and parallel migration.

   ## Backing up your new VMs
   After migrating your VMs to the target datastore, then you can apply policy templates to begin local backups.
   Local backups can be configured through AGM by either:
   * Adding the new VMs to a logical group and protecting that group
   * Using the New Application wizard to protect all unmanaged VMs 
