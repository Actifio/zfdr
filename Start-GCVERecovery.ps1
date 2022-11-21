# Copyright 2022 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


function Start-GCVERecovery ([string]$filename,[int]$phase)
{
    #Requires -Version 7
    <#
    .SYNOPSIS
   Guided menu for DR failover to GCVE using Google Cloud Backup and DR 

    .EXAMPLE
    Start-GCVERecovery
    Runs a guided menu 

    .EXAMPLE
    Start-GCVERecovery -filename recoveryplan.csv -phase 2
    
    Runs a guided menu where the reocvery CSV file is called recoveryplan.csv and the phase that will be run is phase 2.
    

    .DESCRIPTION
    A function to help users find the right commands to run
    #>

   #

   # if the used doesn't specify a phase, assumes its 1.   This may be a mistake and we may need to change this to asking them.
   if (!($phase))
   {
       [int]$phase = 1
   }
   
   # this function gives a prompted login to the Backup Management Console and then returns to the GCVE menu
    function loginagm
    {  
         Connect-AGM
         gcveactions
    }

    # this function gives a prompted login to the vCenter and then returns to the GCVE menu
    function logingcve
    {
        Connect-VIServer
        gcveactions
    }

    # this function exports the policy templatess from the side side Backup Management Console.   This lets us import them into a DR site console
    function exportagmslts
    {
        Clear-Host
        Write-Host "Export AGM SLTs"  
        Write-Host ""
        Write-Host "The function you need to run is:   Export-AGMLibSLT"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Export-AGMLibSLT
            Read-Host -Prompt "Press enter to continue"
            sourcesideactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            sourcesideactions
        }
        else 
        {
            return    
        }
    }

    # this function imports the policy templatess that were exported from the side side Backup Management Console.   
    function importagmslts
    {
        Clear-Host
        Write-Host "Import AGM SLTs"  
        Write-Host ""
        Write-Host "The function you need to run is:   Import-AGMLibSLT"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Import-AGMLibSLT
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcveactions
        }
        else 
        {
            return    
        }
    }

    # this function lets the user change the phase, which will determine which VMs in the CSV get used
    function setphase
    {
        Clear-Host
        Write-Host "Phase is currently set to:  $phase"
        Write-Host ""
        Write-Host "1`: Increment phase by 1 (default)"
        Write-Host "2`: Let me set the phase"
        Write-Host "3`: Let me back "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            $phase = $phase + 1
            gcveactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            [int]$phase = Read-Host "What phase do you want to set this to (current phase is $phase)?"
            gcveactions
        }
        else 
        {
            gcveactions    
        }
    }

    # this function lets the user specify which CSV file to use if one was not specified when we started the main function.   We display the file after verifying it exists
    function setfilename
    {
        if ($filename)
        {
            Write-Host "The current filename is $filename"
            $newfilename = Read-Host "Please supply a new csv filename or press enter to display the current one"
        }
        else {
            $newfilename = Read-Host "Please supply a csv file correctly formatted as per the help for this function using: -filename xxxx.csv"
        }
        if ($newfilename -eq "")
        {
            $newfilename = $filename
        }
        if ( Test-Path $newfilename )
         {
            $filename = $newfilename 
            $recoverylist = Import-Csv -Path $filename
            # if we dont have a phase or sourcevmname column then this file is not formatted correctly and we should not proceed.   May need to add checks for other columns, but these two are key.
            if (!($recoverylist.phase)) { Read-Host -Prompt "Could not find the phase column in the CSV file, which is mandatory.  Press enter to continue"; gcveactions }
            if (!($recoverylist.sourcevmname)) { Read-Host -Prompt "Could not find the sourcevmname column in the CSV file, which is mandatory Press enter to continue"; gcveactions }
            # let the user see the imported file
            $recoverylist| Format-Table 
             Read-Host -Prompt "Press enter to continue"
             gcveactions
         }
         else 
         {
             Write-Host "Could not find the file $filename"
             Read-Host -Prompt "Press enter to continue"
             gcveactions
         }
    }

    # this function imports OnVault images into the recovery side Backup Appliance, presumably created by the source side backup appliance
    function importonvaultimages
    {
        Clear-Host
        Write-Host "Import OnVault Images"
        Write-Host ""
        Write-Host "The function you need to run is:   Import-AGMLibOnVault"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Import-AGMLibOnVault
            gcveactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcveactions
        }
        else 
        {
            return    
        }
    }

    function exportdrsidevmwareconfig
    {
        $filename = Read-Host "Please supply a name for the output csv file (xxxx.csv)"
        if ( Test-Path $filename )
        {
            Read-Host -Prompt "That file name already exists"
            sourcesideactions
        }
        else 
        {
            #  sourcevmname,sourcepowerstate,sourcenicname,sourcenetworkname,sourceconnectionstate,sourcemacaddress,sourceipaddress
            $hostgrab = Get-AGMHost -filtervalue "vmtype=vmware&shadow=true" -sort hostname:asc
            if ($hostgrab.id.count -eq 0 )
            {
                write-host ""
                Read-Host -Prompt "No imported VMware type hosts were found.  Run an import first"
                write-host ""
                gcveactions
            }
            else
            {
            $hostgrab | Select-Object @{N="sourcevmname";E={$_.hostname}},sourcepowerstate,sourcenicname,@{N="sourcenetworkname";E={$_.NetworkName}},@{N="sourceconnectionstate";E={$_.ConnectionState}},@{N="sourcemacaddress";E={$_.MacAddress}},@{N=”sourceipaddress”;E={@($_.ipaddress)}},phase,targetvmname,label,targetnetworkname,poweronvm,targetmacaddress | Export-Csv -path $filename
            }
            write-host ""
            write-host $hostgrab.id.count "VMs were found and exported to file: $filename"
            Read-Host -Prompt "You will need to update this file before moving to the next step"
            write-host ""
        }
        gcveactions
    }

    function listimportedimages
    {
        if (!($filename))
        {
            $filename = Read-Host "Please supply a csv file correctly formatted using: -filename xxxx.csv"
        }
        if ( Test-Path $filename )
        {
            # now we enable the interfaces in the desired interface 
            $recoverylist = Import-Csv -Path $filename
            # if we dont have a phase or sourcevmname column then this file is not formatted correctly and we should not proceed.   May need to add checks for other columns, but these two are key.
            if (!($recoverylist.phase)) { Read-Host -Prompt "Could not find the phase column in the CSV file, which is mandatory.  Press enter to continue"; gcveactions }
            if (!($recoverylist.sourcevmname)) { Read-Host -Prompt "Could not find the sourcevmname column in the CSV file, which is mandatory Press enter to continue"; gcveactions }
            $AGMArray = @()
            foreach ($app in $recoverylist)
            {
                if ($app.phase -eq $phase)
                {
                    $sourcevmname = $app.sourcevmname
                    $imagegrab = get-agmimage -filtervalue "appname=$sourcevmname&jobclass=OnVault" -limit 1 -sort consistencydate:desc 
                    $condate = $imagegrab.consistencydate
                    write-host "Collected image date for $sourcevmname"
                    $AGMArray += [pscustomobject]@{
                        vmname = $sourcevmname
                        consistencydate = $condate
                    }
                }
            }
            Clear-Host
            $AGMArray | Format-Table
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
        else 
        {
            Write-Host "Could not find the file $filename"
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
    }


    # this function runs through the filename and creates new VMs for each listed VM in the current phase.  It relies on a function in AGMPowerLIB added in release 0.0.0.40
    function createnewvms
    {
        if (!($filename))
        {
            $filename = Read-Host "Please supply a csv file correctly formatted using: -filename xxxx.csv"
        }
        if ( Test-Path $filename )
        {
            # if we dont have a phase or sourcevmname column then this file is not formatted correctly and we should not proceed.   May need to add checks for other columns, but these two are key.
            $recoverylist = Import-Csv -Path $filename
            if (!($recoverylist.phase)) { Read-Host -Prompt "Could not find the phase column in the CSV file, which is mandatory.  Press enter to continue"; gcveactions }
            if (!($recoverylist.sourcevmname)) { Read-Host -Prompt "Could not find the sourcevmname column in the CSV file, which is mandatory Press enter to continue"; gcveactions }
            New-AGMLibGCVEfailover -filename $filename -phase $phase
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
        else 
        {
            Write-Host "Could not find the file $filename"
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
    }

    # this function lists all mounts on the Backup appliance.  
   function listmounts
   {
        Clear-Host
        Write-Host "List your mounts"
        Write-Host ""
        Write-Host "The function you need to run is:   Get-AGMLibActiveImage"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Get-AGMLibActiveImage | Select-Object id,imagename,apptype,appliancename,hostname,appname,mountedhost,consumedsize_gib,label,imagestate | Format-Table
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcveactions
        }
        else 
        {
            return    
        }
   }

   # this function monitors any running mount jobs on the backup appliance.
   function  monitorjobs

   {
        Clear-Host
        Write-Host "Monitor running jobs"
        Write-Host ""
        Write-Host "To monitor all jobs, the function you need to run is:    Get-AGMLibRunningJobs -m"
        Write-Host "To monitor mounts, the function you need to run is:    Get-AGMLibRunningJobs -jobclass mount -m"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Get-AGMLibRunningJobs -m
            gcveactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcveactions
        }
        else 
        {
            return    
        }
   }


   # this function unmounts the VMs from the backup appliance.   This is a cleanup funtion.   If the CSV file has labels, it makes this job much easier.

   function unmountyourimages
   {  
        Clear-Host
        Write-Host "Unmount your images"
        Write-Host ""
        Write-Host "The function you need to run is:   Remove-AGMLibMount"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Remove-AGMLibMount
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcveactions
        }
        else 
        {
            return    
        }
   }    

# this function lists all the VMware VMs.   I am poncdering whether to list only the VMs in the current phase.
   function listvmwarevms
   {
        Get-VM | Get-NetworkAdapter | Select-Object @{N="VM";E={$_.Parent.Name}},@{N="Power";E={$_.Parent.PowerState}},@{N="NIC";E={$_.Name}},@{N="Network";E={$_.NetworkName}},@{N="Connected";E={$_.ConnectionState}},@{N="MacAddress";E={$_.MacAddress}},@{N=”IP Address”;E={@($_.Parent.guest.IPAddress[0])}},@{N="Datastore";E={[string]::Join(',',(Get-Datastore -Id $_.Parent.DatastoreIdList | Select-Object -ExpandProperty Name))}} | Format-Table
        Read-Host -Prompt "Press enter to continue"
        gcveactions
   }

   function listphasevmwarevms
   {
        if (!($filename))
        {
            $filename = Read-Host "Please supply a csv file correctly formatted using: -filename xxxx.csv"
        }
        if ( Test-Path $filename )
        {
            # now we enable the interfaces in the desired interface 
            $recoverylist = Import-Csv -Path $filename
            $phasevmlist = ($recoverylist | where-object {$_.phase -eq $phase}).targetvmname
            Get-VM |  Where-object {$_.name -in $phasevmlist} | Get-NetworkAdapter | Select-Object @{N="VM";E={$_.Parent.Name}},@{N="Power";E={$_.Parent.PowerState}},@{N="NIC";E={$_.Name}},@{N="Network";E={$_.NetworkName}},@{N="Connected";E={$_.ConnectionState}},@{N="MacAddress";E={$_.MacAddress}},@{N=”IP Address”;E={@($_.Parent.guest.IPAddress[0])}},@{N="Datastore";E={[string]::Join(',',(Get-Datastore -Id $_.Parent.DatastoreIdList | Select-Object -ExpandProperty Name))}} | Format-Table
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
        else 
        {
            Write-Host "Could not find the file $filename"
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
   }


    # this function lists all the VMware VMs.   This is for the source side so thats where it returns to
   function listsourcevmwarevms
   {
        Get-VM | Get-NetworkAdapter | Select-Object @{N="VM";E={$_.Parent.Name}},@{N="Power";E={$_.Parent.PowerState}},@{N="NIC";E={$_.Name}},@{N="Network";E={$_.NetworkName}},@{N="Connected";E={$_.ConnectionState}},@{N="MacAddress";E={$_.MacAddress}},@{N=”IP Address”;E={@($_.Parent.guest.IPAddress[0])}} | Format-Table
        Read-Host -Prompt "Press enter to continue"
        sourcesideactions
   }

   # this function is used to create a starter CSV file on the source side
   function exportvmwareconfig
   {
        $filename = Read-Host "Please supply a name for the output csv file (xxxx.csv)"
        if ( Test-Path $filename )
        {
            Read-Host -Prompt "That file name already exists"
            sourcesideactions
        }
        else 
        {
            #  sourcevmname,sourcepowerstate,sourcenicname,sourcenetworkname,sourceconnectionstate,sourcemacaddress,sourceipaddress
            Get-VM | Get-NetworkAdapter | Select-Object @{N="sourcevmname";E={$_.Parent.Name}},@{N="sourcepowerstate";E={$_.Parent.PowerState}},@{N="sourcenicname";E={$_.Name}},@{N="sourcenetworkname";E={$_.NetworkName}},@{N="sourceconnectionstate";E={$_.ConnectionState}},@{N="sourcemacaddress";E={$_.MacAddress}},@{N=”sourceipaddress”;E={@($_.Parent.guest.IPAddress[0])}},phase,targetvmname,label,targetnetworkname,poweronvm,targetmacaddress | Export-Csv -path $filename
        }
        sourcesideactions
   }

    # this function is used to create a starter CSV file on the source side
    function updatevmwareconfig
    {
        $infile = Read-Host "Please supply the name an existing csv file that that was exported previously. This file will not be changed"
        if ( Test-Path $infile )
        {
            #  sourcevmname,sourcepowerstate,sourcenicname,sourcenetworkname,sourceconnectionstate,sourcemacaddress,sourceipaddress
            $importedvms =  Import-Csv -path $infile
            # if we cannot find the first columnm this is probably not a valid source file
            if ($importedvms.sourcevmname -eq $null) 
            { 
                Read-Host -Prompt "The specified file does not appear contain valid data to be a source file. Press enter to continue"
                sourcesideactions
            }
        }
        else 
        {
            Read-Host -Prompt "Could not open the specified file $infile. Please check it exists. Press enter to continue"
            sourcesideactions
        } 
        $outfile = Read-Host "Please supply the name for a new output csv file (xxxx.csv) that will be created"
        # we need an unused output file name
        if ( Test-Path $outfile )
        {            
        Read-Host -Prompt "The output file name $outfile already exists.  Please specify a file name that is unused. Press enter to continue"
        sourcesideactions
        }
        write-host "Fetching VM details, this may take some time"
        $foundvms = Get-VM | Get-NetworkAdapter | Select-Object @{N="sourcevmname";E={$_.Parent.Name}},@{N="sourcepowerstate";E={$_.Parent.PowerState}},@{N="sourcenicname";E={$_.Name}},@{N="sourcenetworkname";E={$_.NetworkName}},@{N="sourceconnectionstate";E={$_.ConnectionState}},@{N="sourcemacaddress";E={$_.MacAddress}},@{N="sourceipaddress";E={@($_.Parent.guest.IPAddress[0])}},phase,targetvmname,label,targetnetworkname,poweronvm,targetmacaddress
        foreach ($vm in $foundvms)
        {
            $vmpeek = $importedvms | where-object {($_.sourcevmname -eq $vm.sourcevmname)}
            if ($vmpeek)
            {
                # write-host "Found existing VM: " $vm.sourcevmname
            }
            else 
            {
                write-host "Found new VM to add to the recovery plan: " $vm.sourcevmname
                $importedvms += [pscustomobject]@{
                    sourcevmname = $vm.sourcevmname
                    sourcepowerstate = $vm.sourcepowerstate
                    sourcenicname = $vm.sourcenicname
                    sourcenetworkname = $vm.sourcenetworkname
                    sourceconnectionstate = $vm.sourceconnectionstate
                    sourcemacaddress = $vm.sourcemacaddress
                    sourceipaddress = $vm.sourceipaddress
                }
            }
        }
        $importedvms | Export-Csv -path $outfile
        Read-Host -Prompt "Wrote to new output file: $outfile    Press enter to continue"
        sourcesideactions 
    }

   # this function is used to setup networking for our new VMs.   
   function configurevmwarevms
   {
        if (!($filename))
        {
            $filename = Read-Host "Please supply a csv file correctly formatted using: -filename xxxx.csv"
        }
        if ( Test-Path $filename )
        {
            # now we enable the interfaces in the desired interface 
            $recoverylist = Import-Csv -Path $filename
            # if we dont have a phase or sourcevmname column then this file is not formatted correctly and we should not proceed.   May need to add checks for other columns, but these two are key.
            if (!($recoverylist.phase)) { Read-Host -Prompt "Could not find the phase column in the CSV file, which is mandatory.  Press enter to continue"; gcveactions }
            if (!($recoverylist.sourcevmname)) { Read-Host -Prompt "Could not find the sourcevmname column in the CSV file, which is mandatory Press enter to continue"; gcveactions }
            foreach ($app in $recoverylist)
            {
                if ($app.phase -eq $phase)
                {
                    #if there is no network name specified, then wherever it got put is where it is staying put where it was created
                    if ($app.targetvmname.length -gt 0)
                    {
                        $mountvmname = $app.targetvmname
                    }
                    else {
                        $mountvmname = $app.sourcevmname
                    }
                    if ($app.targetnetworkname.length -gt 0)
                    {      
                        write-host "Enabling " $mountvmname "in network " $app.targetnetworkname
                        # if a MAC address was specified we set it and power the VM on.
                        if ($app.targetmacaddress.length -gt 0)
                        {
                            Get-VM $mountvmname  | Get-NetworkAdapter | Set-NetworkAdapter -MacAddress $app.targetmacaddress -Confirm:$false
                            Start-VM -VM $mountvmname
                        }
                        # Note that if the VM is not powered on, this command will fail
                        Get-VM $mountvmname  | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $app.targetnetworkname -Connected:$true -StartConnected:$true -Confirm:$false
                        Get-VM $mountvmname | Get-NetworkAdapter | Select-Object @{N="VM";E={$_.Parent.Name}},@{N="NIC";E={$_.Name}},@{N="Network";E={$_.NetworkName}},@{N="Connected";E={$_.ConnectionState}}
                    }
                    else 
                    {
                        write-host "Enabling " $mountvmname "in its current network"
                        # if a MAC address was specified we set it and power the VM on.
                        if ($app.targetmacaddress.length -gt 0)
                        {
                            Get-VM $mountvmname  | Get-NetworkAdapter | Set-NetworkAdapter -MacAddress $app.targetmacaddress
                            Start-VM -VM $mountvmname
                        }
                        # Note that if the VM is not powered on, this command will fail
                        Get-VM $mountvmname  | Get-NetworkAdapter | Set-NetworkAdapter -Connected:$true -StartConnected:$true -Confirm:$false
                        Get-VM $mountvmname | Get-NetworkAdapter | Select-Object @{N="VM";E={$_.Parent.Name}},@{N="NIC";E={$_.Name}},@{N="Network";E={$_.NetworkName}},@{N="Connected";E={$_.ConnectionState}}    
                    }
                }
            }
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
        else 
        {
            Write-Host "Could not find the file $filename"
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
   }

   function migratevms
   {
        if (!($filename))
        {
            $filename = Read-Host "Please supply a csv file correctly formatted using: -filename xxxx.csv"
        }
        if ( Test-Path $filename )
        {
            # now we migrate the VMs
            $recoverylist = Import-Csv -Path $filename
            # if we dont have a phase or sourcevmname column then this file is not formatted correctly and we should not proceed.   May need to add checks for other columns, but these two are key.
            if (!($recoverylist.phase)) { Read-Host -Prompt "Could not find the phase column in the CSV file, which is mandatory.  Press enter to continue"; gcveactions }
            if (!($recoverylist.sourcevmname)) { Read-Host -Prompt "Could not find the sourcevmname column in the CSV file, which is mandatory Press enter to continue"; gcveactions }
            $targetds = (Get-Datastore  | Sort-Object -Property FreespaceGB -Descending:$true | Select-Object -First 1).name
            Clear-Host
            Write-Host "VM migration menu"
            write-host ""
            write-host "The most empty datastore will be used.  It is currently: $targetds"
            Write-Host ""
            Write-Host "1`: Migrate one VM in the current phase at a time sequentially (default)"
            Write-Host "2`: Migrate all the VMs in the current phase in parallel"
            Write-Host "3`: Back up, I am not sure which choice to make"
            [int]$userselectionm = Read-Host "Please select from this list [1-3]"
            if ($userselectionm -eq 1 -or $userselectionm -eq "")
            {
                $asyncmigrate = $false
            } 
            if ($userselectionm -eq 2)
            {
                $asyncmigrate = $true
            } 
            if ($userselectionm -eq 3)
            {
                gcveactions
            }
            foreach ($app in $recoverylist)
            {
                if ($app.phase -eq $phase)
                {
                    if ($app.targetvmname.length -gt 0)
                    {
                        $mountvmname = $app.targetvmname
                    }
                    else {
                        $mountvmname = $app.sourcevmname
                    }
                    write-host "Migrating " $mountvmname "to the VSAN datastore"
                    if ($asyncmigrate -eq $true) { Move-VM -VM $mountvmname -Datastore $targetds -RunAsync }     
                    if ($asyncmigrate -eq $false) { Move-VM -VM $mountvmname -Datastore $targetds }        
                }
            }
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
        else 
        {
            Write-Host "Could not find the file $filename"
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
   }

   
   function deletevms
   {
        Clear-Host
        Write-Host "VM DELETION menu"
        write-host ""
        write-host "This options is DESTRUCTIVE.  It will delete VMs!"
        write-host "Use this option after you have done a test failover AND after you migrated the VMs to your datastores."
        Write-Host "If you didn't do a migrate (option 14), then just use option 15, to unmount your VMs.  This will remove them from VMware and from the Backup Appliance"
        Write-Host ""
        Write-Host "1`: Return to the main menu (default)"
        Write-Host "2`: I did not use option 14 so let me use option 15 to unmount the VMs"
        Write-Host "3`: I migrated the VMs and now I want to delete them"
        [int]$userselectionm = Read-Host "Please select from this list [1-3]"
        if ($userselectionm -eq 1 -or $userselectionm -eq "" -or $userselectionm -gt 3)
        {
            gcveactions
        } 
        if ($userselectionm -eq 2)
        {
            unmountyourimages
        } 
        if (!($filename))
        {
            $filename = Read-Host "Please supply a csv file correctly formatted using: -filename xxxx.csv"
        }
        if ( Test-Path $filename )
        {
            # now we migrate the VMs
            $recoverylist = Import-Csv -Path $filename
            # if we dont have a phase or sourcevmname column then this file is not formatted correctly and we should not proceed.   May need to add checks for other columns, but these two are key.
            if (!($recoverylist.phase)) { Read-Host -Prompt "Could not find the phase column in the CSV file, which is mandatory.  Press enter to continue"; gcveactions }
            if (!($recoverylist.sourcevmname)) { Read-Host -Prompt "Could not find the sourcevmname column in the CSV file, which is mandatory Press enter to continue"; gcveactions }
            foreach ($app in $recoverylist)
            {
                if ($app.phase -eq $phase)
                {
                    if ($app.targetvmname.length -gt 0)
                    {
                        $mountvmname = $app.targetvmname
                    }
                    else {
                        $mountvmname = $app.sourcevmname
                    }
                    write-host "Powering off and deleting " $mountvmname 
                    Stop-VM -VM $mountvmname -Kill -Confirm:$false
                    Remove-VM -VM $mountvmname -DeletePermanently -Confirm:$false -RunAsync
                }
            }
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
        else 
        {
            Write-Host "Could not find the file $filename"
            Read-Host -Prompt "Press enter to continue"
            gcveactions
        }
   }

   function listvmwaretasks
   {
        do 
        {
            Clear-Host
            $tasks = Get-task -status Running
            $tasks | Format-Table
            write-host ""
            $n=10
            do
            {   
                # this lets the user break out
                if ([Console]::KeyAvailable)
                {
                    # read the key, and consume it so it won't
                    # be echoed to the console:
                    $keyInfo = [Console]::ReadKey($true)
                    # exit loop
                    return
                }
                # this counts down 10 to 1
                start-Sleep -s 1
                $n = $n-1
                Write-Host -NoNewLine "`rRefreshing in $n seconds (Press any key to exit)"
            } until ($n -eq 0)
            
        } while ($true)
   }



   # this function is basically where all the action is at.   The goal of the order is to be logically sequential.
   function gcveactions
   {  
        Write-Host ""
        Write-host "GCVE recovery menu. Current Phase is $phase"
        Write-Host ""
        Write-host "Note that if you have not connected to AGM yet with Connect-AGM, or vCenter then do this first before proceeding"
        Write-Host "What do you need to do?"
        Write-Host ""
        write-host " 1`: Login to AGM            Do you need to login to AGM with Connect-AGM?"
        write-host " 2`: Login to vCenter        Do you need to login to vCenter with Connect-VIServer?"
        write-host " 3`: Import AGM SLTs         Do you want to import Policy Templates from the source AGM?  Note you need to have a file of exported SLTs to do this"
        write-host " 4`: Import OnVault images   Do you want to import (or forget) the latest images from an OnVault pool so they can be used in the DR Site?"
        write-host " 5`: Create config file      Do you want to create a config file using the imported VMs, rather than use one created on the source side?"
        if ($filename) { write-host " 6`: Supply/Display filename Do you want to set or display your recovery file. Current file is: $filename" }
        if (!($filename)) { write-host " 6`: Supply filename         Do you want to set and display your recovery file. No file is currently set." }
        write-host " 7`: Set the phase           Do you want to set which phase it is.  Current phase is $phase"
        Write-Host " 8`: List OnVault images     Do you want to see the latest backup date for each VM in the current phase?"
        Write-Host " 9`: Create new VMs          Do you create a new set of VMs based on a phase number?"
        Write-Host "10`: Monitor running jobs    Do you want to monitor running jobs"
        Write-Host "11`: List your mounts        Do you want to list the current mounts"
        Write-Host "12`: List all VMware VMs     Do you want to list the VMs in VMware"
        Write-Host "13`: List new phase VMs      Do you want to list the VMs in VMware that were created in this phase"
        Write-Host "14`: Set VMware Networking   Do you want to configure VMware VM networking based on a phase number?"
        write-host "15`: Migrate VMs             Do you want to migrate the VMs in the current phase"
        Write-Host "16`: Unmount your images     Do you want to unmount the VMs we mounted?"
        write-host "17`: Delete VMs              Do you want to DELETE the VMs created in the current phase.  This would be done after finishing a test that included a migrate."
        write-host "18`: List running tasks      List any running VMware tasks"
        write-host "19`: Back                    Take me back to the previous menu"
        write-host "20`: Exit                    Take me back to the command line"
        Write-Host ""
        # ask the user to choose
        While ($true) 
        {
            Write-host ""
            $listmax = 20
            [int]$userselection2 = Read-Host "Please select from this list [1-$listmax]"
            if ($userselection2 -lt 1 -or $userselection2 -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
            } 
            else
            {
                break
            }
        }
        if ($userselection2 -eq 1) { loginagm }
        if ($userselection2 -eq 2) { logingcve }
        if ($userselection2 -eq 3) { importagmslts }  
        if ($userselection2 -eq 4) { importonvaultimages }
        if ($userselection2 -eq 5) { exportdrsidevmwareconfig }
        if ($userselection2 -eq 6) { setfilename }
        if ($userselection2 -eq 7) { setphase }
        if ($userselection2 -eq 8) { listimportedimages }
        if ($userselection2 -eq 9) { createnewvms }
        if ($userselection2 -eq 10) { monitorjobs }
        if ($userselection2 -eq 11) { listmounts }
        if ($userselection2 -eq 12) { listvmwarevms }
        if ($userselection2 -eq 13) { listphasevmwarevms }
        if ($userselection2 -eq 14) { configurevmwarevms }
        if ($userselection2 -eq 15) { migratevms } 
        if ($userselection2 -eq 16) { unmountyourimages }   
        if ($userselection2 -eq 17) { deletevms }
        if ($userselection2 -eq 18) { listvmwaretasks }
        if ($userselection2 -eq 19) { mainmenu }
        if ($userselection2 -eq 20) { return }

    }

    function sourcesideactions
    {  
         Write-Host ""
         Write-host "Source side setup menu"
         Write-Host ""
         Write-host "Note that if you have not connected to AGM yet with Connect-AGM, or vCenter then do this first before proceeding"
         Write-Host "What do you need to do?"
         Write-Host ""
         write-host " 1`: Login to AGM            Do you need to login to AGM with Connect-AGM?"
         write-host " 2`: Login to vCenter        Do you need to login to vCenter with Connect-VIServer?"
         write-host " 3`: Export AGM SLTs         Do you want to export your Policy Templates from AGM?"
         write-host " 4`: Display VMware Config   Do you want to display the config of your current VMs?"
         write-host " 5`: Export VMware Config    Do you want to export the config of your current VMs?"
         write-host " 6`: Update VMware Config    Do you want to update a previously exported config file to add any new VMs?"
         write-host " 7`: Back                    Take me back to the previous menu"
         write-host " 8`: Exit                    Take me back to the command line"
         Write-Host ""
         # ask the user to choose
         While ($true) 
         {
             Write-host ""
             $listmax = 8
             [int]$userselection2 = Read-Host "Please select from this list [1-$listmax]"
             if ($userselection2 -lt 1 -or $userselection2 -gt $listmax)
             {
                 Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
             } 
             else
             {
                 break
             }
         }
         if ($userselection2 -eq 1) { loginagm }
         if ($userselection2 -eq 2) { logingcve }
         if ($userselection2 -eq 3) { exportagmslts } 
         if ($userselection2 -eq 4) { listsourcevmwarevms } 
         if ($userselection2 -eq 5) { exportvmwareconfig } 
         if ($userselection2 -eq 6) { updatevmwareconfig } 
         if ($userselection2 -eq 7) { mainmenu }
         if ($userselection2 -eq 8) { break }
 
     }

    function mainmenu
    {
        Import-module agmpowerlib
        $agmsessiontest = Get-AGMVersion

        
        clear-host
        Write-Host "This function is designed to help you learn which functions to run before or during a DR event into GCVE."
        Write-Host ""
        Write-host "We are either running this from the Production site or the DR Site."
        Write-Host "Which site are you working with?"
        Write-Host ""
        write-host "1`: Production Site"
        Write-Host "2`: DR Site"
        Write-Host "3`: Exit"
        if ($agmsessiontest.errormessage)
        {
            Write-Host ""
            Write-Host "**** NOTE!   You are not logged into AGM, so please do that first ****"
        }
        $serverlist = $global:DefaultVIServer
        if($null -eq $serverlist) 
        {
            Write-Host "**** NOTE!   You are not logged into vCenter, so please do that first ****"
        }
        while ($true) 
        {
            Write-host ""
            $listmax = 3
            [int]$siteselection = Read-Host "Please select from this list [1-$listmax]"
            if ($siteselection -lt 1 -or $siteselection -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
            } 
            else
            {
                break
            }
        }
        if ($siteselection -eq 1) { sourcesideactions } 
        if ($siteselection -eq 2) { gcveactions }
        if ($siteselection -eq 3) { break }
    }
    mainmenu
}
