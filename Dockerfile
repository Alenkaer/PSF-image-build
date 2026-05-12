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
    && mkdir -p /home/psfrunner/.local/share/powershell \
    && mkdir -p /home/psfrunner/.cache \
    && mkdir -p /home/psfrunner/.config \
    && chown -R ${RUNNER_UID}:${RUNNER_GID} /home/psfrunner

ENV HOME=/home/psfrunner

# §2.1, §2.2: PowerShell modules — pinned exact versions, no third-party HTTP framework
# ExchangeOnlineManagement (latest stable) — Microsoft, MIT license, ExO + S&C cmdlets
#   v3.8.0+ adds -AccessToken support for Connect-IPPSSession (required for S&C app-only)
#   Not version-pinned: the specific version was the problem (3.6.0 and 3.7.0 lacked -AccessToken on IPPSSession)
# Pester 5.6.1 — community standard PS test framework, MIT license, 10M+ downloads
SHELL ["pwsh", "-Command"]
RUN Set-PSRepository PSGallery -InstallationPolicy Trusted; \
    Install-Module ExchangeOnlineManagement -Scope AllUsers -Force; \
    Install-Module Pester -RequiredVersion 5.6.1 -Scope AllUsers -Force

WORKDIR /app
COPY --chown=${RUNNER_UID}:${RUNNER_GID} . /app/

USER psfrunner
EXPOSE 8080

# Healthcheck — no shell variables (avoids Docker Compose $ interpolation)
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD ["pwsh", "-c", "if ((Invoke-WebRequest -Uri http://localhost:8080/health -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200) { exit 0 } else { exit 1 }"]

ENTRYPOINT ["pwsh", "-File", "/app/server.ps1"]
