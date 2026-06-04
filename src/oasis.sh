#!/bin/bash

# =============================================================================
# OASIS - Organized Automatic Sorting & Intelligent Structure
# A Downloads folder organizer for macOS
# Version: 1.3.0
# =============================================================================

VERSION="1.3.0"

# Configuration - Change this to rename the app
APP_NAME="oasis"

# Paths (derived from APP_NAME)
CONFIG_DIR="$HOME/.config/$APP_NAME"
ENABLED_FILE="$CONFIG_DIR/enabled"
LOG_FILE="$CONFIG_DIR/oasis.log"
DOWNLOADS_DIR="$HOME/Downloads"

# Log rotation settings
MAX_LOG_LINES=1000

# Dry-run mode (set via --dry-run flag)
DRY_RUN=false

# Safety check: ensure critical variables are set
if [[ -z "$HOME" ]] || [[ ! -d "$HOME" ]]; then
    echo "Error: HOME directory not set or does not exist" >&2
    exit 1
fi

if [[ ! -d "$DOWNLOADS_DIR" ]]; then
    echo "Error: Downloads directory does not exist: $DOWNLOADS_DIR" >&2
    exit 1
fi

# =============================================================================
# File Extension Categories
# =============================================================================

IMAGES_EXT="jpg jpeg png gif webp svg ico bmp tiff tif heic heif raw psd ai eps"
DOCUMENTS_EXT="pdf doc docx xls xlsx ppt pptx txt rtf odt ods odp pages numbers keynote md markdown csv json xml html htm"
VIDEOS_EXT="mp4 mov avi mkv wmv flv webm m4v mpeg mpg 3gp"
AUDIO_EXT="mp3 wav aac flac ogg m4a wma aiff aif alac"

# Partial download patterns to skip
PARTIAL_PATTERNS="crdownload part download partial tmp"

# Month name arrays
MONTH_NAMES=("" "January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December")
MONTH_ABBREV=("" "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")

# =============================================================================
# Logging Functions
# =============================================================================

log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] $message"
    else
        echo "$message" >> "$LOG_FILE"
    fi
}

# Rotate log file if it exceeds MAX_LOG_LINES
rotate_log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        return
    fi

    local line_count
    line_count=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -d ' ')

    if [[ "$line_count" -gt "$MAX_LOG_LINES" ]]; then
        # Keep the last MAX_LOG_LINES lines
        local temp_file
        temp_file=$(mktemp)
        tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$temp_file"
        mv "$temp_file" "$LOG_FILE"
    fi
}

# =============================================================================
# File Date Functions
# =============================================================================

# Get file's download date (when it was added to Downloads folder)
# Returns: YYYY-MM-DD in local time
# Priority: kMDItemDateAdded > birth time > modification time
get_file_date() {
    local file="$1"

    # Try kMDItemDateAdded first (Spotlight metadata - most accurate for downloads)
    local date_added
    date_added=$(mdls -raw -name kMDItemDateAdded "$file" 2>/dev/null)

    if [[ -n "$date_added" && "$date_added" != "(null)" ]]; then
        # Convert UTC timestamp to local time (Spotlight returns UTC like "2026-01-26 05:53:54 +0000")
        local local_date
        local_date=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$date_added" "+%Y-%m-%d" 2>/dev/null)

        if [[ -n "$local_date" ]]; then
            echo "$local_date"
            return
        fi
    fi

    # Fallback to birth time (file creation on this filesystem)
    local birth_date
    birth_date=$(stat -f "%SB" -t "%Y-%m-%d" "$file" 2>/dev/null)

    if [[ -n "$birth_date" ]]; then
        echo "$birth_date"
        return
    fi

    # Last resort: modification time
    stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null
}

# Parse date components from YYYY-MM-DD format
parse_date_year()  { echo "${1:0:4}"; }
parse_date_month() { echo "${1:5:2}"; }
parse_date_day()   { echo "${1:8:2}"; }

# =============================================================================
# Helper Functions
# =============================================================================

is_enabled() {
    if [[ -f "$ENABLED_FILE" ]]; then
        local status
        status=$(cat "$ENABLED_FILE" | tr -d '[:space:]')
        [[ "$status" == "true" ]]
    else
        # Default to enabled if no config file exists
        return 0
    fi
}

get_category() {
    local ext="${1##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    if [[ " $IMAGES_EXT " == *" $ext "* ]]; then
        echo "Images"
    elif [[ " $DOCUMENTS_EXT " == *" $ext "* ]]; then
        echo "Documents"
    elif [[ " $VIDEOS_EXT " == *" $ext "* ]]; then
        echo "Videos"
    elif [[ " $AUDIO_EXT " == *" $ext "* ]]; then
        echo "Audio"
    else
        echo "Other"
    fi
}

# Check if a folder name is one of OASIS's own structural folders (week or
# month folders). These must never be re-sorted into a category bucket.
is_oasis_folder() {
    local name="$1"

    # Week folder: "Week 1 (Jun 1-7)"
    if [[ "$name" =~ ^Week\ [0-9]+\ \([A-Z][a-z]{2}\ [0-9]+-[0-9]+\)$ ]]; then
        return 0
    fi

    # Month folder: "January 2026"
    local m
    for m in "${MONTH_NAMES[@]}"; do
        [[ -z "$m" ]] && continue
        if [[ "$name" == "$m "[0-9][0-9][0-9][0-9] ]]; then
            return 0
        fi
    done

    return 1
}

# Check if file is a partial/in-progress download
is_partial_download() {
    local filename="$1"
    local ext="${filename##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    # Check extension-based patterns
    for pattern in $PARTIAL_PATTERNS; do
        if [[ "$ext" == "$pattern" ]]; then
            return 0
        fi
    done

    # Check for ~ suffix (used by some apps for temp files)
    if [[ "$filename" == *"~" ]]; then
        return 0
    fi

    return 1
}

# Get number of days in a month
days_in_month() {
    local year="$1"
    local month="$2"
    date -j -v+1m -v-1d -f "%Y-%m-%d" "${year}-${month}-01" "+%d" 2>/dev/null
}

# Get week info for a given date
# Returns: week_num|week_start_day|week_end_day
get_week_info() {
    local year="$1"
    local month="$2"
    local day="$3"

    # Remove leading zeros for arithmetic
    day=$((10#$day))
    month=$((10#$month))

    # Get day of week for the 1st of the month (1=Mon, 7=Sun)
    local first_day_dow
    first_day_dow=$(date -j -f "%Y-%m-%d" "${year}-$(printf '%02d' $month)-01" "+%u" 2>/dev/null)

    # Get total days in month
    local total_days
    total_days=$(days_in_month "$year" "$(printf '%02d' $month)")
    total_days=$((10#$total_days))

    # Calculate days in week 1 (1st through first Sunday)
    local days_in_week1
    if [[ "$first_day_dow" -eq 7 ]]; then
        days_in_week1=1
    else
        days_in_week1=$((7 - first_day_dow + 1))
    fi

    local week_num week_start week_end

    if [[ "$day" -le "$days_in_week1" ]]; then
        week_num=1
        week_start=1
        week_end=$days_in_week1
    else
        # Calculate which week (2, 3, 4, or 5)
        local remaining=$((day - days_in_week1))
        week_num=$(( (remaining - 1) / 7 + 2 ))

        # Calculate start and end of this week
        week_start=$((days_in_week1 + (week_num - 2) * 7 + 1))
        week_end=$((week_start + 6))

        # Cap at end of month
        if [[ "$week_end" -gt "$total_days" ]]; then
            week_end=$total_days
        fi
    fi

    echo "${week_num}|${week_start}|${week_end}"
}

# Format weekly folder name: "Week 1 (Jan 1-5)"
format_weekly_name() {
    local month="$1"
    local week_num="$2"
    local start_day="$3"
    local end_day="$4"
    month=$((10#$month))
    echo "Week $week_num (${MONTH_ABBREV[$month]} $start_day-$end_day)"
}

# Format monthly folder name: "January 2026"
format_monthly_name() {
    local year="$1"
    local month="$2"
    month=$((10#$month))
    echo "${MONTH_NAMES[$month]} $year"
}

# Move file with conflict handling (adds number suffix if exists)
# Also handles very long filenames by truncating if needed
move_file_safe() {
    local src="$1"
    local dest_dir="$2"
    local filename base extension dest
    local counter=1
    local max_name_length=255

    filename=$(basename "$src")

    # Handle files with no extension or ending with dot
    if [[ "$filename" == *.* && "$filename" != *. ]]; then
        base="${filename%.*}"
        extension=".${filename##*.}"
    else
        base="$filename"
        extension=""
    fi

    # Truncate base name if too long (leave room for suffix and extension)
    local suffix_space=10  # Room for " (999)" type suffixes
    local max_base=$((max_name_length - ${#extension} - suffix_space))
    if [[ ${#base} -gt $max_base ]]; then
        base="${base:0:$max_base}"
    fi

    dest="$dest_dir/${base}${extension}"

    # If file exists, add number suffix
    while [[ -e "$dest" ]]; do
        dest="$dest_dir/${base} (${counter})${extension}"
        ((counter++))

        # Safety: prevent infinite loop
        if [[ $counter -gt 9999 ]]; then
            log "Error: Too many conflicting filenames for $filename"
            return 1
        fi
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would move: $src -> $dest"
    else
        mv "$src" "$dest" 2>/dev/null
    fi
}

# Move a directory into dest_dir, handling name conflicts by appending a
# numeric suffix. Keeps the full folder name intact (no extension splitting).
move_dir_safe() {
    local src="$1"
    local dest_dir="$2"
    local name dest
    local counter=1

    name=$(basename "$src")
    dest="$dest_dir/$name"

    # If a folder with the same name exists, add a number suffix
    while [[ -e "$dest" ]]; do
        dest="$dest_dir/${name} (${counter})"
        ((counter++))

        # Safety: prevent infinite loop
        if [[ $counter -gt 9999 ]]; then
            log "Error: Too many conflicting folder names for $name"
            return 1
        fi
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would move folder: $src -> $dest"
    else
        mv "$src" "$dest" 2>/dev/null
    fi
}

# Merge source folder into destination folder
# Handles case where destination already exists
merge_folders() {
    local src_dir="$1"
    local dest_parent="$2"
    local folder_name
    folder_name=$(basename "$src_dir")
    local dest_dir="$dest_parent/$folder_name"

    if [[ ! -d "$dest_dir" ]]; then
        # Destination doesn't exist, simple move
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  Would move folder: $src_dir -> $dest_dir"
        else
            mv "$src_dir" "$dest_parent/" 2>/dev/null
        fi
    else
        # Destination exists, merge contents
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  Would merge folder: $src_dir into $dest_dir"
        else
            # Move each item from source to destination
            find "$src_dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | while IFS= read -r -d '' item; do
                local item_name
                item_name=$(basename "$item")

                if [[ -d "$item" ]]; then
                    # Recursively merge subdirectories
                    merge_folders "$item" "$dest_dir"
                else
                    # Move file with conflict handling
                    move_file_safe "$item" "$dest_dir"
                fi
            done

            # Remove source directory if empty
            rmdir "$src_dir" 2>/dev/null || true
        fi
    fi
}

# =============================================================================
# Main Organization Functions
# =============================================================================

ensure_month_folder() {
    local year month
    year=$(date "+%Y")
    month=$(date "+%m")

    local month_name
    month_name=$(format_monthly_name "$year" "$month")
    local month_dir="$DOWNLOADS_DIR/$month_name"

    if [[ ! -d "$month_dir" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  Would create month folder: $month_name"
        else
            mkdir -p "$month_dir"
            log "Created month folder: $month_name"
        fi
    fi
}

organize_loose_files() {
    local today_date
    today_date=$(date "+%Y-%m-%d")
    local items_organized=0
    local weeks_with_files=()

    # Find all loose items in the Downloads root — files and folders, not hidden.
    # -mindepth 1 excludes the Downloads dir itself; symlinks are ignored.
    while IFS= read -r -d '' item; do
        # Skip .DS_Store and other hidden items
        local itemname
        itemname=$(basename "$item")
        [[ "$itemname" == .* ]] && continue

        # Skip partial/in-progress downloads (covers Safari ".download" bundles)
        if is_partial_download "$itemname"; then
            continue
        fi

        # Pick the destination category. Directories go in the "Folders" bucket
        # (kept whole, not scanned); files are categorized by extension. OASIS's
        # own week/month folders are left untouched.
        local category
        if [[ -d "$item" ]]; then
            if is_oasis_folder "$itemname"; then
                continue
            fi
            category="Folders"
        else
            category=$(get_category "$itemname")
        fi

        # Get the item's download date (single call - optimized)
        local file_date
        file_date=$(get_file_date "$item")

        # Skip items with undeterminable dates
        if [[ -z "$file_date" || ! "$file_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            log "Warning: Could not determine date for $itemname, skipping"
            continue
        fi

        # Skip items added today (they stay loose until midnight)
        if [[ "$file_date" == "$today_date" ]]; then
            continue
        fi

        # Parse date components from single get_file_date call
        local file_year file_month file_day
        file_year=$(parse_date_year "$file_date")
        file_month=$(parse_date_month "$file_date")
        file_day=$(parse_date_day "$file_date")

        # Determine which week of the month this item belongs to
        local week_info week_num week_start week_end
        week_info=$(get_week_info "$file_year" "$file_month" "$file_day")
        week_num=$(echo "$week_info" | cut -d'|' -f1)
        week_start=$(echo "$week_info" | cut -d'|' -f2)
        week_end=$(echo "$week_info" | cut -d'|' -f3)

        # Format the weekly folder name based on the item's date
        local week_name
        week_name=$(format_weekly_name "$file_month" "$week_num" "$week_start" "$week_end")
        local week_dir="$DOWNLOADS_DIR/$week_name"

        # Create category directory if needed
        local category_dir="$week_dir/$category"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  Would organize: $itemname -> $week_name/$category/"
        else
            mkdir -p "$category_dir"
        fi

        # Move the item (folder-aware for directories)
        if [[ -d "$item" ]]; then
            move_dir_safe "$item" "$category_dir"
        else
            move_file_safe "$item" "$category_dir"
        fi
        ((items_organized++))

        # Track which week folders received items (for cleanup)
        local already_tracked=false
        local w
        for w in "${weeks_with_files[@]}"; do
            if [[ "$w" == "$week_name" ]]; then
                already_tracked=true
                break
            fi
        done
        if [[ "$already_tracked" == false ]]; then
            weeks_with_files+=("$week_name")
        fi

    done < <(find "$DOWNLOADS_DIR" -mindepth 1 -maxdepth 1 \( -type f -o -type d \) -print0 2>/dev/null)

    # Clean up empty category directories in any week folders we touched.
    # Only top-level category dirs are removed — never the contents of a moved
    # folder, so an empty downloaded folder still survives in the Folders bucket.
    if [[ "$DRY_RUN" != "true" ]]; then
        for week_name in "${weeks_with_files[@]}"; do
            local week_dir="$DOWNLOADS_DIR/$week_name"
            if [[ -d "$week_dir" ]]; then
                find "$week_dir" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null
            fi
            # Remove week directory if it ended up empty
            if [[ -d "$week_dir" ]] && [[ -z "$(ls -A "$week_dir" 2>/dev/null)" ]]; then
                rmdir "$week_dir" 2>/dev/null
            fi
        done
    fi

    if [[ $items_organized -gt 0 ]]; then
        log "Organized $items_organized items from previous days"
    else
        log "No files or folders from previous days to organize"
    fi
}

# Migration helper: flatten any pre-existing daily folders ("Mon D") created by
# older OASIS versions into their weekly folder's category subfolders.
# Idempotent — once no daily folders remain, this does nothing.
flatten_daily_folders() {
    local current_year current_month current_day
    current_year=$(date "+%Y")
    current_month=$((10#$(date "+%m")))
    current_day=$((10#$(date "+%d")))

    # Collect daily folders first so we don't mutate the tree mid-traversal.
    # Daily folders may sit at the Downloads root or nested inside a week folder.
    local day_dirs=()
    local d
    while IFS= read -r -d '' d; do
        day_dirs+=("$d")
    done < <(find "$DOWNLOADS_DIR" -mindepth 1 -type d -print0 2>/dev/null)

    local day_dir
    for day_dir in "${day_dirs[@]}"; do
        # May have already been moved/removed by an earlier iteration
        [[ -d "$day_dir" ]] || continue

        local dirname
        dirname=$(basename "$day_dir")

        # Match daily folder pattern "Mon D" or "Mon DD" (e.g., "Jan 14")
        [[ "$dirname" =~ ^([A-Z][a-z]{2})\ ([0-9]{1,2})$ ]] || continue
        local month_abbr="${BASH_REMATCH[1]}"
        local day_num="${BASH_REMATCH[2]}"

        # Find month number from abbreviation
        local month_num=0
        local i
        for i in {1..12}; do
            if [[ "${MONTH_ABBREV[$i]}" == "$month_abbr" ]]; then
                month_num=$i
                break
            fi
        done
        [[ "$month_num" -eq 0 ]] && continue

        # Determine the destination week folder
        local parent_dir parent_name week_dir
        parent_dir=$(dirname "$day_dir")
        parent_name=$(basename "$parent_dir")

        if [[ "$parent_name" =~ ^Week\ [0-9]+\ \( ]]; then
            # Already nested inside a week folder — flatten straight into it
            week_dir="$parent_dir"
        else
            # Compute the week folder and place it beside the daily folder
            local folder_mtime_year year
            folder_mtime_year=$(stat -f "%Sm" -t "%Y" "$day_dir" 2>/dev/null)
            year="$current_year"
            if [[ -n "$folder_mtime_year" && "$folder_mtime_year" != "$current_year" ]]; then
                year="$folder_mtime_year"
            elif [[ "$month_num" -gt "$current_month" ]]; then
                year=$((current_year - 1))
            elif [[ "$month_num" -eq "$current_month" && "$day_num" -gt "$current_day" ]]; then
                year=$((current_year - 1))
            fi

            local week_info week_num week_start week_end week_name
            week_info=$(get_week_info "$year" "$(printf '%02d' $month_num)" "$day_num")
            week_num=$(echo "$week_info" | cut -d'|' -f1)
            week_start=$(echo "$week_info" | cut -d'|' -f2)
            week_end=$(echo "$week_info" | cut -d'|' -f3)
            week_name=$(format_weekly_name "$(printf '%02d' $month_num)" "$week_num" "$week_start" "$week_end")
            week_dir="$parent_dir/$week_name"
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  Would flatten daily folder: $dirname -> $(basename "$week_dir")/"
        else
            mkdir -p "$week_dir"
        fi

        # Move the daily folder's category subfolders (and any stray files) up
        # into the week folder, merging with any existing categories.
        find "$day_dir" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | while IFS= read -r -d '' item; do
            if [[ -d "$item" ]]; then
                merge_folders "$item" "$week_dir"
            else
                move_file_safe "$item" "$week_dir"
            fi
        done

        # Remove the now-empty daily folder
        if [[ "$DRY_RUN" != "true" ]]; then
            rmdir "$day_dir" 2>/dev/null || true
        fi
        log "Flattened daily folder $dirname into $(basename "$week_dir")"
    done
}

rollup_weekly_to_monthly() {
    local current_year current_month current_day
    current_year=$(date "+%Y")
    current_month=$((10#$(date "+%m")))
    current_day=$((10#$(date "+%d")))

    # Find all week folders matching pattern "Week N (Mon D-D)"
    while IFS= read -r -d '' week_dir; do
        local week_name
        week_name=$(basename "$week_dir")

        # Parse week folder name: "Week 1 (Jan 1-5)"
        if [[ "$week_name" =~ ^Week\ ([0-9]+)\ \(([A-Z][a-z]{2})\ ([0-9]+)-([0-9]+)\)$ ]]; then
            local week_num="${BASH_REMATCH[1]}"
            local month_abbr="${BASH_REMATCH[2]}"
            local start_day="${BASH_REMATCH[3]}"
            local end_day="${BASH_REMATCH[4]}"

            # Find month number from abbreviation
            local month_num=0
            for i in {1..12}; do
                if [[ "${MONTH_ABBREV[$i]}" == "$month_abbr" ]]; then
                    month_num=$i
                    break
                fi
            done

            if [[ "$month_num" -eq 0 ]]; then
                continue
            fi

            # Determine year using folder modification time
            local folder_mtime_year
            folder_mtime_year=$(stat -f "%Sm" -t "%Y" "$week_dir" 2>/dev/null)

            local year="$current_year"

            # If folder was modified in a different year, use that
            if [[ -n "$folder_mtime_year" && "$folder_mtime_year" != "$current_year" ]]; then
                year="$folder_mtime_year"
            # Otherwise use month comparison
            elif [[ "$month_num" -gt "$current_month" ]]; then
                year=$((current_year - 1))
            fi

            # Check if the week is complete (today is past the week's end date)
            local week_complete=false
            if [[ "$year" -lt "$current_year" ]]; then
                # Previous year - week is definitely complete
                week_complete=true
            elif [[ "$month_num" -lt "$current_month" ]]; then
                # Previous month in current year - week is complete
                week_complete=true
            elif [[ "$month_num" -eq "$current_month" ]] && [[ "$current_day" -gt "$end_day" ]]; then
                # Current month but we're past the week's end day
                week_complete=true
            fi

            if [[ "$week_complete" != "true" ]]; then
                continue
            fi

            # Format month folder name
            local month_name
            month_name=$(format_monthly_name "$year" "$(printf '%02d' $month_num)")
            local month_dir="$DOWNLOADS_DIR/$month_name"

            # Create month folder if needed
            if [[ "$DRY_RUN" != "true" ]]; then
                mkdir -p "$month_dir"
            fi

            # Merge week folder into month folder (handles existing folders)
            merge_folders "$week_dir" "$month_dir"
            log "Moved $week_name to $month_name"
        fi

    done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -type d -name "Week *" -print0 2>/dev/null)
}

# =============================================================================
# Command Functions
# =============================================================================

cmd_enable() {
    mkdir -p "$CONFIG_DIR"
    echo "true" > "$ENABLED_FILE"
    echo "OASIS enabled"
}

cmd_disable() {
    mkdir -p "$CONFIG_DIR"
    echo "false" > "$ENABLED_FILE"
    echo "OASIS disabled"
}

cmd_toggle() {
    mkdir -p "$CONFIG_DIR"
    if is_enabled; then
        echo "false" > "$ENABLED_FILE"
        echo "OASIS disabled"
    else
        echo "true" > "$ENABLED_FILE"
        echo "OASIS enabled"
    fi
}

cmd_status() {
    if is_enabled; then
        echo "OASIS is enabled"
    else
        echo "OASIS is disabled"
    fi
}

cmd_version() {
    echo "OASIS version $VERSION"
}

cmd_run() {
    # Ensure config directory exists
    mkdir -p "$CONFIG_DIR"

    # Rotate log if needed
    rotate_log

    # Check if enabled
    if ! is_enabled; then
        log "OASIS is disabled. Skipping."
        if [[ "$DRY_RUN" != "true" ]]; then
            echo "OASIS is disabled. Run 'oasis enable' to enable."
        fi
        exit 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "=== DRY RUN MODE - No changes will be made ==="
        echo ""
    fi

    log "Starting OASIS organization run..."

    # Step 1: Ensure current month folder exists
    ensure_month_folder

    # Step 2: Organize loose files from previous days into weekly folders
    #         (today's files stay loose until the next midnight run)
    organize_loose_files

    # Step 3: Flatten any legacy daily folders into their weekly folder
    flatten_daily_folders

    # Step 4: Roll up completed weeks into month folders
    rollup_weekly_to_monthly

    log "OASIS organization complete."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "=== DRY RUN COMPLETE ==="
    fi
}

cmd_help() {
    echo "OASIS - Downloads Folder Organizer (v$VERSION)"
    echo ""
    echo "Usage: oasis [command] [options]"
    echo ""
    echo "Commands:"
    echo "  run         Organize Downloads folder now (default)"
    echo "  enable      Enable automatic organization"
    echo "  disable     Disable automatic organization"
    echo "  toggle      Toggle between enabled/disabled"
    echo "  status      Show current status"
    echo "  version     Show version number"
    echo "  help        Show this help message"
    echo ""
    echo "Options:"
    echo "  --dry-run   Preview changes without making them"
    echo ""
    echo "Examples:"
    echo "  oasis run              # Organize now"
    echo "  oasis run --dry-run    # Preview what would be organized"
    echo "  oasis status           # Check if enabled"
    echo ""
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    local command="run"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            enable|disable|toggle|status|run|version|help|--help|-h)
                command="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                cmd_help
                exit 1
                ;;
        esac
    done

    # Handle help aliases
    if [[ "$command" == "--help" || "$command" == "-h" ]]; then
        command="help"
    fi

    case "$command" in
        enable)
            cmd_enable
            ;;
        disable)
            cmd_disable
            ;;
        toggle)
            cmd_toggle
            ;;
        status)
            cmd_status
            ;;
        version)
            cmd_version
            ;;
        run)
            cmd_run
            ;;
        help)
            cmd_help
            ;;
        *)
            echo "Unknown command: $command"
            cmd_help
            exit 1
            ;;
    esac
}

# Run main
main "$@"
