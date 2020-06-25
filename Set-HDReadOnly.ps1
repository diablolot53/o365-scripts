<#
	NAME
		Set-HDReadOnly

	DESCRIPTION
		Changes the permissions on a directory so the user provided is configured with read-only privlages. Can be useful during a OneDrive migration
		to prevent a user from making changes to thier home drive/folder/share during while the files are being uploaded and to
		prepare for a final cutover.
	
	PARAMETERS
		User (Required)
			SamAccountName of the user
			Ex - JDoe
		
		Domain (Required)
			NetBIOS name of the domain
			Ex - CONTOSO
		
		Directory (Required)
			Local directory path
			Ex - D:\UserShare\JDoe
		
		CheckOnly
			Returns the assigned permissions for the provided user and the account listed as owner of the directory

		ChangeOwner
			Changes the owner on the directory to BUILTIN\Administrators

		Force
			Adds the user with read-only privlages to the directory even if they don't have explicit Full Control or Modify permission 
	
	EXAMPLE
		./Set-HDReadOnly -User JDoe -Domain CONTOSO -Directory D:\UserShare\JDoe
#>

param(
	[Parameter(Mandatory)][string]$User,		#SamAccountName of the user
	[Parameter(Mandatory)][string]$Domain,		#AD Domain name/Computer Name
	[Parameter(Mandatory)][string]$Directory,	#Directory that will have have the ACL change
	[switch]$CheckOnly,							#Writes the found ACL entries w/o making changes
	[switch]$ChangeOwner,						#Changes the owner to BUILTIN\Administrators
	[switch]$Force								#Force the user to be added to the ACL with R/O access
)

Function Test-String{
	param(
		[string]$TestValue,
		[string]$ParamName
	)
	
	#Check the string for invalid characters and throw an exception if one is found
	If ($TestValue -match '[^\w:\\-]'){
		$Message = "$ParamName parameter contains illegal character '{1}'." -f $String,$Matches[0]
		#$Exception = [System.FormatException]::new()
		#Write-Error -Exception $Exception  -Message $Message
		Throw $Message
	}
}

#Test input parameters for illegal characters
Test-String $Directory "Directory"
Test-String $User "User"
Test-String $Domain "Domain"

#Verify -Directory is valid
If ((Test-Path $Directory) -eq $False){
	$Message = "Directory not found - $Directory"
	#$Exception = [System.FormatException]::new()
	Throw $Message
}

#-------------------------------------
Try{
	#Get ACL for directory
	$acl = Get-Acl $Directory

	#Find FullControl access rules assigned to user
	$AccessRules = $acl.Access | Where-Object {($_.IdentityReference -eq "$Domain\$User") -and (($_.FileSystemRights -eq "FullControl") -or ($_.FileSystemRights -eq 268435456) -or ($_.FileSystemRights -eq "Modify, Synchronize"))}

	#If no Full Control access rules are found, skip the following sections
	If ($CheckOnly -eq $True){

        #Return any ACL that has the user in the IdentityReference if none were provisioned with Full Control
        If ($AccessRules -eq $Null){
            $AccessRules = $acl.Access | Where-Object {($_.IdentityReference -eq "$Domain\$User")}
        }

        #Check AccessRules again and report if nothing is found
        If ($AccessRules -eq $Null){
            $AccessRules = "$User does not have any explicit permissions to $Directory"
        }
		Else {
			$AccessRules = "Owner`n" + ($acl.Owner | Out-String) + ($AccessRules | Out-String)
		}
        
        #Return findings w/o making changes
		Write-Host ($AccessRules)
	}
	ElseIf (($AccessRules -ne $Null) -or ($Force -eq $True)){
		#Perform the ACL changes
		#Remove Existing access rules
		ForEach ($rule in $AccessRules){
			$acl.RemoveAccessRule($rule) | Out-Null
		}

		#Set read-only access rule
		$ROAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("$Domain\$User","ReadAndExecute",3,0,"Allow")
		$acl.SetAccessRule($ROAccessRule)
		$acl | Set-Acl $Directory
		
		#Inform user that changes were successfull
		Write-Host "$User now has Read-Only access to $Directory"
	}
	Else{
		$Message = "$User does not have Full Control permission to $Directory. No changes were made"
		Write-Host $Message
	}
	
	#Change the owner if the -ChangeOwner parameter is selected
	If ($ChangeOwner -eq $True){
		$newOwner = New-Object System.Security.Principal.NTAccount("BUILTIN","Administrators")
		$oldOwner = $acl.Owner | Out-String
		$acl.SetOwner($newOwner)
		$acl | Set-Acl $Directory
		Write-Host "`nOwner changed from $oldOwner to $newOwner"
	}
}
Catch{
	  Write-Host "An error occurred:"
	  Write-Host $_.ScriptStackTrace
}
