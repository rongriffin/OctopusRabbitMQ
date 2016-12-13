##
# Print the settings for debugging purposes
##
function Print-DebugVariables($RabbitHost, $Port, $ApiUserName, $NewUserName) {
    Write-Host "Using RabbitMQ Host: $RabbitHost"
    Write-Host "Using RabbitMQ Port: $Port"
    Write-Host "Using API Username: $ApiUserName"
    Write-Host "Creating Username: $NewUserName"
}

##
# Create a new user
##
function Create-RabbitUser($RabbitHost, $Port, $NewUserName, $NewPassword, $Credential) {
    $uri = "http://${RabbitHost}:$Port/api/users/$NewUserName"
    Write-Host "Creating a new user at $uri"

    $request = @{
        password="$NewPassword"
        tags=""
    }

    $body = $request | ConvertTo-Json
    Invoke-RestMethod -Uri $uri -Credential $Credential -Body $body -Method Put -ContentType 'application/json'
    
}

##
# Check if the specified user already exists
##
function Check-RabbitUserExists($RabbitHost, $Port, $NewUserName, $Credential) {
    $uri = "http://${RabbitHost}:$Port/api/users"
    Write-Host "Retrieving current users at $uri"
    $response = Invoke-RestMethod -Uri $uri -Credential $Credential -Method Get 

    foreach ($item in $response) {
        if($item.name -eq $NewUserName) {
            Write-Host "user [$NewUserName] exists!"
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
Print-DebugVariables $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQApiUser $stepRabbitMQNewUserName

#create Credentials
$secpasswd = ConvertTo-SecureString $stepRabbitMQApiPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($stepRabbitMQApiUser, $secpasswd)

$exists = Check-RabbitUserExists $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQNewUserName $cred
if ($exists) {
    Write-Host "Skipping..."
}
else {
    Create-RabbitUser $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQNewUserName $stepRabbitMQNewUserPassword $cred
    Write-Host "Done."
}