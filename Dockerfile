# PSF container — PowerShell HTTP API for Exchange Online compliance checks
# HTTP server: .NET System.Net.HttpListener (zero third-party HTTP framework)
# §2.3: Base image pinned by digest, not tag

FROM mcr.microsoft.com/powershell@sha256:042240d57ec9e47e511033b92625a8d95875ee5860af3015992c248b58a8be81
# ↑ powershell:7.5-ubuntu-noble as of 2026-05-07

ARG RUNNER_UID=3001
ARG RUNNER_GID=3001

# System deps — libicu for .NET crypto, ca-certificates for TLS
# §0: No curl — not needed at runtime (least privilege)
RUN apt-get update && apt-get install -y --no-install-recommends \
      libicu74 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# §8.4: Non-root user
RUN groupadd -g ${RUNNER_GID} psfrunner \
    && useradd -u ${RUNNER_UID} -g ${RUNNER_GID} -m -s /bin/bash psfrunner \
    && mkdir -p /home/psfrunner/.local/share \
    && chown -R ${RUNNER_UID}:${RUNNER_GID} /home/psfrunner/.local

# §2.1, §2.2: PowerShell modules — pinned exact versions, no third-party HTTP framework
# ExchangeOnlineManagement 3.6.0 — Microsoft, MIT license, ExO cmdlets
# Pester 5.6.1 — community standard PS test framework, MIT license, 10M+ downloads
# Note: Az.Accounts + Az.KeyVault removed — auth uses client secret (MSAL) directly
SHELL ["pwsh", "-Command"]
RUN Set-PSRepository PSGallery -InstallationPolicy Trusted; \
    Install-Module ExchangeOnlineManagement -RequiredVersion 3.6.0 -Scope AllUsers -Force; \
    Install-Module Pester -RequiredVersion 5.6.1 -Scope AllUsers -Force

WORKDIR /app
COPY --chown=${RUNNER_UID}:${RUNNER_GID} . /app/

USER psfrunner
EXPOSE 8080

# Healthcheck — no shell variables (avoids Docker Compose $ interpolation)
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD ["pwsh", "-c", "exit (0 -eq (Invoke-WebRequest -Uri http://localhost:8080/health -UseBasicParsing -TimeoutSec 3).StatusCode - 200)"]

ENTRYPOINT ["pwsh", "-File", "/app/server.ps1"]
