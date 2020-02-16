#SQL MANAGEMENT STUDIO SHOULD BE INSTALLED FROM WHERE YOU RUN THIS
#The server this is run from should have SQL Port and WMI access to the servers you intend to connect to.
#You will require file sqlserver.psd1, change the path to it below.
Import-Module -Name D:\PATH\TO\sqlserver.psd1 -DisableNameChecking
#Load SQL Management Studio Assembly
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
$ErrorActionPreference = "SilentlyContinue"

$domain = 'DOMAIN'
#SA Windows User Account
$user = "$domain\USERNAME"
$sql_perm_data = @()
$userrole = @()
$date = get-date -format MM-dd
$day = get-date -format dd
$month = get-date -format MM
$year = get-date -format yy
$HKLM = 2147483650
$SQLEdition = "Enterprise"
$SQLPort = "1433"
#List of servers IP's
$IPs = Import-CSV D:\PATH\TO\CSVFILE.CSV

#If you are writing this to a SQL server provide that info below.
$storeSQLserver = "SQL_SERVER"
$storeSQLDatabase = "DATABASE"
$storeTable = "TABLE"

#Get user credentials as wmi, password as encrypted text file, change to your encrypted password location.
$wmiCredentials = New-Object System.Management.Automation.PsCredential $user, (Get-Content D:\YOUR\ENC\PASSWORD.ENC | ConvertTo-SecureString)
#Uncomment to enter credentials on demand
#$wmiCredentials = Get-Credential -credential $null

#Intended to only run once per day, so we begin by erasing todays data if it already exists, so we don't end up with duplicate data.
$query = "DELETE FROM $storeTable where DATE LIKE '$date%' AND DOMAIN LIKE '$domain%'";
Invoke-Sqlcmd -ServerInstance $storeSQLServer -Database $storeSQLdatabase-Query $query -MaxCharLength 3000 -Verbose

foreach ($IP in $IPs) {
    clear-variable srv -ErrorAction SilentlyContinue
    $IP = $IP.IP.replace("`n", "") | out-string
    $IP = $IP.replace(" ", "") | out-string
    $IP = $IP.trim()

    #Get the name of the server
    $sysinfo = Get-WmiObject -computer $IP -credential $wmiCredentials -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
    $server = $sysinfo.Name


    $portCheck = Test-NetConnection -computername $IP -port $SQLPort
    if ($portCheck.tcpTestSucceeded -like "True") { $portPassed = "True" }else { write-host "Unable to Connect to $IP on $SQLPort" }

    if ($portPassed -like "True") {

        write-host "Connecting to $server..."
        clear-variable listenername -ErrorAction SilentlyContinue
        clear-variable srv -ErrorAction SilentlyContinue
        clear-variable instance -ErrorAction SilentlyContinue

        write-host "Checking registry for HA $server..."
        $reg = Get-WmiObject -List -Namespace root\default -computername $IP -Credential $wmiCredentials | Where-Object { $_.Name -eq "StdRegProv" }
        #Collecting SQL cluster availibility group information
        #Availibilty Group Name
        $agName = $reg.EnumValues($HKLM, "Cluster\HadrAgNameToIdMap").sNames
        #Cluster Name
        $clusterName = $reg.getStringValue($HKLM, "Cluster", "ClusterName").sValue
        #Listerner Name
        $GUID = $reg.EnumKey($HKLM, "Cluster\Resources").sNames | `
            where-object { $reg.getStringValue($HKLM, "Cluster\Resources\$_\Parameters", "DnsName").sValue -notlike $NULL`
                -and $reg.getStringValue($HKLM, "Cluster\Resources\$_\Parameters", "DnsName").sValue -notlike "*$clusterName*"
        }
        $listenerName = $reg.getStringValue($HKLM, "Cluster\Resources\$GUID\Parameters", "DnsName").sValue

        #Get SQL Instances
        write-host "Getting SQL instances $server..."
        $reg = Get-WmiObject -List -Namespace root\default -ComputerName $IP -Credential $wmiCredentials | Where-Object { $_.Name -eq "StdRegProv" }
        $regkeys = $reg.GetMultiStringValue($HKLM, "SOFTWARE\Microsoft\Microsoft SQL Server", "InstalledInstances").sValue


        #Find SQL Instance, only one instance per server, for now sorry.
        foreach ($regkey in $regkeys) {
                    
            if ($regkey -like "MSSQL*" -and $regkey -like "*.*") {
                $instance = $regkey
            }
        }

        #Try to find a connection either through listener or direct to server, or by instance name
        write-host "Connecting to SQL $server..."
        [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null 
        #Via listenername instance and port    
        if ($listenerName -notlike $NULL) { $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$listenerName\$instance,$SQLPort" }
        else { 
            #instance only
            $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$server\$instance"

            if ($srv.DatabaseEngineEdition -notlike "*$SQLEdition*") {
                #instance and port
                $srv = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$server\$instance,$SQLPort"

            } 
        }

        #Get all SQL Login accounts
        foreach ($login in $srv.logins) { 
            $loginname = $login.name
            clear-variable userrole -ErrorAction SilentlyContinue
            foreach ($role in $Login.ListMembers()) {
                $role
                $role = $role | out-string
                $userrole += $role + ", "

            }
                                   
            $userrole = $userrole.replace("`n", "")
            $userrole = $userrole + "public"
            $userrole


            if ($login.name -notlike "*dbo*" -and $login.name -notlike "sys"`
                    -and $login.name -notlike "guest" -and $login.name -notlike "*##*"`
                    -and $login.name -notlike "*MS_*" -and $login.name -notlike "*_SCHEMA*") {


                #Create an object and write properties about the account
                $row = New-Object PSObject
                $row | Add-Member -MemberType NoteProperty -Name "Database" -Value "Server Login"
                $row | Add-Member -MemberType NoteProperty -Name "Login" -Value $login.name
                $row | Add-Member -MemberType NoteProperty -Name "Created" -Value $Login.CreateDate
                $row | Add-Member -MemberType NoteProperty -Name "Modified" -Value $Login.DateLastModified
                $row | Add-Member -MemberType NoteProperty -Name "LoginType" -Value $Login.LoginType
                $row | Add-Member -MemberType NoteProperty -Name "Service Account" -Value $ServiceAccount
                $row | Add-Member -MemberType NoteProperty -Name "Roles" -Value $userrole
                $row | Add-Member -MemberType NoteProperty -Name "Disabled" -Value $login.isdisabled
                $sql_perm_data += $row

                #Turn properties into variables for writing to SQL
                $Loginname = $Login.name
                $LoginCreateDate = $Login.CreateDate
                $LoginDateLastModified = $Login.DateLastModified
                $LoginLoginType = $Login.LoginType
                $Loginisdisabled = $Login.isdisabled
                $Databasename = "Server Login"

                if ($srv.DatabaseEngineEdition -like "*Enterprise*") { } else { $AGNAME = "No SQL Connection" }

                #Write SQL Login Information to a SQL Row
                $query = " 
INSERT into $storeTABLE (IP,CNAME,DB,DOMAIN,LOGIN,CREATED,MODIFIED,LOGINTYPE,SERVICEACCOUNT,ROLES,DISABLED,DATE,MONTH,DAY,YEAR,AGNAME,LISNAME,CLUNAME) VALUES ('$IP','$Server','$Databasename','$DOMAIN','$LoginName','$LoginCreateDate','$LoginDateLastModified','$LoginLoginType','$ServiceAccount','$userrole','$loginisdisabled','$date','$Month','$Day','$Year','$agname','$listenername','$clustername')
"
                Invoke-Sqlcmd -ServerInstance $storeSQLServer -Database $storeSQLdatabase-Query $query -MaxCharLength 3000 -Verbose
                                  
            }
                                                                    
        }

        #Begin getting security information for each database
        foreach ($database in $srv.Databases) {
            $users = $database.Users
            foreach ($user in $users | where-object { $_.HasDBAccess -like "True" }) {
                Clear-Variable userrole -ErrorAction SilentlyContinue
                Write-Output "`n Processing $server , $database , $user " 
                foreach ($role in $Database.Roles) {

                    $role = $role.name | out-string
                    $userrole += $role + ", "
                }

                $userrole = $userrole.replace("`n", "")
                $userrole = $userrole + "@"
                $userrole = $userrole.replace(", @", "")

                if ($user.name -notlike "sys"`
                        -and $user.name -notlike "guest" -and $user.name -notlike "*##*"`
                        -and $user.name -notlike "*MS_*" -and $user.name -notlike "*_SCHEMA*") {

                    if ($user.name -like "*ss01*") 
                    { $ServiceAccount = "True" } else { $ServiceAccount = "False" }

                    $row = New-Object PSObject

                    $row | Add-Member -MemberType NoteProperty -Name "Database" -Value $Database.name
                    $row | Add-Member -MemberType NoteProperty -Name "Login" -Value $user.name
                    $row | Add-Member -MemberType NoteProperty -Name "Created" -Value $user.CreateDate
                    $row | Add-Member -MemberType NoteProperty -Name "Modified" -Value $user.DateLastModified
                    $row | Add-Member -MemberType NoteProperty -Name "LoginType" -Value $user.LoginType
                    $row | Add-Member -MemberType NoteProperty -Name "Service Account" -Value $ServiceAccount
                    $row | Add-Member -MemberType NoteProperty -Name "Roles" -Value $userrole
                    $row | Add-Member -MemberType NoteProperty -Name "Disabled" -Value $user.isdisabled

                    $sql_perm_data += $row

                    $userName = $user.Name
                    $userCreateDate = $user.CreateDate
                    $userDateLastModified = $user.DateLastModified
                    $userLoginType = $user.LoginType
                    $userisdisabled = $user.isdisabled
                    $Databasename = $Database.name

                    write-host "has db access: " $user.HasDBAccess

                    if ($srv.DatabaseEngineEdition -like "*$SQLEdition*") { } else { $AGNAME = "No SQL Connection" }

                    $query = "
INSERT into $storeTable (IP,CNAME,DB,DOMAIN,LOGIN,CREATED,MODIFIED,LOGINTYPE,SERVICEACCOUNT,ROLES,DISABLED,DATE,MONTH,DAY,YEAR,AGNAME,LISNAME,CLUNAME) VALUES ('$IP','$Server','$Databasename','$DOMAIN','$UserName','$UserCreateDate','$UserDateLastModified','$UserLoginType','$ServiceAccount','$userrole','$userisdisabled','$date','$Month','$Day','$Year','$agname','$listenername','$clustername')
" 
                    Invoke-Sqlcmd -ServerInstance $storeSQLServer -Database $storeSQLdatabase-Query $query -MaxCharLength 3000 -Verbose

                }
                                  
            }                   
                                
        } 

    } 
}
    
