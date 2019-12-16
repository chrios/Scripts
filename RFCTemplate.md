# Title
DOE : Implement Client Health Check server and pilot at SVCENTRE

# Description
This change will seek to deploy some infrastructure to support an SCCM client health check and rectify program and database. The server will run an SQL Server Express database, a HTTPS web service, and host a script to be deployed as a scheduled task via group policy. The scheduled task will be deployed in this change to SVCENTRE as a pilot before deployment in the Enterprise.

# Risk analysis and mitigation
Risk: The program will not perform expected tasks, and cause issues on machines
Mitigation: Program code reviewed by senior engineers before implementation
Mitigation: The program will be deployed to SVCENTRE in this change to pilot before enterprise deployment.

Risk: The user will be affected by the scheduled task running
Mitigation: SVCENTRE pilot to be communicated for staff to notify implementing engineer if there is an issue

# User Impact
There is no user impact expected from this change.

# Communication Plan
Standard + NEC.DECS.AllStaff@nec.com.au

# Pre-Implementation
Verify available resources on GDC vSphere Datacentre.
Download version 0.8.2 of ConfigMgr Client Health from Anders Rodland's website: https://www.andersrodland.com/configmgr-client-health/
Download installer for SQL Server 2017 Express: https://www.microsoft.com/en-au/sql-server/sql-server-editions-express

# Implementation
Deploy new server to GDC cluster in vSphere from Windows Server 2019 Core template:
1. Browse to https://drwnt-vc1.ntschools.net, login with adm credentials
2. Right click GDC -> New Virtual Machine
3. Select Deploy from TEmplate, Next
4. SElect 'SOE Win2019 Std Core Template', Next
5. Name Machine next available drwnt-inxx
6. Keep defaults for remainder of choices

Create Delegation group for SA privileges, add Domain Admins into SA delegation group
New-ADGroup -Name "Delegation - <servername> SQL Admin" -SamAccountName "Delegation - <servername> SQL Admin" -GroupCategory Security -GroupScope Global -DisplayName "Delegation - <servername> SQL Admin" -Path "OU=Groups,OU=Service,DC=ntschools,DC=net" -Description "Members of this group are SA on <servername>"
Add-ADGroupMember -Identity "Delegation - <servername> SQL Admin" -Members "Domain Admins"

Install SQL Server Express on new server
1. Copy installer to c:\admin on new server
2. Use the following command to install SQL server express:
Setup.exe /QS /ACTION=Install /FEATURES=SQLEngine /INSTANCENAME=MSSQLSERVER /SQLSVCACCOUNT="NT AUTHORITY\Network Service" /SQLSYSADMINACCOUNTS="NTSCHOOLS\Delegation - <servername> SQL Admin" /AGTSVCACCOUNT="NT AUTHORITY\Network Service" /TCPENABLED=1 /IACCEPTSQLSERVERLICENSETERMS

Create file share to hold script and configuration, set permissions



# Verification / Test Plan


# Backout Plan
 