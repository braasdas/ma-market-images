#!/bin/bash
# upload-images.sh
# Uploads images from a weekly market note folder to GitHub Pages CDN
# and replaces placeholder URLs in both HTML files.
#
# Usage: bash upload-images.sh "G:/Shared drives/.../2026-03-06 Market Note"
# Or:    bash upload-images.sh  (auto-detects latest folder)

REPO_DIR="C:/Users/benja/ma-market-images"
WEEKLY_REPORTS_DIR="G:/Shared drives/MA Marketing Drive/1 Compiled Marketing Folder (NEW)/Weekly Reports"
CDN_BASE="https://braasdas.github.io/ma-market-images"

# Determine the target folder
if [ -n "$1" ]; then
    TARGET_DIR="$1"
else
    # Auto-detect latest market note folder by date
    TARGET_DIR=$(ls -d "$WEEKLY_REPORTS_DIR"/*Market\ Note 2>/dev/null | sort | tail -1)
fi

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: Could not find market note folder."
    echo "Usage: bash upload-images.sh \"/path/to/YYYY-MM-DD Market Note\""
    exit 1
fi

# Extract date from folder name (e.g., "2026-03-06")
FOLDER_NAME=$(basename "$TARGET_DIR")
DATE_STR=$(echo "$FOLDER_NAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')

if [ -z "$DATE_STR" ]; then
    echo "ERROR: Could not extract date from folder name: $FOLDER_NAME"
    exit 1
fi

echo "=== MA Market Images Upload ==="
echo "Date:   $DATE_STR"
echo "Folder: $TARGET_DIR"
echo ""

# Create date-specific directory in repo
IMG_DIR="$REPO_DIR/$DATE_STR"
mkdir -p "$IMG_DIR"

# Collect all image files (jpg, jpeg, png, gif, webp) from folder and subfolders
echo "Collecting images..."
IMAGE_COUNT=0
declare -A UPLOADED_FILES

while IFS= read -r -d '' img_path; do
    filename=$(basename "$img_path")
    # Sanitize filename: lowercase, replace spaces with hyphens
    safe_name=$(echo "$filename" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    cp "$img_path" "$IMG_DIR/$safe_name"
    UPLOADED_FILES["$filename"]="$CDN_BASE/$DATE_STR/$safe_name"
    IMAGE_COUNT=$((IMAGE_COUNT + 1))
    echo "  + $filename -> $safe_name"
done < <(find "$TARGET_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" -o -iname "*.webp" \) -print0)

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo "No images found in $TARGET_DIR"
    exit 1
fi

echo ""
echo "Collected $IMAGE_COUNT images."

# Push to GitHub
echo ""
echo "Pushing to GitHub..."
cd "$REPO_DIR"
git add "$DATE_STR/"
git commit -m "Add images for $DATE_STR market note"
git push origin main 2>&1

echo ""
echo "Waiting 30s for GitHub Pages to deploy..."
sleep 30

# Print CDN URLs
echo ""
echo "=== CDN URLs ==="
for original in "${!UPLOADED_FILES[@]}"; do
    echo "  $original"
    echo "    -> ${UPLOADED_FILES[$original]}"
done

# Replace placeholder URLs in HTML files
echo ""
echo "=== Replacing URLs in HTML files ==="

WMN_FILE="$TARGET_DIR/updated_market_note.html"
NEWSLETTER_FILE=$(ls "$TARGET_DIR"/newsletter_*.html 2>/dev/null | head -1)

for html_file in "$WMN_FILE" "$NEWSLETTER_FILE"; do
    if [ -f "$html_file" ]; then
        echo "Processing: $(basename "$html_file")"
        # Replace any squarespace CDN placeholder URLs with our GitHub Pages URLs
        # Match pattern: https://images.squarespace-cdn.com/content/67d200621ae5f1359aee5ad1/FILENAME
        for original in "${!UPLOADED_FILES[@]}"; do
            cdn_url="${UPLOADED_FILES[$original]}"
            # Also try to match sanitized placeholder names
            safe_name=$(echo "$original" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
            # Replace any placeholder URL ending with a similar filename
            sed -i "s|https://images.squarespace-cdn.com/content/[^\"']*/[^\"']*$(echo "$safe_name" | sed 's/\./\\./g')|$cdn_url|gi" "$html_file"
        done
        echo "  Done."
    fi
done

# Also do direct replacements for the known placeholder patterns
for html_file in "$WMN_FILE" "$NEWSLETTER_FILE"; do
    if [ -f "$html_file" ]; then
        # Replace any remaining squarespace placeholder URLs with best-guess GitHub Pages URLs
        sed -i -E "s|https://images\.squarespace-cdn\.com/content/67d200621ae5f1359aee5ad1/([^\"']+)|$CDN_BASE/$DATE_STR/\L\1|gi" "$html_file"
    fi
done

echo ""
echo "=== DONE ==="
echo "Images live at: $CDN_BASE/$DATE_STR/"
echo ""
echo "Uploaded files:"
for original in "${!UPLOADED_FILES[@]}"; do
    echo "  ${UPLOADED_FILES[$original]}"
done
