#!/bin/bash

set -e  # Exit on any error

if [ -z "$1" ]; then
    echo "Error: Version argument is required"
    echo "Usage: ./build-all-images.sh <version>"
    exit 1
fi

version=$1
location=us-central1
project=eco-seeker-458712-i8
repository=trainings10x-prod
registry_path=$location-docker.pkg.dev/$project/$repository

echo "=========================================="
echo "Building All Images"
echo "Version: $version"
echo "Registry: $registry_path"
echo "=========================================="
echo ""

# ============================================
# 1. Build and Push Zitadel Image
# ============================================
echo "=========================================="
echo "1. Building Zitadel Image"
echo "=========================================="

# Build the Go binary
echo "Step 1.1: Building Go binary..."
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags '-extldflags "-static"' -o zitadel-custom .
if [ $? -eq 0 ]; then
    echo "✓ Go binary build successful"
else
    echo "✗ Go binary build failed"
    exit 1
fi

# Build the Docker image
echo "Step 1.2: Building Zitadel Docker image..."
docker build -t zitadel:$version -f Dockerfile.custom .
if [ $? -eq 0 ]; then
    echo "✓ Build successful"
else
    echo "✗ Build failed"
    exit 1
fi

# Tag and push
echo "Step 1.3: Pushing Zitadel image..."
docker tag zitadel:$version $registry_path/zitadel:$version
docker push $registry_path/zitadel:$version
if [ $? -eq 0 ]; then
    echo "✓ Zitadel image pushed successfully"
else
    echo "✗ Push failed"
    exit 1
fi

# ============================================
# 2. Build and Push Login Image
# ============================================
echo ""
echo "=========================================="
echo "2. Building Login Image"
echo "=========================================="

# Build the login app
echo "Step 2.1: Building login Next.js app..."
cd apps/login
pnpm install
pnpm run build
if [ $? -eq 0 ]; then
    echo "✓ Login app build successful"
else
    echo "✗ Login app build failed"
    exit 1
fi

# Build the Docker image
echo "Step 2.2: Building Login Docker image..."
docker build -t zitadel-login:$version -f Dockerfile.custom .
if [ $? -eq 0 ]; then
    echo "✓ Build successful"
else
    echo "✗ Build failed"
    exit 1
fi

# Tag and push
echo "Step 2.3: Pushing Login image..."
docker tag zitadel-login:$version $registry_path/zitadel-login:$version
docker push $registry_path/zitadel-login:$version
if [ $? -eq 0 ]; then
    echo "✓ Login image pushed successfully"
else
    echo "✗ Push failed"
    exit 1
fi

cd ../..

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "All Images Successfully Stored!"
echo "=========================================="
echo ""
echo "Images pushed to Artifact Registry:"
echo "  1. Zitadel:  $registry_path/zitadel:$version"
echo "  2. Login:    $registry_path/zitadel-login:$version"
echo ""
echo "To use these images, update docker-compose.yaml with:"
echo "  zitadel image:  $registry_path/zitadel:$version"
echo "  login image:    $registry_path/zitadel-login:$version"
echo "=========================================="
