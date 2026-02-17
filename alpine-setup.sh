#!/bin/sh

# Changing directory to home
echo "🏠 Changing directory to home..."
cd ~

# Displaying Alpine Linux version
echo "🐧 Displaying Alpine Linux version..."
cat /etc/alpine-release

# Setting Alpine repositories
echo "🔧 Setting Alpine repositories..."
echo "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main" > /etc/apk/repositories
echo "https://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories

# Updating APK package index
echo "🔄 Updating APK package index..."
apk update

# Upgrading installed packages
echo "⬆️ Upgrading installed packages..."
apk upgrade

# Installing Docker, Docker Compose, OpenSSL, and jq
echo "🐳 Installing Docker, Docker Compose, jq, and curl..."
apk add docker docker-compose openssl jq curl

# Adding Docker to boot services
echo "⚙️ Adding Docker to boot services..."
rc-update add docker boot

# Starting Docker service
echo "🚀 Starting Docker service..."
service docker start

# Waiting for Docker to start
echo "⏳ Waiting for Docker to start..."
until service docker status | grep -q "started"; do 
    echo "🔄 Docker is starting, waiting..."
    sleep 5
done

# Confirm Docker is running
echo "✅ Docker is running!"

# Displaying Docker info
echo "ℹ️ Displaying Docker info..."
docker info

# Pulling Docker images
echo "⬇️ Pulling Docker images..."
docker pull netbirdio/dashboard:latest
docker pull netbirdio/management:latest
docker pull netbirdio/relay:latest
docker pull netbirdio/signal:latest

# Running NetBird setup script
echo "🎉 Clonning Netbird Setup repo..."
wget https://github.com/siammridha/netbird-setup/archive/refs/heads/main.zip -O netbird-setup.zip
# Unzip the ZIP file into the target directory
unzip -o netbird-setup.zip
# copy all files to netbird-setup
mv netbird-setup-main netbird-setup
#clean up the ZIP file
rm -r netbird-setup-main netbird-setup.zip

echo "🎉 Running NetBird setup script..."
chmod +x netbird-setup/netbird-deploy.sh
bash -i ./netbird-setup/netbird-deploy.sh