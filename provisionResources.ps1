# TODO: set variables
$studentName = "mike"
$rgName = "$studentName-ps-rg"
$vmName = "$studentName-ps-vm"
$vmSize = "Standard_B2s"
$vmImage = $(az vm image list --query "[? contains(urn, 'Ubuntu')] | [0].urn" -o tsv)
$vmAdminUsername = "student"
$vmAdminPassword = "Launchcode-@zure1"
$kvName = "$studentName-lc0922-ps-kv-4"
$kvSecretName = "ConnectionStrings--Default"
$kvSecretValue = "server=localhost;port=3306;database=coding_events;user=coding_events;password=launchcode"
# TODO: enter your GitHub user name
$github_username = "Sanchez2047"

# TODO: enter the name of your project branch that has your updated code
$solution_branch = "3-aadb2c"

# api
$api_service_user = "api-user"
$api_working_dir = "/opt/coding-events-api"

az configure --default location=eastus

# TODO: provision RG
az group create -n $rgName
az configure --default group=$rgName

# TODO: provision VM
$vmData=$(az vm create -n $vmName -g $rgName --size $vmSize --image $vmImage --admin-username $vmAdminUsername --admin-password $vmAdminPassword --authentication-type password --assign-identity --query "[ identity.systemAssignedIdentity, publicIpAddress ]" -o tsv)
az configure --default vm=$vmName
# TODO: capture the VM systemAssignedIdentity
$vmId=$(echo $vmData | Select -First 1)
$vmIP=$(echo $vmData | Select -Last 1)

# TODO: open vm port 443
az vm open-port -g $rgName -n $vmName --port 443

# provision KV
az keyvault create -n $kvName -g $rgName --enable-soft-delete false --enabled-for-deployment true

# TODO: create KV secret (database connection string)
az keyvault secret set --vault-name $kvName --description 'connection string' --name $kvSecretName --value $kvSecretValue

# TODO: set KV access-policy (using the vm ``systemAssignedIdentity``)
az keyvault set-policy --name $kvName --object-id $vmId --secret-permissions list get

# Create a new deliver-deploy script
rm deliver-deploy.sh

New-Item -Name "deliver-deploy.sh" -ItemType "file" -Value "
#! /usr/bin/env bash

set -ex

# -- env vars --

# for cloning in delivery

# needed to use dotnet from within RunCommand
export HOME=/home/student
export DOTNET_CLI_HOME=/home/student

# -- end env vars --

# -- set up API service --

# create API service user and dirs
useradd -M '$api_service_user' -N
mkdir '$api_working_dir'

chmod 700 /opt/coding-events-api/
chown $api_service_user /opt/coding-events-api/

# generate API unit file
cat << EOF > /etc/systemd/system/coding-events-api.service
[Unit]
Description=Coding Events API

[Install]
WantedBy=multi-user.target

[Service]
User=$api_service_user
WorkingDirectory=$api_working_dir
ExecStart=/usr/bin/dotnet ${api_working_dir}/CodingEventsAPI.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=coding-events-api
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=DOTNET_HOME=$api_working_dir
EOF

# -- end setup API service --

# -- deliver --

# deliver source code

git clone https://github.com/$github_username/coding-events-api /tmp/coding-events-api

cd /tmp/coding-events-api/CodingEventsAPI

# checkout branch that has the appsettings.json we need to connect to the KV
git checkout $solution_branch

cat << EOF > /tmp/coding-events-api/CodingEventsAPI/appsettings.json
{
  'Logging': {
    'LogLevel': {
      'Default': 'Information',
      'Microsoft': 'Warning',
      'Microsoft.Hosting.Lifetime': 'Information'
    }
  },
  'AllowedHosts': '*',
  'ServerOrigin': '$vmIP',
  'KeyVaultName': '$kvName',
  'JWTOptions': {
    'Audience': 'dacff9ec-c689-43e5-b72c-5b037acc87d8',
    'MetadataAddress': 'https://mikecolton0915tenant.b2clogin.com/MikeColton0915tenant.onmicrosoft.com/v2.0/.well-known/openid-configuration?p=B2C_1_susi-flow',
    'RequireHttpsMetadata': true,
    'TokenValidationParameters': {
      'ValidateIssuer': true,
      'ValidateAudience': true,
      'ValidateLifetime': true,
      'ValidateIssuerSigningKey': true
    }
  }
}
EOF


dotnet publish -c Release -r linux-x64 -o '$api_working_dir'

# -- end deliver --

# -- deploy --

# start API service
service coding-events-api start

# -- end deploy --"

az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/1configure-vm.sh

az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/2configure-ssl.sh

az vm run-command invoke --command-id RunShellScript --scripts @deliver-deploy.sh


# TODO: print VM public IP address to STDOUT or save it as a file
Write-Output "Please navigate to $vmIP to view Coding Events"