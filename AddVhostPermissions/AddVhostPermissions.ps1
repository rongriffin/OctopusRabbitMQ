##
# Print the settings for debugging purposes
##
function Print-DebugVariables($RabbitHost, $Port, $ApiUserName, $UserName, $VHost) {
    Write-Host "Using RabbitMQ Host: $RabbitHost"
    Write-Host "Using RabbitMQ Port: $Port"
    Write-Host "Using API Username: $ApiUserName"
    Write-Host "Setting up permissions for Username: $UserName"
    Write-Host "Setting up permissions on Vhost: $Vhost"
}

##
# Create a new user
##
function Set-UserVhostPermsission($RabbitHost, $Port, $UserName, $Vhost, $Credential) {
    $uri = "http://${RabbitHost}:$Port/api/permissions/$Vhost/$UserName"
    Write-Host "Setting user permissions at $uri"

    $request = @{
        configure=".*"
        write=".*"
        read=".*"
    }

    $body = $request | ConvertTo-Json
    Invoke-RestMethod -Uri $uri -Credential $Credential -Body $body -Method Put -ContentType 'application/json'    
}

##
# Check if a vhost exists
##
function Check-VirtualHostExists($RabbitHost, $Port, $Vhost, $Credential) {
    $uri = "http://${RabbitHost}:$Port/api/vhosts"
    Write-Host "Retrieving vhosts at $uri"
    $response = Invoke-RestMethod -Uri $uri -Credential $Credential -Method Get 

    foreach ($item in $response) {
        if($item.name -eq $Vhost) {
            Write-Host "vhost [$Vhost] exists!"
            return $true
        }
    }

    return $false
}

##
# Check if the specified user already exists
##
function Check-RabbitUserExists($RabbitHost, $Port, $UserName, $Credential) {
    $uri = "http://${RabbitHost}:$Port/api/users"
    Write-Host "Retrieving current users at $uri"
    $response = Invoke-RestMethod -Uri $uri -Credential $Credential -Method Get 

    foreach ($item in $response) {
        if($item.name -eq $UserName) {
            Write-Host "user [$UserName] exists!"
            return $true
        }
    }

    return $false
}

# Handle untrusted certs since we use self-signed certificates.
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# variable names are prefixed with 'step' to prevent issues with Octopus variable set name collisions.
Print-DebugVariables $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQApiUser $stepRabbitMQUser $stepRabbitMQVhost

#create Credentials
$secpasswd = ConvertTo-SecureString $stepRabbitMQApiPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($stepRabbitMQApiUser, $secpasswd)

$userexists = Check-RabbitUserExists $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQUser $cred
if ($userexists) {
    $vhostexists = Check-VirtualHostExists $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQVhost $cred
    if ($vhostexists) {
         Set-UserVhostPermsission $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQUser $stepRabbitMQVhost $cred
         Write-Host "Done."
    }
    else {
        Write-Error "Vhost [$stepRabbitMQVhost] does not exist.  Create it first."
    }
}
else {    
    Write-Error "User [$stepRabbitMQUser] does not exist.  Create it first."
}