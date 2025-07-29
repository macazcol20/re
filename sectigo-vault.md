https://github.com/square/certstrap

[Certstrap Root/Intermediate CA] ───▶ [Vault PKI Engine on Kubernetes]
                                          │
                                          ▼
       [Vault Agent Injector or CSI Driver injects certs into pods]

## Key terminologies
**- Root CA**
The Root Certificate Authority (CA) is the top-level trust anchor in a public key infrastructure (PKI). It's a self-signed certificate that issues and signs intermediate CAs, which in turn sign the certificates for your applications and services.

**- Intermediate CA**

## Install
- certstrap must be built with Go 1.18+. You can build certstrap from source:

```sh
git clone https://github.com/square/certstrap
cd certstrap
go build
```

## Initialize a new ROOT certificate authority:
```sh
./certstrap init --common-name "CollinsRootCA"
Created out/CollinsRootCA.key
Created out/CollinsRootCA.crt
Created out/CollinsRootCA.crl
```

## Generate the Intermediate CA CSR
```sh
./certstrap request-cert --common-name "CollinsIntermediateCA"
```

##  Sign the CSR Using Your Root CA
```sh
./certstrap sign "CollinsIntermediateCA" --CA "CollinsRootCA"
## you will see a new cert after the signing: CollinsIntermediateCA.crt
```

## Create the Certificate Chain for Vault
Vault expects a full certificate chain (intermediate first, then root).

```sh
cat out/CollinsIntermediateCA.crt out/CollinsRootCA.crt > out/CollinsIntermediateCA-chain.crt

ls -l out/CollinsIntermediateCA-chain.crt
```

## Now onto Vault
### Deploy Vault in Kubernetes 

## Enable and Configure the PKI Engine
```sh
vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=8760h pki_int
```

## Set URLs (replace with real Vault address):
```sh
vault write pki_int/config/urls \
  issuing_certificates="https://vault.yourdomain.com/v1/pki_int/ca" \
  crl_distribution_points="https://vault.yourdomain.com/v1/pki_int/crl"
```

## Create a Role to Issue TLS Certs
```sh
vault write pki_int/roles/k8s-tls-role \
  allowed_domains="svc.cluster.local" \
  allow_subdomains=true \
  allow_glob_domains=true \
  generate_lease=true \
  max_ttl="72h"
```

## Install Vault Agent Injector (for Automatic Cert Injection)
```sh
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --set "injector.enabled=true" \
  --set "server.enabled=false"

## annotate the namespace where your service is running: example on namespace kafka
kubectl annotate namespace kafka vault.hashicorp.com/agent-injection=enabled
```

## Annotate Your Pod/Deployment to Get TLS Cert
```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-tls-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-tls-app
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "k8s-tls-role"
        vault.hashicorp.com/agent-inject-secret-cert.pem: "pki_int/issue/k8s-tls-role"
        vault.hashicorp.com/agent-inject-template-cert.pem: |
          {{- with secret "pki_int/issue/k8s-tls-role" "common_name=my-tls-app.svc.cluster.local" -}}
          {{ .Data.certificate }}
          {{ end }}
      labels:
        app: my-tls-app
    spec:
      serviceAccountName: vault-auth
      containers:
      - name: app
        image: nginx
```

