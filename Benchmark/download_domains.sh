#!/bin/bash

mkdir -p Data

# Download Cisco Umbrella top 1M domains
echo "Downloading Cisco Umbrella top 1M domains..."
curl -L "http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip" -o "Data/top-1m.csv.zip"
unzip -o "Data/top-1m.csv.zip" -d "Data/"

# Extract just the domains (second column) and save to a file
echo "Extracting domains..."
cut -d ',' -f 2 "Data/top-1m.csv" > "Data/domains.txt"

echo "Done! Domains saved to Data/domains.txt"
