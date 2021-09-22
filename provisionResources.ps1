# TODO: set variables
$studentName = "mike"
$rgName = "$studentName-ps-rg"
$vmName = "$studentName-ps-vm"
$vmSize = "Standard_B2s"
$vmImage = $(az vm image list --query "[? contains(urn, 'Ubuntu')] | [0].urn" -o tsv)
$vmAdminUsername = "student"
$vmAdminPassword = "LaunchCode-@zure1"
$kvName = "$studentName-lc0922-ps-kv-3"
$kvSecretName = "ConnectionStrings--Default"
$kvSecretValue = "server=localhost;port=3306;database=coding_events;user=coding_events;password=launchcode"

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

az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/1configure-vm.sh

az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/2configure-ssl.sh

az vm run-command invoke --command-id RunShellScript --scripts @deliver-deploy.sh


# TODO: print VM public IP address to STDOUT or save it as a file
Write-Output "Please navigate to $vmIP to view Coding Events"