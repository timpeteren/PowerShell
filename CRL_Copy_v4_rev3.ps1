# 
# Title: CRL_Copy_v4.ps1 
# Date: 7/18/2017 
# Author: Paul Fox (MCS) 
# Copyright Microsoft Corporation @2017 
# 
# Description: This script monitors the remaining lifetime of a CRL, publishes a CRL to a UNC and\or NTFS location and sends notifications via SMTP and EventLog. 
# There are two input arguments: 
# "Monitor" - checks the "master" CRL and the CRL in CDP locations. If the NextUpdate time is within "threshold" an alert will be sent. 
# "Publish" - checks the status of the master CRL and copies the Master CRL to identified CDP locations if the CRL numbers do not match 
# Master CRL and CDP push location must be file system paths (UNC and\or NTFS). The script validates that push was successful by comparing the hash 
# values of the Master and CDP CRLs. Credentials can be stored for authenticating to non-domain UNC shares. Set credentials with the set-credential.ps1 script and adjust line #486 accordingly 
# Settings are configured within the crl_config.xml file. 
# 
# Debugging: 1) $debugpreference = "continue" at the powershell command prompt for detailed output of the script 
# 2) uncomment line #27 to enable powershell transcript logging. Helpful for troubleshooting scheduled tasks 
# 
# Thank you to everyone for your code contributions and ideas. For a detailed explaination of this script please go to: https://gallery.technet.microsoft.com/scriptcenter/Powershell-CRL-Copy-v4-11554ea5 
# 
# 21/8/2019
# Modified: Added conversion for crl numbers to make sure they are in hexadecimal format when the master (published) crl and (local) issuing CA crl are compared
# If run within the task scheduler using the "Publish" method the process no longer requires local administrator permissions. 
#
# 12.04.2021
# Removed script dependency "Get-Credential" (line 479-ish $Cred = ./get-credential.ps1 $cdp.push_username $cdp.push_passwordfile)
#
# IMPORTANT! 
# The service account running the scheduled task is given the right to "Logon as a batch job", via central or local group policy configuration.
#
param ($arg1, [switch]$disablenet = $false, [string]$conf = ".\crl_config.xml") 
# 
# Powershell transcripts: uncomment the following command to enable logging of this script. This is helpful when the script runs as a scheduled task 
# start-transcript -path "c:\temp\transcript.txt" 
if (!$arg1 -or (($arg1 -ne "publish") -and ($arg1 -ne "monitor"))) { 
    write-host "Usage: ./crl_copy_v4.ps1 publish|monitor [-disablenet] [-conf <ConfigFile>]" 
    write-host "" 
    write-host "the disablenet switch is an option that controls whether we disable the network interface when the script is done." 
    write-host "" 
    write-host "" 
    write-host "Example: to publish CRL to CDP locations specified in crl_config.xml" 
    write-host "./crl_copy_v4.ps1 publish" 
    write-host "" 
    write-host "Example: to compare the `"master`" CRL to published CRLs in the CDP locations specified in crl_config.xml" 
    write-host "./crl_copy_v4.ps1 monitor" 
    write-host "" 
    write-host "Example: to publish CRL to CDP locations specified in crl_config_1.xml (diffrent configuration file)" 
    write-host "./crl_copy_v4.ps1 publish -conf `"c:\crl_publish\crl_config_1.xml`"" 
    write-host "Default Configuration file is read from: ./crl_config.xml" 
    write-host "" 
    exit 
} 
# 
# Function: Results 
# Description: Writes the $evtlog_string to the Application eventlog and sends 
# SMTP message to recipients if $SMTP = [bool]$true and $EventLevel <= SMTPThreshold 
# 
function results([string]$evt_string, [string]$evtlog_string, [int]$level, [string]$title, [bool]$sendsmtp, [string]$from, [array]$to, [string]$SmtpServer, [string]$SMTPThreshold, [bool]$published) { 
    write-debug "******** Inside results function ********" 
    write-debug "SMTP = $sendsmtp" 
    write-debug "EventLevel: $level" 
    write-debug "SMTP threshold: $SMTPThreshold" 
    write-debug "Published Notification: $published" 
    # if eventlog does not exist create it (must run script as local administrator once to create) 
    if (![system.diagnostics.eventlog]::sourceExists($EventSource)) { 
        $evtlog = [system.diagnostics.eventlog]::CreateEventSource($EventSource, "Application") 
    } 
    # set eventlog object 
    $evtlog = new-object system.diagnostics.eventlog("application", ".") 
    $evtlog.source = $EventSource 
    # write to eventlog 
    $evtlog.writeEntry($evtlog_string, $level, $EventID) 
    # send email if sendsmtp = TRUE and event level <= SMTPThreshold or Notify on Publish 
    if ($sendsmtp -and (($level -le $SMTPThreshold) -or $published)) { 
        write-debug "Sending SMTP" 
        if ($level -eq $EventHigh) { 
            $SMTPPriority = "High" 
        } 
        else { 
            $SMTPPriority = "Normal" 
        } 
        $messageParameters = @{ 
            Subject    = $title 
            From       = $from 
            To         = $to 
            SmtpServer = $SmtpServer 
            Body       = $evt_string | Out-String 
            Priority   = $SMTPPriority 
        } 
        Send-mailMessage @messageParameters -BodyAsHtml 
    } 
    else { 
        write-debug "SMTP message not sent" 
    } 
    if ($tmp_outfile) { 
        foreach ($file in $tmp_outfile) { 
            $debug_out = "Outputing to: " + $file 
            write-debug $debug_out 
            $evt_string | Out-File $file 
        } 
    } 
    else { 
        write-debug "No output files specified" 
    } 
} # end results function 
# 
# Function: retrieve 
# Description: Pulls the CRL based upon method 
# Thanks to Matt Ernst and Russell Tomkins (https://msdnshared.blob.core.windows.net/media/2016/04/CRLFreshCheck.psm1_.txt) for moving this section of the code to the native .Net. 
# 
function retrieve([string]$name, [string]$method, [string]$path) { 
    $RAWCRL = New-Object -ComObject "X509Enrollment.CX509CertificateRevocationList" 
    $debug_out = "Function: pulling CRL: " + $name + " Method: " + $method + " Path: " + $path 
    write-debug $debug_out 
    switch ($method) { 
        "file" { 
            $path = $path + $name 
            $RAWCRL = $null 
            $RAWCRL = [Convert]::ToBase64String(($RAWCRL = Get-Content $path -Encoding Byte)) 
        } 
        "ldap" { 
            $RAWCRL = $null 
            $CRLNumber = 0 
            $i = 0 
            $found = [bool]$FALSE 
            $tmp = $name.split(".") 
            $name = $tmp[0] 
            $domain = "LDAP://cn=cdp,cn=public key services,cn=services,cn=configuration," + $path 
            $root = New-Object System.DirectoryServices.DirectoryEntry($domain) 
            $query = New-Object System.DirectoryServices.DirectorySearcher($root) 
            $strFilter = "(&(objectclass=cRLDistributionPoint)(cn=$name))" 
            $query.Filter = $strFilter 
            $query.SearchScope = "subtree" 
            $query.PageSize = 1000 
            $results = $query.FindAll() 
            $debug_out = "LDAP: found " + $results.count + " CRLs" 
            write-debug $debug_out 
            if ($results.count -gt 0) { 
                # sometimes there might be multiple CRLs in the LDAP location 
                # find the highest CRL number and return that one 
                foreach ($ldapcrl in $results) { 
                    if ($ldapcrl.Properties.certificaterevocationlist) { 
                        $RAWCRL = $null 
                        $RAWCRL = [Convert]::ToBase64String($ldapcrl.Properties["certificaterevocationlist"][0]) 
                        $CRL = New-Object -ComObject "X509Enrollment.CX509CertificateRevocationList" 
                        $CRL.InitializeDecode($RAWCRL, 1) 
                        $CRLnumberTMP = $CRL.CRLNumber() 
                        if ($CRLnumberTMP -ge $CRLNumber) { 
                            $CRLNumber = $CRLnumberTMP 
                            $result_num = $i 
                            $found = [bool]$TRUE 
                        } 
                        $i++ 
                    } 
                } #end foreach 
            } # if results > 0 
            else { 
                write-debug "No LDAP CRL found" 
            } 
            if ($found) { 
                $RAWCRL = $null 
                $RAWCRL = [Convert]::ToBase64String($results[$result_num].Properties["certificaterevocationlist"][0]) 
            } 
            else { 
                write-debug "No CRL found in LDAP that had a CRL # > 0" 
            } 
        } #end LDAP switch 
        "www" { 
            $RAWCRL = $null 
            $HostHeader = ([URI]$path).Host 
            Try { 
                $TempFile = [IO.Path]::GetTempFileName() 
                $crl_url = $path + $name 
                Invoke-WebRequest $crl_url -Headers @{Host = $HostHeader } -OutFile $TempFile 
                $RAWCRL = [Convert]::ToBase64String((Get-Content $TempFile -Encoding Byte)) 
                Remove-Item $TempFile 
            } 
            Catch { 
                write-host "Unable to connect to WWW location $path" 
            } 
        } #end www switch 
        default { 
            write-host "Unable to determine CRL pull method, must be `"www`", `"ldap`" or `"file`" " 
            $evtlog_string = "Unable to determine CRL pull method, must be `"www`", `"ldap`" or `"file`" " + $newline 
            $evt_string = $evt_string + "Unable to determine CRL pull method, must be `"www`", `"ldap`" or `"file`" " + $newline 
        } 
    } #end of switch 
    # 
    # Process the CRL 
    # 
    $CRL = New-Object -ComObject "X509Enrollment.CX509CertificateRevocationList" 
    $CRL.InitializeDecode($RAWCRL, 1) 
    $CRL | 
    Add-Member @{'NextCRLPublish' = try { [datetime]::ParseExact([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($($CRL.X509Extensions).where( { $_.ObjectID.Value -eq '1.3.6.1.4.1.311.21.4' }).RawData("1"))).substring(2), 'yyMMddHHmmss\Z', $null) }Catch { } } -PassThru | 
    Add-Member @{'FreshestCRL' = try { ([regex]::Matches([text.encoding]::ASCII.GetString([convert]::FromBase64String($($crl.X509Extensions).where( { $_.ObjectId.Value -eq '2.5.29.46' }).RawData('1'))), '(https?:\/\/.+?\.crl)').groups.value | select -Unique) }catch { } } -PassThru | 
    Add-Member @{'PublishedCRLLocations' = try { ([regex]::Matches([text.encoding]::ASCII.GetString([convert]::FromBase64String($($crl.X509Extensions).where( { $_.ObjectId.Value -eq '1.3.6.1.4.1.311.21.14' }).RawData('1'))), '(https?:\/\/.+?\.crl)').groups.value | select -Unique) }catch { } } -PassThru | 
    # 
    # Check for delta CRL information in the CRL 
    # 
    ForEach { 
        $ThisCRL = $_ 
        If ($($ThisCRL.X509Extensions).where( { $_.ObjectID.Value -eq '2.5.29.27' })) {
            $_ | Add-Member @{'DeltaCRLIndicator' = try { $($ThisCRL.X509Extensions).where( { $_.ObjectID.Value -eq '2.5.29.27' }).rawdata('4').replace(' ', '').substring(4) }catch { } }
        }
        else { Write-Debug "No delta CRL" } 
    } 
    $debug_out = "Pulled CRL CRLNumber: " + $crl.CRLNumber() + $newline 
    $debug_out = $debug_out + "Pulled CRL IssuerName: " + $crl.Issuer.Name + $newline 
    $debug_out = $debug_out + "Pulled CRL ThisUpdate: " + $crl.ThisUpdate.ToLocalTime() + $newline 
    $debug_out = $debug_out + "Pulled CRL NextUpdate: " + $crl.NextUpdate.ToLocalTime() + $newline 
    $debug_out = $debug_out + "Pulled CRL NextCRLPublish: " + $crl.NextCRLPublish.ToLocalTime() + $newline 
    write-debug $debug_out 
    return $crl 
} # end of function retrieve 
# 
# MAIN 
# 
# Variables 
# 
[xml]$xmlconfigfile = get-content $conf 
$master_name = $xmlconfigfile.configuration.master_crl.name 
$master_retrieval = $xmlconfigfile.configuration.master_crl.retrieval 
$master_path = $xmlconfigfile.configuration.master_crl.path 
$cdps = $xmlconfigfile.configuration.cdps.cdp 
$SMTP = [bool]$xmlconfigfile.configuration.SMTP.send_SMTP 
$SmtpServer = $xmlconfigfile.configuration.SMTP.SmtpServer 
$from = $xmlconfigfile.configuration.SMTP.from 
$to = ($xmlconfigfile.configuration.SMTP.to).split(",") 
$published_notify = [bool]$xmlconfigfile.configuration.SMTP.published_notify 
$notify_of_publish = [bool]$false 
$title = $xmlconfigfile.configuration.SMTP.title 
$SMTPThreshold = $xmlconfigfile.configuration.SMTP.SMTPThreshold 
$EventSource = $xmlconfigfile.configuration.eventvwr.EventSource 
$EventID = $xmlconfigfile.configuration.eventvwr.EventID 
$EventHigh = $xmlconfigfile.configuration.eventvwr.EventHigh 
$EventWarning = $xmlconfigfile.configuration.eventvwr.EventWarning 
$EventInformation = $xmlconfigfile.configuration.eventvwr.EventInformation 
$threshold = $xmlconfigfile.configuration.warnings.threshold 
$threshold_unit = $xmlconfigfile.configuration.warnings.threshold_unit 
$cluster = [bool]$xmlconfigfile.configuration.adcs.cluster 
$clustername = $xmlconfigfile.configuration.adcs.clustername 
$LanInterface = $xmlconfigfile.configuration.Ethernet.LanInterface 
$tmp_outfile = ($xmlconfigfile.configuration.output.outfile).split(",") 
$newline = [System.Environment]::NewLine 
$time = Get-Date 
$EventLevel = $EventInformation 
$CRLList = @{ } 
# 
# Lior Pollack - Add code to enable the network interface ExampleOrg LAN 
# Change "ExampleOrgLAN*" in configuration to the ethernet adapter name of your LAN interface. 
# 
if ($disablenet) { 
    if (!$LanInterface) { 
        write-host "Please include your ethernet lan adapter in the config file or do not use the -disablenat argument" 
        write-host "Use the following format:" 
        write-host "<Ethernet> <LanInterface>ExampleOrgLAN*</LanInterface> </Ethernet>" 
        exit
    } 
    $debug_out = "Enabling interface: " + $LanInterface 
    write-debug $debug_out 
    Get-NetAdapter -Name $LanInterface | Enable-NetAdapter -Confirm:$false 
    Start-Sleep -s 5 
} 
# Lior Pollack - End Enable Logic. 
# 
# Build the output string header 
# 
$evt_string = "<Title>" + $title + " " + $time + "</Title>" + $newline 
$evt_string = $evt_string + "<h1><b>" + $title + " " + $time + "</br></h1>" + $newline 
$evt_string = $evt_string + "<pre>" + $newline 
$evt_string = $evt_string + "CRL Name: " + $master_name + $newline 
$evt_string = $evt_string + "Method: " + $arg1 + $newline 
$evt_string = $evt_string + "Warning threshold: " + $threshold + " " + $threshold_unit + "<br>" + $newline 
# 
# Eventlog string 
# 
$evtlog_string = $evtlog_string + "CRL Name: " + $master_name + $newline 
$evtlog_string = $evtlog_string + "Method: " + $arg1 + $newline 
$evtlog_string = $evtlog_string + "Warning threshold: " + $threshold + " " + $threshold_unit + $newline 
# 
# If ran within the task scheduler, run with admin rights to read the service status 
# Is certsrv running? Is it a clustered CA? 
# If clustered and is not running, send an Informational message 
# 
$service = get-service -Name CertSvc
if (!($service.Status -eq "Running")) { 
    if ($cluster) { 
        # Make sure we are not the active node of the cluster. If we are we have an issue 
        $hostname = $env:COMPUTERNAME 
        $clusterNode = get-clustergroup $clustername 
        $activeclusternode = $clusternode.ownernode.name 
        if ($hostname -eq $activeclusternode) { 
            $evt_string = $evt_string + "<font color=`"red`">**** IMPORTANT **** IMPORTANT **** IMPORTANT ****</font><br>" + $newline 
            $evt_string = $evt_string + "Active clustered Certsvc status is: " + $service.status + "<br>" + $newline 
            $evt_string = $evt_string + "</pre>" + $newline 
            $evtlog_string = $evtlog_string + "**** IMPORTANT **** IMPORTANT **** IMPORTANT ****" + $newline 
            $evtlog_string = $evtlog_string + "Active clustered Certsvc status is: " + $service.status + $newline 
            results $evt_string $evtlog_string $EventHigh $title $SMTP $from $to $SmtpServer $SMTPThreshold $notify_of_publish 
            write-debug "ADCS is not running and this is the active clustered node. Not good." 
            exit 
        } 
        else { 
            # all good, other node of the cluster is the active node 
            $evt_string = $evt_string + "Active Directory Certificate Services is not running on this node of the cluster<br>" + $newline 
            $evt_string = $evt_string + "</pre>" + $newline 
            $evtlog_string = $evtlog_string + "Active Directory Certificate Services is not running on this node of the cluster<br>" + $newline 
            # don't write the HTML output files, the other node will write the files 
            $tmp_outfile = $null 
            results $evt_string $evtlog_string $EventInformation $title $SMTP $from $to $SmtpServer $SMTPThreshold $notify_of_publish 
            write-debug "ADCS is not running. This is a clustered node. Exiting" 
            exit 
        } 
    } 
    else { 
        $evt_string = $evt_string + "<font color=`"red`">**** IMPORTANT **** IMPORTANT **** IMPORTANT ****</font><br>" + $newline 
        $evt_string = $evt_string + "Certsvc status is: " + $service.status + "<br>" + $newline 
        $evt_string = $evt_string + "</pre>" + $newline 
        $evtlog_string = $evtlog_string + "**** IMPORTANT **** IMPORTANT **** IMPORTANT ****" + $newline 
        $evtlog_string = $evtlog_string + "Certsvc status is: " + $service.status + $newline 
        results $evt_string $evtlog_string $EventHigh $title $SMTP $from $to $SmtpServer $SMTPThreshold $notify_of_publish 
        write-debug "ADCS is not running and not a clustered node. Not good." 
        exit 
    } 
} 
else { 
    write-debug "Certsvc is running. Continue." 
} 
# 
# Build the output table 
# 
$evt_string = $evt_string + "<table border=`"1`">" + $newline 
$evt_string = $evt_string + "<tr><td bgcolor=`"#6495ED`"><b> CRL </b></td>` 
<td bgcolor=`"#6495ED`"><b> Path </b></td>` 
<td bgcolor=`"#6495ED`"><b> Number </b></td>` 
<td bgcolor=`"#6495ED`"><b> <a title=`"When this CRL was published`" href=http://blogs.technet.com/b/pki/archive/2008/06/05/how-effectivedate-thisupdate-nextupdate-and-nextcrlpublish-are-calculated.aspx target=`"_blank`"> ThisUpate </a></b></td>` 
<td bgcolor=`"#6495ED`"><b> <a title=`"The CRL will expire at this time`" href=http://blogs.technet.com/b/pki/archive/2008/06/05/how-effectivedate-thisupdate-nextupdate-and-nextcrlpublish-are-calculated.aspx target=`"_blank`"> NextUpdate </a></b></td>` 
<td bgcolor=`"#6495ED`"><b> <a title=`"Time when the CA will publish the next CRL`" href=http://blogs.technet.com/b/pki/archive/2008/06/05/how-effectivedate-thisupdate-nextupdate-and-nextcrlpublish-are-calculated.aspx target=`"_blank`"> NextCRLPublish </a> </b></td>` 
<td bgcolor=`"#6495ED`"><b> Status </b></td>" 
if ($arg1 -eq "publish") { 
    $evt_string = $evt_string + "<td bgcolor=`"#6495ED`"><b> Published </b></td>" 
} 
$evt_string = $evt_string + "</tr>" + $newline 
# 
# Get the master CRL 
# 
write-debug "Pulling master CRL" 
$master_crl = New-Object -ComObject "X509Enrollment.CX509CertificateRevocationList" 
$master_crl = retrieve $master_name $master_retrieval $master_path 
if ($master_crl) { 
    $evt_string = $evt_string + "<tr><td> Master </td>" 
    $evt_string = $evt_string + "<td> " + $master_path + " </td>" 
    $evt_string = $evt_string + "<td> " + $master_crl.CRLNumber() + " </td>" 
    $evt_string = $evt_string + "<td> " + $master_crl.ThisUpdate.ToLocalTime() + " </td>" 
    $evt_string = $evt_string + "<td> " + $master_crl.NextUpdate.ToLocalTime() + " </td>" 
    $evt_string = $evt_string + "<td> " + $master_crl.NextCRLPublish.ToLocalTime() + " </td>" 
} 
else { 
    $EventLevel = $EventHigh 
    $evt_string = $evt_string + "</table></br>" + $newline 
    $evt_string = $evt_string + "<font color=`"red`">Unable to retrieve master crl: $master_path$master_name </font><br>" + $newline 
    $evt_string = $evt_string + "</pre>" + $newline 
    $evtlog_string = $evtlog_string + "Unable to retrieve master crl: $master_name" + $newline 
    results $evt_string $evtlog_string $EventLevel $title $SMTP $from $to $SmtpServer $SMTPThreshold $notify_of_publish 
    write-debug $evt_string 
    exit 
} 
# 
# It looks like IsCurrent method checks against UTC time 
# So reverting to compare with LocalTime 
# 
if ($master_crl.NextUpdate.ToLocalTime() -gt $time) { 
    # determine if with in threshold warning window 
    $delta = new-timespan $time $master_crl.NextUpdate.ToLocalTime() 
    $measure = "Total" + $threshold_unit 
    if ($delta.$measure -gt $threshold) { 
        $evt_string = $evt_string + "<td bgcolor=`"green`"> </td>" 
        $evtlog_string = $evtlog_string + "Master CRL is current" + $newline 
    } 
    else { 
        $evt_string = $evt_string + "<td bgcolor=`"yellow`"> </td>" 
        $evtlog_string = $evtlog_string + "Master CRL is soon to expire and is below threshold level" + $newline 
        $EventLevel = $EventWarning 
    } 
} 
else { 
    $evt_string = $evt_string + "<td bgcolor=`"red`"> </td>" 
    $evtlog_string = $evtlog_string + "Master CRL has expired" + $newline 
    $EventLevel = $EventHigh 
} 
if ($arg1 -eq "publish") { 
    $evt_string = $evt_string + "<td> </td>" 
} 
$evt_string = $evt_string + "</tr>" + $newline 
# 
# Pull CRLs from the CDPs 
# 
write-debug "Pulling CDP CRLs" 
foreach ($cdp in $cdps) { 
    $cdp_crl = New-Object -ComObject "X509Enrollment.CX509CertificateRevocationList" 
    #$cdp_crl = $null 
    $cdp_crl = retrieve $master_name $cdp.retrieval $cdp.retrieval_path 
    $evt_string = $evt_string + "<tr><td> " + $cdp.name + " </td>" 
    # if CDP is http then make an HREF 
    if ($cdp.retrieval -eq "www") { 
        if ($master_name -match " ") { 
            $www_crl = $master_name.replace(" ", "%20") 
        } 
        else { 
            $www_crl = $master_name 
        } 
        $evt_string = $evt_string + "<td><a href=" + $cdp.retrieval_path + $www_crl + ">" + $cdp.retrieval_path + $www_crl + " </a></td>" 
    } 
    else { 
        $evt_string = $evt_string + "<td> " + $cdp.retrieval_path + " </td>" 
    } 
    if ($cdp_crl) { 
        $evt_string = $evt_string + "<td> " + $cdp_crl.CRLNumber() + " </td>" 
        $evt_string = $evt_string + "<td> " + $cdp_crl.ThisUpdate.ToLocalTime() + " </td>" 
        $evt_string = $evt_string + "<td> " + $cdp_crl.NextUpdate.ToLocalTime() + " </td>" 
        $evt_string = $evt_string + "<td> " + $cdp_crl.NextCRLPublish.ToLocalTime() + " </td>" 
        if ($cdp_crl.NextUpdate.ToLocalTime() -gt $time) { 
            # determine if with in threshold warning window 
            $delta = new-timespan $time $cdp_crl.NextUpdate.ToLocalTime() 
            $measure = "Total" + $threshold_unit 
            if ($delta.$measure -gt $threshold) { 
                # if within threshold and the CRL numbers do not match set to orange 
                if ($cdp_crl.CRLNumber() -ne $master_crl.CRLNumber()) { 
                    $evt_string = $evt_string + "<td bgcolor=`"orange`"> </td>" 
                    $evtlog_string = $evtlog_string + $cdp.name + " CRL number does not match master CRL" + $newline 
                } 
                else { 
                    $evt_string = $evt_string + "<td bgcolor=`"green`"> </td>" 
                    $evtlog_string = $evtlog_string + $cdp.name + " is current" + $newline 
                } 
            } 
            else { 
                # within the threshold window 
                $evt_string = $evt_string + "<td bgcolor=`"yellow`"> </td>" 
                $evtlog_string = $evtlog_string + $cdp.name + " is soon to expire and is below threshold level" + $newline 
                if ($EventLevel -gt $EventWarning) { $EventLevel = $EventWarning } 
            } 
        } 
        else { 
            # expired 
            $evt_string = $evt_string + "<td bgcolor=`"red`"> </td>" 
            $evtlog_string = $evtlog_string + $cdp.name + " has expired" + $newline 
            if ($EventLevel -gt $EventHigh) { $EventLevel = $EventHigh } 
        } 
    } # end $cdp_crl exists 
    else { 
        $EventLevel = $EventWarning 
        $evt_string = $evt_string + "<td colspan=`"4`" font color=`"red`">Unable to retrieve crl</font></td>" + $newline 
        $evt_string = $evt_string + "<td bgcolor=`"yellow`"> </td>" 
        $evtlog_string = $evtlog_string + "Unable to retrieve crl: " + $cdp.retrieval_path + $master_name + $newline 
    } 
    if ($arg1 -eq "publish") {
        if ($cdp.push) { 
            $master_crl_tryparse = 0
            $cdp_crl_tryparse = 0
            # TryParse crl number of $master_crl and convert to four-character hex if it is an integer
            if ([int]::TryParse($master_crl.CRLNumber(), [ref]$master_crl_tryparse)) { $master_crl_crlnumber = '{0:X4}' -f $master_crl_tryparse }
            else { $master_crl_crlnumber = $master_crl.CRLNumber() }
            # TryParse crl number of $cdp_crl and convert to a four-character hex if it is an integer
            if ([int]::TryParse($cdp_crl.CRLNumber(), [ref]$cdp_crl_tryparse)) { $cdp_crl_crlnumber = '{0:X4}' -f $cdp_crl_tryparse }
            else { $cdp_crl_crlnumber = $cdp_crl.CRLNumber() }
            $debug_out = "Comparing latest generated issuing CA crl number (cdp_crl_number) with number of published crl (master_crl_number):" + $newline
            $debug_out = $debug_out + "If master_crl_number: $master_crl_crlnumber, is bigger than cdp_crl_number: $cdp_crl_crlnumber, the crl file will be published"
            Write-Debug $debug_out
            if ($master_crl_crlnumber -gt $cdp_crl_crlnumber) { 
                # only file copy at this time 
                $debug_out = "Master CRL is newer, pushing out to " + $cdp.push_path 
                write-output $debug_out 
                $source_path = $master_path + $master_Name 
                $source = Get-Item $source_path 
                $dest_path = $cdp.push_path + "\" + $master_Name 
                # Using an external account to mount file location 
                if ($cdp.push_username -and $cdp.push_passwordfile) { 
                    $debug_out = "Using credentials to mount remote CDP: username/passwordfile = " + $cdp.push_username + "/" + $cdp.push_passwordfile 
                    write-debug $debug_out 
                    
                    $Cred = New-Object System.Management.Automation.PSCredential($cdp.push_username, (Get-Content $cdp.push_passwordfile | ConvertTo-SecureString))
                    $dir = new-psdrive -name P -PSProvider filesystem -root $(($cdp.push_path).TrimEnd("\")) -Credential $Cred 
                } 
                else { 
                    $debug_out = "Using credentials of the account running the script" 
                    write-debug $debug_out 
                } 
                # Copy 
                Copy-Item $source $dest_path 
                # Compare the hash values of the master CRL to the copied CDP CRL 
                # If they do not equal alert via SMTP set event level to high 
                $master_hash = get-filehash -path $source_path 
                write-debug $master_hash.Hash 
                $cdp_hash = get-filehash -path $dest_path 
                write-debug $cdp_hash.Hash 
                if ($master_hash.Hash -ne $cdp_hash.Hash) { 
                    $evt_string = $evt_string + "<td bgcolor=`"red`"> failed </td>" 
                    $evtlog_string = $evtlog_string + "CRL publish to " + $cdp.name + " failed" + $newline 
                    if ($EventLevel -gt $EventHigh) { $EventLevel = $EventHigh } 
                } 
                else { 
                    write-debug "Push succeeded" 
                    $evt_string = $evt_string + "<td bgcolor=`"green`"> " + $time + " </td>" 
                    $evtlog_string = $evtlog_string + "CRL publish to " + $cdp.name + " succeeded" + $newline 
                    # determine if we need to send an SMTP message 
                    if ($published_notify) { 
                        $notify_of_publish = $published_notify 
                    } 
                } 
                # remove drive mapping 
                if ($dir) { 
                    Remove-PSDrive -name P 
                } 
            } #end if master crl # > cdp crl # 
            else { 
                $evt_string = $evt_string + "<td> </td>" 
            } 
        } #end if $cdp.push = TRUE 
        else { 
            $evt_string = $evt_string + "<td> </td>" 
        } 
    } #end of if arg1 = publish 
    $evt_string = $evt_string + "</tr>" + $newline 
    write-debug "" 
    write-debug "----------------" 
    write-debug "" 
} #end of foreach $cdps 
# 
# Close up the table 
# 
$evt_string = $evt_string + "</table></br>" + $newline 
# 
# Send results 
# 
results $evt_string $evtlog_string $EventLevel $title $SMTP $from $to $SmtpServer $SMTPThreshold $notify_of_publish 
# 
# Lior Pollack, Logic Footer 
# 
# Lior Pollack - Disable Network Card 
if ($disablenet) { 
    $debug_out = "Disabling interface: " + $LanInterface 
    write-debug $debug_out 
    Get-NetAdapter -Name $LanInterface | Disable-NetAdapter -Confirm:$false 
} 
# Lior Pollack - End Enable Logic. 
# Lior Pollack - When using for test (monitor) Open CRLCopy.HTM (the 1st one specified on the configuration file) in the default browser. 
if ($arg1 -eq "monitor") 
{ Start-Process $tmp_outfile[0] } 
# Lior Pollack - End Logic. 
# Lior Pollack - If you need to wait at the end for troubleshooting, uncomment the following: 
# write-host "Press any key to continue..." 
# $test = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 
# Write-Host 