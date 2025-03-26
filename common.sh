
# Color definitions
ERROR='\033[0;31m'
FINISH='\033[0;32m'
PROCESS='\033[0;33m'
SKIP='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local message="$1"
    local color="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Use the specified color or default to no color
    if [[ -z "$color" ]]; then
        color="$NC" # Default to no color
    fi
    echo -e "[$timestamp] ${color}$message${NC}"
}
