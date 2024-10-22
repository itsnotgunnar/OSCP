#!/usr/bin/env bash

# Color codes
RED='\e[91m'
GREEN='\e[38;5;300m'
YELLOW='\e[93m'
BLUE='\e[38;5;204m'
MAGENTA='\e[95m'
FLASH='\e[98;5;208m'
ORANGE='\e[38;5;208m'
CYAN='\e[94m'
BOLD='\e[1m'
RESET='\e[0m'
PINK='\e[38;5;204m'

####################################################################################################################################### BANNER ###########################################################################################################################################################################################################################################################################################################################################

echo
echo -e "${RESET}${CYAN}                                                                                         "
echo -e "                                                                                         "
echo -e "     ${FLASH}${ORANGE}########${RESET}${CYAN}  ${FLASH}${ORANGE}##${RESET}${CYAN}           ${FLASH}${ORANGE}###${RESET}${CYAN}     ${FLASH}${ORANGE}########${RESET}${CYAN}   ${FLASH}${ORANGE}########${RESET}${CYAN}              ${FLASH}${ORANGE}##${RESET}${CYAN}   ${BOLD}${FLASH}${RED}####${RESET}${CYAN}           "
echo -e "    ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}       ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}          ${FLASH}${ORANGE}## ##${RESET}${CYAN}   ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}     ${FLASH}${ORANGE}##${RESET}${CYAN}  ${FLASH}${ORANGE}##${RESET}${CYAN}                   ${FLASH}${ORANGE}##${RESET}${CYAN}   ${BOLD}${FLASH}${RED}##  ${BOLD}${FLASH}${RED}##${RESET}${CYAN}  ${BOLD}${FLASH}${RED}##${RESET}${CYAN}      "
echo -e "    ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}       ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}         ${FLASH}${ORANGE}##${RESET}${CYAN}   ${FLASH}${ORANGE}##${RESET}${CYAN}  ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}    ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}  ${FLASH}${ORANGE}##${RESET}${CYAN}                  ${FLASH}${ORANGE}##${RESET}${CYAN}         ${BOLD}${FLASH}${RED}####${RESET}${CYAN}       "
echo -e "     ${FLASH}${ORANGE}######${RESET}${CYAN}   ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}        ${FLASH}${ORANGE}##${RESET}${CYAN}     ${FLASH}${ORANGE}##${RESET}${CYAN}  ${FLASH}${ORANGE}########${RESET}${CYAN}   ${FLASH}${ORANGE}######${RESET}${CYAN}             ${FLASH}${ORANGE}##${RESET}${CYAN}                     "
echo -e "    ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}       ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}        ${FLASH}${ORANGE}#########${RESET}${CYAN} ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}   ${FLASH}${ORANGE}##${RESET}${CYAN}   ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}                ${FLASH}${ORANGE}##${RESET}${CYAN}                      "
echo -e "    ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}       ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}       ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}     ${FLASH}${ORANGE}##${RESET}${CYAN} ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}    ${FLASH}${ORANGE}##${RESET}${CYAN}  ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}               ${FLASH}${ORANGE}##${RESET}${CYAN}                       "
echo -e "    ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}        ${FLASH}${ORANGE}########${RESET}${CYAN} ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}    ${FLASH}${ORANGE} ${FLASH}${ORANGE}##${RESET}${CYAN}  ${FLASH}${ORANGE}##${RESET}${CYAN}     ${FLASH}${ORANGE}##${RESET}${CYAN}  ${FLASH}${ORANGE}########${RESET}${CYAN}        ${FLASH}${ORANGE}##${RESET}${CYAN}                        "
echo -e "                                                                                         "
echo -e "                                                                                         ${RESET}"
echo

##########################################################################################################################################################################################################################################################################################################################################################################################################################################################################################

# Define users to analyze (users with valid login shells)
USERS=$( awk -F: '/sh$/{print $1}' /etc/passwd 2>/dev/null )

# Define directories to exclude to improve performance and reduce irrelevant data
EXCLUDE_DIRS=( "/proc/*" "/sys/*" "/run/*" "/var/lib/*" "/var/run/*" "/var/cache/*" "/var/tmp/*" "/var/log/journal/*" "/lib/*" "/usr/lib*/*" "/lib64/*" "/snap/*" "/boot/*" )

# Convert EXCLUDE_DIRS into find command parameters
FIND_EXCLUDES=()
for DIR in "${EXCLUDE_DIRS[@]}"; do
    FIND_EXCLUDES+=(-path "$DIR" -prune -o)
done

# Output directory for results
OUTPUT_DIR="/dev/shm/filesystem_analysis"
mkdir -p "$OUTPUT_DIR"

# 1. Find Files Owned by Users (Or User's Group) in Directories Owned by Others
find_files_in_foreign_dirs() {
    echo -e "${GREEN}1. Finding files owned by users (or their groups) in directories owned by others...${RESET}"

    for USER in $USERS; do
        OUTPUT_FILE="$OUTPUT_DIR/${USER}_files_in_foreign_dirs.txt"
        : > "$OUTPUT_FILE"  # Clear previous output

        # Get all group IDs the user belongs to
        USER_GROUP_IDS=$(id -G "$USER")

        # Build the find command to find files owned by the user or their groups
        FIND_CMD=(find /)
        FIND_CMD+=("${FIND_EXCLUDES[@]}")
        FIND_CMD+=(-type f \( -user "$USER")

        for GID in $USER_GROUP_IDS; do
            FIND_CMD+=( -o -group "$GID" )
        done

        FIND_CMD+=( \) -print )

        # Execute find command
        "${FIND_CMD[@]}" 2>/dev/null | while read -r FILE; do
            # Get file's owner and group IDs
            FILE_UID=$(stat -c "%u" "$FILE" 2>/dev/null)
            FILE_GID=$(stat -c "%g" "$FILE" 2>/dev/null)

            # Get directory's owner and group IDs
            DIR_PATH=$(dirname "$FILE")
            DIR_UID=$(stat -c "%u" "$DIR_PATH" 2>/dev/null)
            DIR_GID=$(stat -c "%g" "$DIR_PATH" 2>/dev/null)

            # Check if directory's owner or group differs from file's owner or group
            if [[ "$DIR_UID" != "$FILE_UID" || "$DIR_GID" != "$FILE_GID" ]]; then
                echo "$FILE (File UID:GID $FILE_UID:$FILE_GID, Directory UID:GID $DIR_UID:$DIR_GID)" >> "$OUTPUT_FILE"
            fi
        done
    done

    echo -e "${PINK}Files in foreign directories saved in $OUTPUT_DIR/*_files_in_foreign_dirs.txt${RESET}"
    echo
}

# 2. Find Files with Permissions Differing from Their Owning Directory
find_files_with_permission_anomalies() {
    echo -e "${GREEN}2. Finding files with permissions differing from their owning directory...${RESET}"

    OUTPUT_FILE="$OUTPUT_DIR/permission_anomalies.txt"
    : > "$OUTPUT_FILE"  # Clear previous output

    # Build find exclusion parameters
    FIND_EXCLUDES=()
    for DIR in "${EXCLUDE_DIRS[@]}"; do
        FIND_EXCLUDES+=(! -path "$DIR")
    done

    FIND_EXCLUDES+=(! -path "/usr/lib*/*" ! -path "/usr/share/*")

    # Find files and compare permissions
    find / -type f "${FIND_EXCLUDES[@]}" 2>/dev/null | grep -v "/proc\|modules\|journal\|package\|python\|boot\|cache\|/default\|themes\|/docs\|\.npm\|vendor\|/core/*\|locale\|/doc/\|/mime/\|/man/\|/etc/php-zts.d\|/sys/module/\|font\|help\|/licenses\|/usr/lib/firmware\|/usr/lib/firewalld\|crypto-policies" | while read -r FILE; do
        DIR_PATH=$(dirname "$FILE")
        DIR_PERMS=$(stat -c "%a" "$DIR_PATH" 2>/dev/null)
        FILE_PERMS=$(stat -c "%a" "$FILE" 2>/dev/null)
        if [[ "$DIR_PERMS" && "$FILE_PERMS" && "$DIR_PERMS" != "$FILE_PERMS" ]]; then
            # Exclude cases where dir_perms=755 and file_perms=644
            if [[ ! ( "$DIR_PERMS" == "755" && "$FILE_PERMS" == "644" ) && ! ( "$DIR_PERMS" == "555" && "$FILE_PERMS" == "755" ) ]]; then
                echo "$FILE (File perms: $FILE_PERMS, Directory perms: $DIR_PERMS)" >> "$OUTPUT_FILE"
            fi
        fi
    done

    echo -e "${PINK}Permission anomalies saved in $OUTPUT_DIR/permission_anomalies.txt${RESET}"
    echo
}

# 3. Find Writable Files by User (Except Root)
find_writable_files_by_user() {
    echo -e "${GREEN}3. Finding writable files by user (except root)...${RESET}"

    USERS_NO_ROOT=$(awk -F: '/sh$/{ if ($1 != "root") print $1 }' /etc/passwd)

    for USER in $USERS_NO_ROOT; do
        OUTPUT_FILE="$OUTPUT_DIR/${USER}_writable_files.txt"
        : > "$OUTPUT_FILE"  # Clear previous output

        find / "${FIND_EXCLUDES[@]}" -type f -user "$USER" -writable -print 2>/dev/null | grep -v "/proc\|modules\|journal\|package\|python\|boot\|cache\|/default\|themes\|/docs\|\.npm\|vendor\|/core/*\|locale\|/doc/\|/mime/\|/man/\|/etc/php-zts.d\|/sys/module/\|font\|help\|/licenses\|/usr/lib/firmware\|/usr/lib/firewalld\|crypto-policies" >> "$OUTPUT_FILE"
    done

    echo -e "${PINK}Writable files by user saved in $OUTPUT_DIR/*_writable_files.txt${RESET}"
    echo
}

# 4. Find Readable, Writable, Executable Files Owned by Root or Root Group, Per User/Group
find_root_files_accessible_by_users() {
    echo -e "${GREEN}4. Finding readable, writable, executable files owned by root or root group, per user/group...${RESET}"

    OUTPUT_SUBDIR="$OUTPUT_DIR/root_files_accessible_by_users"
    mkdir -p "$OUTPUT_SUBDIR"

    # Readable files owned by root, readable by group
    find / "${FIND_EXCLUDES[@]}" -type f -user root ! -perm -o=r -perm -g=r 2>/dev/null | grep -v "/proc\|modules\|journal\|package\|python\|boot\|cache\|/default\|themes\|/docs\|\.npm\|vendor\|/core/*\|locale\|/doc/\|/mime/\|/man/\|/etc/php-zts.d\|/sys/module/\|font\|help\|/licenses\|/usr/lib/firmware\|/usr/lib/firewalld\|crypto-policies" > "$OUTPUT_SUBDIR/readable_by_group.txt"

    # Writable files owned by root, writable by group
    find / "${FIND_EXCLUDES[@]}" -type f -user root ! -perm -o=w -perm -g=w 2>/dev/null | grep -v "/proc\|modules\|journal\|package\|python\|boot\|cache\|/default\|themes\|/docs\|\.npm\|vendor\|/core/*\|locale\|/doc/\|/mime/\|/man/\|/etc/php-zts.d\|/sys/module/\|font\|help\|/licenses\|/usr/lib/firmware\|/usr/lib/firewalld\|crypto-policies" > "$OUTPUT_SUBDIR/writable_by_group.txt"

    # Executable files owned by root, executable by group
    find / "${FIND_EXCLUDES[@]}" -type f -user root ! -perm -o=x -perm -g=x 2>/dev/null | grep -v "/proc\|modules\|journal\|package\|python\|boot\|cache\|/default\|themes\|/docs\|\.npm\|vendor\|/core/*\|locale\|/doc/\|/mime/\|/man/\|/etc/php-zts.d\|/sys/module/\|font\|help\|/licenses\|/usr/lib/firmware\|/usr/lib/firewalld\|crypto-policies" > "$OUTPUT_SUBDIR/executable_by_group.txt"

    echo -e "${PINK}Root files accessible by users saved in $OUTPUT_SUBDIR/${RESET}"
    echo
}

# 5. Find Directories Owned by Non-Root Users
find_directories_owned_by_non_root() {
    echo -e "${GREEN}5. Finding directories owned by non-root users...${RESET}"

    OUTPUT_FILE="$OUTPUT_DIR/non_root_owned_directories.txt"
    : > "$OUTPUT_FILE"  # Clear previous output

    find / -type d ! -user root "${FIND_EXCLUDES[@]}" -print 2>/dev/null | grep -v "/proc\|modules\|journal\|package\|python\|boot\|cache\|/default\|themes\|/docs\|\.npm\|vendor\|/core/*\|locale\|/doc/\|/mime/\|/man/\|/etc/php-zts.d\|/sys/module/\|font\|help\|/licenses\|/usr/lib/firmware\|/usr/lib/firewalld\|crypto-policies" > "$OUTPUT_FILE"

    echo -e "${PINK}Directories owned by non-root users saved in $OUTPUT_FILE${RESET}"
    echo
}

# 6. List the 1000 Most Recently Modified Files
# Thinking about filtering out user share as a whole
list_recently_modified_files() {
    echo -e "${GREEN}6. Listing the 1000 most recently modified files...${RESET}"

    OUTPUT_FILE="$OUTPUT_DIR/recently_modified_files.txt"
    : > "$OUTPUT_FILE"  # Clear previous output

    find / -type f -mmin 20 "${FIND_EXCLUDES[@]}" -iregex '.*site-packages.*\|^.*/\.cargo.*\|.*stable-x86_64.*\|.*.python.*\|\..*m2.*\|.*\/go\/.*\|.*\/\.config\/.*\|.*modules.*\|.*package.*' -prune -o -printf '%T@ %p\n' 2>/dev/null | sort -nr | grep -v "/proc\|modules\|journal\|package\|python\|boot\|cache\|/default\|themes\|/docs\|\.npm\|vendor\|/core/*\|locale\|/doc/\|/mime/\|/man/\|/etc/php-zts.d\|/sys/module/\|font\|help\|/licenses\|/usr/lib/firmware\|/usr/lib/firewalld\|crypto-policies" | cut -d' ' -f2- > "$OUTPUT_FILE"

    echo -e "${PINK}Recently modified files saved in $OUTPUT_FILE${RESET}"
    echo
}

find_interesting_files() {
    echo -e "${GREEN}7. Finding and analyzing interesting files...${RESET}"

    OUTPUT_FILE="$OUTPUT_DIR/interesting_files.txt"
    : > "$OUTPUT_FILE"  # Clear previous output


    find / ! -path "/proc/*" ! -path "/sys/*" ! -path "/run/*" ! -path "/var/lib/*" ! -path "/private/var/*" -iregex '.*site-packages.*\|^.*/\.cargo.*\|.*stable-x86_64.*' -prune -o -iregex ".*\.kdbx\|.*\.ini\|.*\.conf\|.*\.cnf\|.*\.config.*\|.*\.db\|.*\.y*ml\|.*\.txt\|.*\.xml\|.*\.json\|.*\.dat\|.*\.secrets\|.*id_rsa\|.*id_dsa\|.*authorized_keys\|.*sites-available.*\|.*sites-enabled.*\|.*\..*rc\|.*\.env.*\|.*\.bak\|.*\.inf\|.*\.sql.*\|.*\.key\|.*\.sav\|.*\.log\|.*\.settings\|.*\.vcl\|.*conf.*\.php.*\|.*admin.*\.php\|database\.php\|db\.php\|storage\.php\|settings\.php\|installer\.php\|config\.inc\.php\|.*pass.*\.php\|.*\..*sh\|.*\.py\|^.*/\.[^/]*$" 2>/dev/null | grep -v "/proc\|modules\|journal\|package\|python\|boot\|/cache\|/default\|themes\|/docs\|\.npm\|vendor\|/core/*\|locale\|/doc/\|/mime/\|/man/\|/etc/php-zts.d\|/sys/module/\|font\|help\|/licenses\|/usr/lib/firmware\|/usr/lib/firewalld\|crypto-policies" > "$OUTPUT_DIR/temp_interesting_files.txt"

    sed -i "/linpeas\|pspy\|hawk\|checker\|falcon/d" "$OUTPUT_DIR/interesting_files.txt"
    sed -i "/linpeas\|pspy\|hawk\|checker\|falcon/d" "$OUTPUT_DIR/temp_interesting_files.txt"
    
    sleep .5
    # Rank files by last modified time
    echo -e "${PINK}Ranking files by last modified time...${RESET}\n"
    while read -r FILE; do
        if [ -f "$FILE" ]; then
            MOD_TIME=$(stat -c "%Y" "$FILE")
            echo "$MOD_TIME|$FILE"
        fi
    done < "$OUTPUT_DIR/temp_interesting_files.txt" | sort -n | cut -d'|' -f2 > "$OUTPUT_FILE"


    # Optionally, extract information about the files
    echo -e "${PINK}Collecting additional information about the files...${RESET}"
    OUTPUT_DETAILS="$OUTPUT_DIR/interesting_files_details.txt"
    : > "$OUTPUT_DETAILS"

    MAX_PREVIEW_SIZE=512  # Maximum number of bytes to preview from each file

    while read -r FILE; do
        echo "File: $FILE" >> "$OUTPUT_DETAILS"
        echo "Last Modified: $(stat -c '%y' "$FILE")" >> "$OUTPUT_DETAILS"
        echo "Size: $(stat -c '%s' "$FILE") bytes" >> "$OUTPUT_DETAILS"
        echo "Owner: $(stat -c '%U' "$FILE")" >> "$OUTPUT_DETAILS"
        echo "Permissions: $(stat -c '%A' "$FILE")" >> "$OUTPUT_DETAILS"
        echo "File Type: $(file -b "$FILE")" >> "$OUTPUT_DETAILS"
        echo "Preview:" >> "$OUTPUT_DETAILS"
        head -c "$MAX_PREVIEW_SIZE" "$FILE" 2>/dev/null| head -n 10 >> "$OUTPUT_DETAILS"
        echo -e "\n---\n" >> "$OUTPUT_DETAILS"
    done < "$OUTPUT_FILE"

    rm "$OUTPUT_DIR/temp_interesting_files.txt"

    echo -e "${PINK}Interesting files saved in $OUTPUT_FILE${RESET}"
    echo -e "${PINK}Detailed information saved in $OUTPUT_DETAILS${RESET}"
    echo
}

# Main function to run all tasks
main() {
    echo -e "${BOLD}${WHITE}Starting filesystem permission analysis...${RESET}"
    echo

    # Run functions in the background
    find_files_in_foreign_dirs &
    PID1=$!
    sleep .1
    find_files_with_permission_anomalies &
    PID2=$!      
    sleep .1
    find_writable_files_by_user &
    PID3=$! 
    sleep .1
    find_root_files_accessible_by_users &
    PID4=$! 
    sleep .1
    find_directories_owned_by_non_root &
    PID5=$!   
    sleep .1
    list_recently_modified_files &
    PID6=$!
    sleep .1
    find_interesting_files &
    PID7=$!
    sleep .1
    echo

    # Wait for all background processes to complete
    wait $PID1 $PID2 $PID3 $PID4 $PID5 $PID6

    echo -e "${BOLD}${GREEN}Filesystem permission analysis completed.${RESET}"
}

# Run the main function
main
