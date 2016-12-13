##
# Print the settings for debugging purposes
##
function Print-DebugVariables($RabbitHost, $Port, $UserName, $Vhost) {
    Write-Host "Using RabbitMQ Host: $RabbitHost"
    Write-Host "Using RabbitMQ Port: $Port"
    Write-Host "Using Username: $UserName"
    Write-Host "Using VHost: $Vhost"    
}

##
# Create a new vhost
##
function Create-VirtualHost($RabbitHost, $Port, $Vhost, $Credential) {
    $uri = "http://${RabbitHost}:$Port/api/vhosts/$Vhost"
    Write-Host "Creating vhost at $uri"
    Invoke-RestMethod -Uri $uri -Credential $Credential -Method Put -ContentType 'application/json'
    
}

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
Print-DebugVariables $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQUser $stepRabbitMQVirtualHost

#create Credentials
$secpasswd = ConvertTo-SecureString $stepRabbitMQPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($stepRabbitMQUser, $secpasswd)

$exists = Check-VirtualHostExists $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQVirtualHost $cred
if ($exists) {
    Write-Host "Skipping..."
}
else {
    Create-VirtualHost $stepRabbitMQHost $stepRabbitMQPort $stepRabbitMQVirtualHost $cred
    Write-Host "Done."
}