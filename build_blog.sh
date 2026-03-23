#!/bin/bash

# build_blog.sh
# Converts all markdown files in blogs/markdown/ to HTML using Pandoc,
# then regenerates blogs/index.html listing all posts.
#
# Usage: ./build_blog.sh
# Requires: pandoc

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKDOWN_DIR="$SCRIPT_DIR/blogs/markdown"
HTML_DIR="$SCRIPT_DIR/blogs/html"
TEMPLATE="$SCRIPT_DIR/blogs/templates/post.html"
INDEX="$SCRIPT_DIR/blogs/index.html"

# ── Checks ────────────────────────────────────────────────────────────────────

if ! command -v pandoc &>/dev/null; then
    echo "Error: pandoc is not installed. Install it with:"
    echo "  sudo apt install pandoc   # Debian/Ubuntu"
    exit 1
fi

mkdir -p "$HTML_DIR"

# ── Convert each markdown file ────────────────────────────────────────────────

declare -a POST_DATA  # will hold "date|title|filename" per post

echo "Building blog posts..."

for md_file in "$MARKDOWN_DIR"/*.md; do
    [ -e "$md_file" ] || { echo "  No markdown files found in $MARKDOWN_DIR"; break; }

    filename=$(basename "$md_file" .md)
    html_out="$HTML_DIR/$filename.html"

    # Extract front matter fields (title, date, tags)
    title=$(grep -m1 '^title:' "$md_file" | sed 's/^title:[[:space:]]*//')
    date=$(grep -m1 '^date:'  "$md_file" | sed 's/^date:[[:space:]]*//')
    tags=$(grep -m1 '^tags:'  "$md_file" | sed 's/^tags:[[:space:]]*//')

    title="${title:-Untitled}"
    date="${date:-Unknown date}"

    pandoc "$md_file" \
        --template="$TEMPLATE" \
        --metadata title="$title" \
        --metadata date="$date" \
        --metadata tags="$tags" \
        --highlight-style=monochrome \
        -o "$html_out"

    echo "  ✓ $filename.html  ($title)"

    # Store for index generation: sort key is raw date string
    POST_DATA+=("$date|$title|$filename")
done

# ── Sort posts by date (newest first) ─────────────────────────────────────────
# We rely on the date being parseable by `date -d`; fall back to file order otherwise.

sort_posts() {
    local -a sorted=()
    for entry in "${POST_DATA[@]}"; do
        raw_date="${entry%%|*}"
        epoch=$(date -d "$raw_date" +%s 2>/dev/null || echo 0)
        sorted+=("$epoch|$entry")
    done
    # Sort descending by epoch
    IFS=$'\n' sorted=($(printf '%s\n' "${sorted[@]}" | sort -rn))
    # Strip the epoch prefix
    POST_DATA=()
    for entry in "${sorted[@]}"; do
        POST_DATA+=("${entry#*|}")
    done
}

sort_posts

# ── Generate blogs/index.html ─────────────────────────────────────────────────

echo "Generating index..."

cat > "$INDEX" << 'HEREDOC'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blog</title>
    <link rel="stylesheet" href="../style.css">
</head>
<body>
    <nav class="sidebar">
        <h1>zenze's website</h1>
        <ul>
            <li><a href="../index.html">Home</a></li>
            <li><a href="../pages/projects.html">Projects</a></li>
            <li><a href="index.html">Blog</a></li>
            <li><a href="../pages/about.html">About</a></li>
        </ul>
HEREDOC

# Inject the last-updated timestamp
echo "        <p class=\"sidebar-updated\">Last updated: $(date '+%d %B %Y')</p>" >> "$INDEX"

cat >> "$INDEX" << 'HEREDOC'
    </nav>

    <main class="content">
        <h2>Blog</h2>
        <hr>
        <p>Thoughts, tutorials, and updates.</p>

        <table>
            <tr>
                <th>Sr.No</th>
                <th>Title</th>
                <th>Date</th>
            </tr>
HEREDOC

counter=1
for entry in "${POST_DATA[@]}"; do
    IFS='|' read -r date title filename <<< "$entry"
    cat >> "$INDEX" << HEREDOC
            <tr>
                <td>$counter</td>
                <td><a href="html/$filename.html">$title</a></td>
                <td>$date</td>
            </tr>
HEREDOC
    ((counter++))
done

cat >> "$INDEX" << 'HEREDOC'
        </table>

        <div class="footer">
            <p><a href="../index.html">Back to Home</a></p>
        </div>
    </main>
</body>
</html>
HEREDOC

echo "  ✓ blogs/index.html ($((counter - 1)) posts)"
echo ""
echo "Done! Blog built successfully."
