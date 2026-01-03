#!/bin/bash

set -e  # Exit on any error

if [ -z "$1" ]; then
    echo "Error: Version argument is required"
    echo "Usage: ./build-session-webhook.sh <version>"
    exit 1
fi

version=$1
location=us-central1
project=eco-seeker-458712-i8
repository=trainings10x-prod
registry_path=$location-docker.pkg.dev/$project/$repository
image_name="session-webhook"
full_image_path=$registry_path/$image_name:$version

echo "=========================================="
echo "Building Session-Webhook Image"
echo "Version: $version"
echo "Registry: $registry_path"
echo "=========================================="

# Build the Docker image
echo "Step 1: Building Docker image..."
docker build -t $image_name:$version -f Dockerfile .
if [ $? -eq 0 ]; then
    echo "✓ Build successful"
else
    echo "✗ Build failed"
    exit 1
fi

# Tag the image for the registry
echo "Step 2: Tagging image for registry..."
docker tag $image_name:$version $full_image_path
if [ $? -eq 0 ]; then
    echo "✓ Tagging successful"
else
    echo "✗ Tagging failed"
    exit 1
fi

# Push to Artifact Registry
echo "Step 3: Pushing image to Artifact Registry..."
docker push $full_image_path
if [ $? -eq 0 ]; then
    echo "✓ Push successful"
else
    echo "✗ Push failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Image successfully stored in Artifact Registry!"
echo "=========================================="
echo "Image path: $full_image_path"
echo ""
echo "To use this image:"
echo "  docker pull $full_image_path"
echo ""
echo "In docker-compose.yaml, use:"
echo "  image: $full_image_path"
echo "=========================================="
