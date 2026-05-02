FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Pre-create VS Code server directories owned by the vscode user.
# Docker seeds a named volume from the image directory on first creation,
# so this ensures the volumes initialise with correct ownership without
# any host-side workarounds.
RUN mkdir -p /home/vscode/.vscode-server/data/User \
             /home/vscode/.vscode-server/extensions \
    && chown -R vscode:vscode /home/vscode/.vscode-server
