# PSF Pode

PowerShell HTTP API for Exchange Online compliance checks.  
Runs as a Docker container using [Pode](https://badgerati.github.io/Pode/).

## Build

```bash
docker build -t psf-pode .
```

## Environment variables (required at runtime)

| Variable | Purpose |
|---|---|
| `PSF_FUNCTION_KEY` | API authentication key (x-functions-key header) |
| `SP_APP_ID` | Azure Service Principal Application ID |
| `SP_TENANT_ID` | Azure Tenant ID |
| `SP_CLIENT_SECRET` | Service Principal client secret |
| `KEYVAULT_URI` | Azure Key Vault URI |
| `DEFAULT_TENANT_DOMAIN` | Default M365 tenant domain |
| `DEFAULT_APP_ID` | Default App Registration ID |
| `DEFAULT_CERT_NAME` | Certificate name in Key Vault |

## Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/health` | None | Health check |
| POST | `/api/QuarantinePolicy` | API key | CIS 2.1.8 |
| POST | `/api/SharingPolicy` | API key | CIS 3.2.2 |
| POST | `/api/AttackSimTraining` | API key | CIS 2.1.9 |
| POST | `/api/ExternalInOutlook` | API key | CIS 3.5.1 |
| POST | `/api/CustomerLockbox` | API key | CIS 8.7.1 |
| POST | `/api/M365AppsUpdate` | API key | CIS 6.3.1 |
| POST | `/api/CommunicationCompliance` | API key | CIS 7.5.1 |
| POST | `/api/RecordsRetention` | API key | CIS 8.5.1 |

## License

MIT
