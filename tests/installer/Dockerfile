FROM debian:12-slim

# Base tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget python3 tar ca-certificates git unzip && \
    rm -rf /var/lib/apt/lists/*

# Node.js 22 (for Codex CLI, npx, Claude CLI)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Bun (for OpenCode)
ENV BUN_INSTALL="/opt/bun"
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/opt/bun/bin:${PATH}"

# Claude Code CLI — real install or mock fallback
RUN npm install -g @anthropic-ai/claude-code 2>/dev/null || \
    (mkdir -p /usr/local/bin && printf '#!/bin/sh\necho "claude v1.0-mock"' > /usr/local/bin/claude && chmod +x /usr/local/bin/claude)

# Codex CLI — real install or mock fallback
RUN npm install -g @openai/codex 2>/dev/null || \
    (mkdir -p /usr/local/bin && printf '#!/bin/sh\necho "codex v0.1-mock"' > /usr/local/bin/codex && chmod +x /usr/local/bin/codex)

# OpenCode — real install or mock fallback
RUN (curl -fsSL https://opencode.ai/install | bash) 2>/dev/null || \
    (mkdir -p /usr/local/bin && printf '#!/bin/sh\necho "opencode v0.1-mock"' > /usr/local/bin/opencode && chmod +x /usr/local/bin/opencode)

# beads CLI — real install or mock fallback
RUN npm install -g @beads/bd 2>/dev/null || \
    (mkdir -p /usr/local/bin && printf '#!/bin/sh\necho "bd mock — no beads workspace"' > /usr/local/bin/bd && chmod +x /usr/local/bin/bd)

# Create test user with proper PATH
RUN useradd -m testuser
USER testuser
ENV PATH="/opt/bun/bin:/usr/local/bin:${PATH}"
WORKDIR /home/testuser
