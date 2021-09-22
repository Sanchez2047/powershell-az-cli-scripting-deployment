
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
useradd -M "api-user" -N
mkdir "/opt/coding-events-api"

chmod 700 /opt/coding-events-api/
chown api-user /opt/coding-events-api/

# generate API unit file
cat << EOF > /etc/systemd/system/coding-events-api.service
[Unit]
Description=Coding Events API

[Install]
WantedBy=multi-user.target

[Service]
User=api-user
WorkingDirectory=/opt/coding-events-api
ExecStart=/usr/bin/dotnet /opt/coding-events-api/CodingEventsAPI.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=coding-events-api
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=DOTNET_HOME=/opt/coding-events-api
EOF

# -- end setup API service --

# -- deliver --

# deliver source code

git clone https://github.com/Sanchez2047/coding-events-api /tmp/coding-events-api

cd /tmp/coding-events-api/CodingEventsAPI

# checkout branch that has the appsettings.json we need to connect to the KV
git checkout 3-aadb2c

cat << EOF > /tmp/coding-events-api/CodingEventsAPI/appsettings.json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Microsoft.Hosting.Lifetime": "Information"
    }
  },
  "AllowedHosts": "*",
  "ServerOrigin": "20.102.122.253",
  "KeyVaultName": "mike-lc0922-ps-kv-7",
  "JWTOptions": {
    "Audience": "dacff9ec-c689-43e5-b72c-5b037acc87d8",
    "MetadataAddress": "https://mikecolton0915tenant.b2clogin.com/MikeColton0915tenant.onmicrosoft.com/v2.0/.well-known/openid-configuration?p=B2C_1_susi-flow",
    "RequireHttpsMetadata": true,
    "TokenValidationParameters": {
      "ValidateIssuer": true,
      "ValidateAudience": true,
      "ValidateLifetime": true,
      "ValidateIssuerSigningKey": true
    }
  }
} 
EOF


dotnet publish -c Release -r linux-x64 -o "/opt/coding-events-api"

# -- end deliver --

# -- deploy --

# start API service
service coding-events-api start

# -- end deploy --