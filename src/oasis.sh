#!/bin/bash

# =============================================================================
# OASIS - Organized Automatic Sorting & Intelligent Structure
# A Downloads folder organizer for macOS
# =============================================================================

# Configuration - Change this to rename the app
APP_NAME="oasis"

# Paths (derived from APP_NAME)
CONFIG_DIR="$HOME/.config/$APP_NAME"
ENABLED_FILE="$CONFIG_DIR/enabled"
LOG_FILE="$CONFIG_DIR/oasis.log"
DOWNLOADS_DIR="$HOME/Downloads"

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

# Month name arrays
MONTH_NAMES=("" "January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December")
MONTH_ABBREV=("" "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")

# Get file's download date (when it was added to Downloads folder)
# Priority: kMDItemDateAdded > birth time > modification time
get_file_date() {
    local file="$1"
    local format="$2"  # "Y" for year, "m" for month, "d" for day, "Y-m-d" for full date

    # Try kMDItemDateAdded first (Spotlight metadata - most accurate for downloads)
    local date_added
    date_added=$(mdls -raw -name kMDItemDateAdded "$file" 2>/dev/null)

    if [[ -n "$date_added" && "$date_added" != "(null)" ]]; then
        # Parse the date (format: 2026-01-23 08:00:03 +0000)
        case "$format" in
            Y)    echo "$date_added" | cut -d'-' -f1 ;;
            m)    echo "$date_added" | cut -d'-' -f2 ;;
            d)    echo "$date_added" | cut -d'-' -f3 | cut -d' ' -f1 ;;
            Y-m-d) echo "$date_added" | cut -d' ' -f1 ;;
        esac
        return
    fi

    # Fallback to birth time (file creation on this filesystem)
    local birth_date
    birth_date=$(stat -f "%SB" -t "%Y-%m-%d" "$file" 2>/dev/null)

    if [[ -n "$birth_date" ]]; then
        case "$format" in
            Y)    echo "$birth_date" | cut -d'-' -f1 ;;
            m)    echo "$birth_date" | cut -d'-' -f2 ;;
            d)    echo "$birth_date" | cut -d'-' -f3 ;;
            Y-m-d) echo "$birth_date" ;;
        esac
        return
    fi

    # Last resort: modification time (original behavior)
    case "$format" in
        Y)    stat -f "%Sm" -t "%Y" "$file" 2>/dev/null ;;
        m)    stat -f "%Sm" -t "%m" "$file" 2>/dev/null ;;
        d)    stat -f "%Sm" -t "%d" "$file" 2>/dev/null ;;
        Y-m-d) stat -f "%Sm" -t "%Y-%m-%d" "$file" 2>/dev/null ;;
    esac
}

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

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

# Get number of days in a month
days_in_month() {
    local year="$1"
    local month="$2"
    # Note: -v flags must come before -f on macOS
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

# Format daily folder name: "Jan 14"
format_daily_name() {
    local month="$1"
    local day="$2"
    month=$((10#$month))
    day=$((10#$day))
    echo "${MONTH_ABBREV[$month]} $day"
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
move_file_safe() {
    local src="$1"
    local dest_dir="$2"
    local filename
    local base
    local extension
    local dest
    local counter=1

    filename=$(basename "$src")

    # Handle files with no extension
    if [[ "$filename" == *.* ]]; then
        base="${filename%.*}"
        extension=".${filename##*.}"
    else
        base="$filename"
        extension=""
    fi

    dest="$dest_dir/$filename"

    # If file exists, add number suffix
    while [[ -e "$dest" ]]; do
        dest="$dest_dir/${base} (${counter})${extension}"
        ((counter++))
    done

    mv "$src" "$dest" 2>/dev/null
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
        mkdir -p "$month_dir"
        log "Created month folder: $month_name"
    fi
}

organize_loose_files() {
    local today_date
    today_date=$(date "+%Y-%m-%d")
    local files_organized=0
    local days_with_files=()

    # Find all loose files in Downloads (not in subdirectories, not hidden)
    while IFS= read -r -d '' file; do
        # Skip if it's a directory
        [[ -d "$file" ]] && continue

        # Skip .DS_Store and other hidden files
        local filename
        filename=$(basename "$file")
        [[ "$filename" == .* ]] && continue

        # Skip partially downloaded files
        [[ "$filename" == *.crdownload ]] && continue
        [[ "$filename" == *.part ]] && continue
        [[ "$filename" == *.download ]] && continue

        # Get file's download date (when it was added to Downloads)
        local file_date
        file_date=$(get_file_date "$file" "Y-m-d")

        # Skip files added today (they stay loose until midnight)
        if [[ "$file_date" == "$today_date" ]]; then
            continue
        fi

        # Extract year, month, day from file's download date
        local file_year file_month file_day
        file_year=$(get_file_date "$file" "Y")
        file_month=$(get_file_date "$file" "m")
        file_day=$(get_file_date "$file" "d")

        # Format the daily folder name based on file's date
        local day_name
        day_name=$(format_daily_name "$file_month" "$file_day")
        local day_dir="$DOWNLOADS_DIR/$day_name"

        # Determine category
        local category
        category=$(get_category "$filename")

        # Create category directory if needed
        local category_dir="$day_dir/$category"
        mkdir -p "$category_dir"

        # Move file
        move_file_safe "$file" "$category_dir"
        ((files_organized++))

        # Track which days received files
        if [[ ! " ${days_with_files[*]} " =~ " ${day_name} " ]]; then
            days_with_files+=("$day_name")
        fi

    done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -type f -print0 2>/dev/null)

    # Clean up empty category directories in any daily folders we touched
    for day_name in "${days_with_files[@]}"; do
        local day_dir="$DOWNLOADS_DIR/$day_name"
        if [[ -d "$day_dir" ]]; then
            find "$day_dir" -type d -empty -delete 2>/dev/null
        fi
        # Remove day directory if it's empty
        if [[ -d "$day_dir" ]] && [[ -z "$(ls -A "$day_dir" 2>/dev/null)" ]]; then
            rmdir "$day_dir" 2>/dev/null
        fi
    done

    if [[ $files_organized -gt 0 ]]; then
        log "Organized $files_organized files from previous days"
    else
        log "No files from previous days to organize"
    fi
}

rollup_daily_to_weekly() {
    local current_year current_month current_day
    current_year=$(date "+%Y")
    current_month=$(date "+%m")
    current_day=$(date "+%d")

    local today_name
    today_name=$(format_daily_name "$current_month" "$current_day")

    # Find all daily folders matching pattern "Mon D" or "Mon DD" (e.g., "Jan 14")
    while IFS= read -r -d '' day_dir; do
        local dirname
        dirname=$(basename "$day_dir")

        # Skip today's folder
        [[ "$dirname" == "$today_name" ]] && continue

        # Parse the folder name to extract month and day
        # Expected format: "Jan 14" or "Jan 1"
        if [[ "$dirname" =~ ^([A-Z][a-z]{2})\ ([0-9]{1,2})$ ]]; then
            local month_abbr="${BASH_REMATCH[1]}"
            local day_num="${BASH_REMATCH[2]}"

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

            # Determine year (assume current year, or previous year if month > current month)
            local year="$current_year"
            if [[ "$month_num" -gt "$((10#$current_month))" ]]; then
                year=$((current_year - 1))
            fi

            # Get week info
            local week_info
            week_info=$(get_week_info "$year" "$(printf '%02d' $month_num)" "$day_num")
            local week_num week_start week_end
            week_num=$(echo "$week_info" | cut -d'|' -f1)
            week_start=$(echo "$week_info" | cut -d'|' -f2)
            week_end=$(echo "$week_info" | cut -d'|' -f3)

            # Format week folder name
            local week_name
            week_name=$(format_weekly_name "$(printf '%02d' $month_num)" "$week_num" "$week_start" "$week_end")
            local week_dir="$DOWNLOADS_DIR/$week_name"

            # Create week folder if it doesn't exist
            mkdir -p "$week_dir"

            # Move day folder into week folder
            mv "$day_dir" "$week_dir/" 2>/dev/null
            log "Moved $dirname to $week_name"
        fi

    done < <(find "$DOWNLOADS_DIR" -maxdepth 1 -type d -print0 2>/dev/null)
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

            # Determine year (assume current year, or previous year if month > current month)
            local year="$current_year"
            if [[ "$month_num" -gt "$current_month" ]]; then
                year=$((current_year - 1))
            fi

            # Check if the week is complete (today is past the week's end date)
            # A week is complete if we're past that week's end day
            local week_complete=false
            if [[ "$month_num" -lt "$current_month" ]]; then
                # Previous month - week is complete
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

            # Create month folder and move week into it
            mkdir -p "$month_dir"
            mv "$week_dir" "$month_dir/" 2>/dev/null
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

cmd_run() {
    # Ensure config directory exists
    mkdir -p "$CONFIG_DIR"

    # Check if enabled
    if ! is_enabled; then
        log "OASIS is disabled. Skipping."
        echo "OASIS is disabled. Run 'oasis enable' to enable."
        exit 0
    fi

    log "Starting OASIS organization run..."

    # Step 1: Ensure current month folder exists
    ensure_month_folder

    # Step 2: Organize loose files from previous days (today's files stay loose)
    organize_loose_files

    # Step 3: Roll up completed days into week folders
    rollup_daily_to_weekly

    # Step 4: Roll up completed weeks into month folders
    rollup_weekly_to_monthly

    log "OASIS organization complete."
}

cmd_help() {
    echo "OASIS - Downloads Folder Organizer"
    echo ""
    echo "Usage: oasis [command]"
    echo ""
    echo "Commands:"
    echo "  run      Organize Downloads folder now (default if no command)"
    echo "  enable   Enable automatic organization"
    echo "  disable  Disable automatic organization"
    echo "  toggle   Toggle between enabled/disabled"
    echo "  status   Show current status"
    echo "  help     Show this help message"
    echo ""
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    local command="${1:-run}"

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
        run)
            cmd_run
            ;;
        help|--help|-h)
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
