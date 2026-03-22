#!/usr/bin/env bash
# Simple terminal setup that actually works

# Install Starship (the only thing that matters)
brew install starship

# Simple .zshrc
cat > ~/.zshrc << 'EOF'
# Homebrew
export PATH="/opt/homebrew/bin:$PATH"

# Starship prompt
eval "$(starship init zsh)"

# Basic aliases that work
alias ll='ls -la'
alias gs='git status'
alias gp='git push'
alias gpl='git pull'

# That's it. Done.
EOF

echo "✅ Simple terminal setup complete"
