#!/bin/sh

echo "🚀 Welcome to the .NET Alpine VM Setup!"

# Ensure the script runs only ONCE
if [ -f /root/.setup-done ]; then
    echo "Setup has already been completed. Skipping..."
    exit 0
fi

# Update Alpine and install dependencies
apk update && apk upgrade
apk add bash curl git icu-libs libgcc libstdc++ krb5-libs zlib


echo "🔐 Would you like to change the root password? (y/n)"
echo " "

read -r CHANGE_PASS

if [ "$CHANGE_PASS" = "y" ] || [ "$CHANGE_PASS" = "Y" ]; then
    while true; do
        echo -n "Enter new root password: "
        read -s PASSWORD1
        echo
        echo -n "Confirm new root password: "
        read -s PASSWORD2
        echo

        if [ "$PASSWORD1" = "$PASSWORD2" ]; then
            echo "✅ Password set successfully!"
            echo "root:$PASSWORD1" | chpasswd
            break
        else
            echo "❌ Passwords do not match! Please try again."
        fi
    done
else
    echo "🚀 Skipping password change..."
fi

echo "🚀 Continuing with the setup..."


# Install .NET SDK
echo "📥 Installing .NET SDK..."
curl -fsSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 8.0 --install-dir /usr/share/dotnet
ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet

# Fix potential .NET Globalization issues
echo "export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1" >> /etc/profile
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# Get GitHub repository details
while true; do
    echo "📦 Enter the GitHub repository URL (HTTPS format, e.g., https://github.com/user/repo.git):"
    read -r GIT_REPO

    echo "🔑 Do you need an access token? (y/n)"
    read -r USE_TOKEN
    if [ "$USE_TOKEN" = "y" ]; then
        echo "🔑 Enter your GitHub access token:"
        read -r GIT_TOKEN
        GIT_REPO_AUTH="https://$GIT_TOKEN@${GIT_REPO#https://}"
    else
        GIT_REPO_AUTH="$GIT_REPO"
    fi

    # Check if the repository is accessible
    if git ls-remote "$GIT_REPO_AUTH" &> /dev/null; then
        echo "✅ Repository authentication successful."
        break
    else
        echo "❌ Authentication failed. Please check your access token or repository URL and try again."
    fi
done

# Prompt for the branch, list available branches
while true; do
    echo "🌿 Available branches you could track:"
    git ls-remote --heads "$GIT_REPO_AUTH" | awk '{print $2}' | sed 's|refs/heads/||g'

    echo "🌿 Enter the branch you want to track:"
    read -r GIT_BRANCH
    GIT_BRANCH=${GIT_BRANCH:-main}

    # Try cloning the repo
            echo "🗑️ Deleting any previous project..."
        if [ -d "/opt/dotnet-api" ]; then
            rm -rf /opt/dotnet-api
            echo "✅ Old project deleted."
        else
            echo "ℹ️ No existing project found."
        fi

        echo "📁 Creating a fresh directory for the new project..."
        mkdir -p /opt/dotnet-api
        cd /opt/dotnet-api || exit

        echo "📥 Cloning the new project..."
        git clone --branch "$GIT_BRANCH" "$GIT_REPO_AUTH" .

    if [ $? -ne 0 ]; then
        echo "❌ Failed to clone branch '$GIT_BRANCH'. Please select a valid branch."
    else
        break
    fi
done

# Save repository details
echo "$GIT_REPO_AUTH" > /root/repo_url.txt
echo "$GIT_BRANCH" > /root/repo_branch.txt

# Locate the .csproj file
PROJECT_FILE=$(find /opt/dotnet-api -name "*.csproj" | head -n 1)

if [ -z "$PROJECT_FILE" ]; then
    echo "❌ No .csproj file found! Check if your repository contains a valid .NET project."
    exit 1
fi

echo "📦 Restoring dependencies..."
dotnet restore "$PROJECT_FILE"

echo "📦 Building .NET API..."
dotnet build -c Release "$PROJECT_FILE"

# Create auto-start script for .NET API in the console
cat <<EOF > /root/start-dotnet-console.sh
#!/bin/sh
echo "🚀 System fully loaded. Starting .NET API in console mode..."

# Ensure .NET handles case sensitivity properly
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# Navigate to the API directory
cd /opt/dotnet-api || exit

# Ensure the repository exists
if [ ! -d ".git" ]; then
    echo "❌ Error: Repository is missing! Re-cloning..."
    rm -rf /opt/dotnet-api/*
    git clone --branch \$(cat /root/repo_branch.txt) "\$(cat /root/repo_url.txt)" .
fi

# Update and build the API
echo "🔄 Updating repository..."
git fetch origin
git reset --hard origin/\$(cat /root/repo_branch.txt)

echo "📦 Restoring dependencies..."
dotnet restore

echo "⚙️ Building application..."
dotnet build -c Release

# Locate the .dll file
APP_DLL=\$(find /opt/dotnet-api -type f -name "*.dll" | grep "bin/Release" | head -n 1)

if [ -z "\$APP_DLL" ]; then
    echo "❌ No built .dll file found! Build might have failed."
    exit 1
fi

# Start .NET API and stay in the console
echo "🚀 Running .NET API..."
exec dotnet "\$APP_DLL"

# If the script exits, fall back to login shell
exec /sbin/getty 38400 tty1
EOF

chmod +x /root/start-dotnet-console.sh


# Mark setup as completed
touch /root/.setup-done

echo "✅ Setup complete! Your .NET API will now run in the console on boot."