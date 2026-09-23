#!/usr/bin/env zsh

# Directory to process (default = current folder)
TARGET_DIR="${1:-.}"

echo "🔍 Scanning '$TARGET_DIR' for Markdown files..."

# Loop through all .md files recursively
find "$TARGET_DIR" -type f -name "*.md" | while read -r file; do
  # Skip if dg-publish already exists
  if grep -q '^dg-publish:' "$file"; then
    echo "✅ Already set: $file"
    continue
  fi

  # Check if file starts with YAML frontmatter
  if head -n 1 "$file" | grep -q '^---'; then
    # Insert dg-publish: true after first '---' line
    awk '
      NR == 1 { print; print "dg-publish: true"; next }
      { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    echo "📝 Added dg-publish to existing frontmatter: $file"
  else
    # Prepend a new YAML frontmatter block
    {
      echo "---"
      echo "dg-publish: true"
      echo "---"
      echo
      cat "$file"
    } > "${file}.tmp" && mv "${file}.tmp" "$file"
    echo "🌱 Added new frontmatter with dg-publish: $file"
  fi
done

echo "✨ Done! All missing dg-publish properties added."
