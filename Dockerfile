FROM mcr.microsoft.com/powershell:7.4-ubuntu-noble

ARG RUNNER_UID=3001
ARG RUNNER_GID=3001

# System deps for ExchangeOnlineManagement (.NET crypto needs libicu)
RUN apt-get update && apt-get install -y --no-install-recommends \
      libicu74 ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user matching TrueNAS runner convention
RUN groupadd -g ${RUNNER_GID} psfrunner \
    && useradd -u ${RUNNER_UID} -g ${RUNNER_GID} -m -s /bin/bash psfrunner \
    && mkdir -p /home/psfrunner/.local/share \
    && chown -R ${RUNNER_UID}:${RUNNER_GID} /home/psfrunner/.local

# Install PowerShell modules with pinned versions
SHELL ["pwsh", "-Command"]
RUN Set-PSRepository PSGallery -InstallationPolicy Trusted; \
    Install-Module Pode -RequiredVersion 2.11.1 -Scope AllUsers -Force; \
    Install-Module Az.Accounts -RequiredVersion 3.0.5 -Scope AllUsers -Force; \
    Install-Module Az.KeyVault -RequiredVersion 6.3.0 -Scope AllUsers -Force; \
    Install-Module ExchangeOnlineManagement -RequiredVersion 3.6.0 -Scope AllUsers -Force; \
    Install-Module Pester -RequiredVersion 5.6.1 -Scope AllUsers -Force

WORKDIR /app
COPY --chown=${RUNNER_UID}:${RUNNER_GID} . /app/

USER psfrunner
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD ["pwsh", "-c", "exit (0 -eq (Invoke-WebRequest -Uri http://localhost:8080/health -UseBasicParsing -TimeoutSec 3).StatusCode - 200)"]

ENTRYPOINT ["pwsh", "-File", "/app/server.ps1"]
