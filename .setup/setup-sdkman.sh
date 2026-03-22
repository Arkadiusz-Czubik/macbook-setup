#!/usr/bin/env bash
# ~/dotfiles/setup_sdkman.sh

set -e

echo "☕ Setting up SDKMAN and Java tools..."

# Install SDKMAN
if [ ! -d "$HOME/.sdkman" ]; then
    echo "📦 Installing SDKMAN..."
    curl -s "https://get.sdkman.io" | bash
    
    # Source SDKMAN
    source "$HOME/.sdkman/bin/sdkman-init.sh"
else
    echo "✅ SDKMAN already installed"
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Install Java LTS versions (Amazon Corretto)
echo "☕ Installing Java..."
sdk install java 21.0.1-amzn || true  # Amazon Corretto JDK 21 (LTS)
sdk install java 17.0.9-amzn || true  # Amazon Corretto JDK 17 (LTS)

# Set Java 21 as default
sdk default java 21.0.1-amzn

# Install latest stable Gradle
echo "🏗️  Installing Gradle..."
sdk install gradle || true

# Show installed versions
echo ""
echo "✅ SDKMAN setup complete!"
echo ""
echo "📋 Installed versions:"
java -version
gradle -version

echo ""
echo "💡 To manage Java versions:"
echo "  sdk list java          # List available versions"
echo "  sdk install java X.Y.Z # Install specific version"
echo "  sdk use java X.Y.Z     # Use version for current session"
echo "  sdk default java X.Y.Z # Set default version"
