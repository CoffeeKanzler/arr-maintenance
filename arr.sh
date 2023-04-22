#!/bin/bash

# Variables
TARGET_STATUS="warning"
PAGE_SIZE=100

# Add your arr instances as ("URL" "API_KEY") pairs
ARR_INSTANCES=(
  "URL" "API_KEY"
  "URL" "API_KEY"
# Add more instances as needed
)

# Function to fetch and process downloads for a given page and instance
process_downloads_page() {
  local arr_url="$1"
  local api_key="$2"
  local page="$3"

  local downloads=$(curl -s -H "X-Api-Key: $api_key" "$arr_url/api/v3/queue?pageSize=$PAGE_SIZE&page=$page")

  # Filtering downloads with target trackedDownloadStatus
  local target_downloads=$(echo "$downloads" | jq -c ".records[] | select(.trackedDownloadStatus == \"$TARGET_STATUS\")")
  [[ -z "$target_downloads" ]] && { echo "No target downloads found. Skipping this Page"; return; }
  # Deleting downloads with target trackedDownloadStatus
  while read -r download; do
    local id=$(echo "$download" | jq '.id')
    echo "Deleting download with ID: $id"
    curl -s -X DELETE -H "X-Api-Key: $api_key" "$arr_url/api/v3/queue/$id"
  done <<< "$target_downloads"
}

# Iterate over all arr instances
for ((i = 0; i < ${#ARR_INSTANCES[@]}; i += 2)); do
  arr_url="${ARR_INSTANCES[i]}"
  api_key="${ARR_INSTANCES[i+1]}"

  # Fetch the first page to calculate the total number of pages
  downloads=$(curl -s -H "X-Api-Key: $api_key" "$arr_url/api/v3/queue?pageSize=$PAGE_SIZE&page=1")
  total_items=$(echo "$downloads" | jq '.totalRecords')
  total_pages=$((($total_items + $PAGE_SIZE - 1) / $PAGE_SIZE))

  # Iterate over all pages and process the downloads
  for ((page = 1; page <= total_pages; page++)); do
    echo "Processing page $page of $total_pages for instance $arr_url"
    process_downloads_page "$arr_url" "$api_key" "$page"
  done
done

echo "Finished deleting downloads with trackedDownloadStatus '$TARGET_STATUS'"
