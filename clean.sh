#!/bin/zsh
# =============================================================================
#  clean.sh — Disk space cleanup for macOS (mobile / Node / Xcode development)
#  Usage: ./clean.sh [--dry-run]
# =============================================================================

DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

SDKMANAGER=~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager

# Color helpers
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

run() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
    return 1
  else
    "$@"
  fi
}

# For commands with pipes or redirections that cannot be passed as an array
run_sh() {
  if $DRY_RUN; then
    echo "  [dry-run] $1"
    return 1
  else
    eval "$1"
  fi
}

section() { echo "\n${CYAN}══════════════════════════════════════════${NC}"; echo "${CYAN}  $1${NC}"; echo "${CYAN}══════════════════════════════════════════${NC}" }
ok()      { echo "  ${GREEN}✓${NC} $1" }
info()    { echo "  ${YELLOW}→${NC} $1" }

$DRY_RUN && echo "\n${YELLOW}DRY-RUN MODE: commands will be printed but nothing will be executed.${NC}"

# ─────────────────────────────────────────────────────────────────────────────
section "SUMMARY BEFORE CLEANUP"
# ─────────────────────────────────────────────────────────────────────────────
echo "Current disk usage:"
df -h / | awk 'NR==2 {print "  Used: "$3"  Available: "$4"  Total: "$2}'

echo "\nSize by category:"
du -sh ~/Library/Developer/CoreSimulator/Devices 2>/dev/null | awk '{print "  iOS Simulators:          "$1}'
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport 2>/dev/null | awk '{print "  iOS DeviceSupport:       "$1}'
du -sh ~/Library/Developer/Xcode/Archives 2>/dev/null | awk '{print "  Xcode Archives:          "$1}'
du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | awk '{print "  Xcode DerivedData:       "$1}'
du -sh ~/Library/Android/sdk 2>/dev/null | awk '{print "  Android SDK:             "$1}'
du -sh ~/.android/avd 2>/dev/null | awk '{print "  Android AVDs:            "$1}'
du -sh ~/.gradle/caches 2>/dev/null | awk '{print "  Gradle cache:            "$1}'
du -sh ~/Library/Caches/CocoaPods 2>/dev/null | awk '{print "  CocoaPods cache:         "$1}'
du -sh ~/Library/Caches/org.swift.swiftpm 2>/dev/null | awk '{print "  Swift PM cache:          "$1}'

# ─────────────────────────────────────────────────────────────────────────────
section "1. NPM — clean cache"
# ─────────────────────────────────────────────────────────────────────────────
info "npm cache clean --force"
run npm cache clean --force 2>/dev/null && ok "npm cache cleared"

# ─────────────────────────────────────────────────────────────────────────────
section "2. BREW — remove old versions and orphan dependencies"
# ─────────────────────────────────────────────────────────────────────────────
if command -v brew &>/dev/null; then
  info "brew cleanup --prune=all"
  run brew cleanup --prune=all 2>/dev/null && ok "brew cleanup done"
  info "brew autoremove"
  run brew autoremove 2>/dev/null && ok "brew autoremove done"
else
  info "brew not installed — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "3. GRADLE — clean Android build cache"
# ─────────────────────────────────────────────────────────────────────────────
if [[ -d ~/.gradle/caches ]]; then
  info "Removing ~/.gradle/caches"
  run rm -rf ~/.gradle/caches && ok "Gradle cache removed"
else
  info "~/.gradle/caches not found — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "4. COCOAPODS — clean cache"
# ─────────────────────────────────────────────────────────────────────────────
if command -v pod &>/dev/null; then
  info "pod cache clean --all"
  run pod cache clean --all 2>/dev/null && ok "CocoaPods cache cleared"
else
  info "pod not installed — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "5. XCODE — DerivedData"
# ─────────────────────────────────────────────────────────────────────────────
if [[ -d ~/Library/Developer/Xcode/DerivedData ]]; then
  SIZE=$(du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | awk '{print $1}')
  info "Removing DerivedData ($SIZE)"
  run rm -rf ~/Library/Developer/Xcode/DerivedData && ok "DerivedData removed"
else
  info "DerivedData empty — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "6. XCODE — Unused simulators"
# ─────────────────────────────────────────────────────────────────────────────
info "Removing simulators marked as 'unavailable'"
run xcrun simctl delete unavailable 2>/dev/null && ok "Unavailable simulators removed"

# ─────────────────────────────────────────────────────────────────────────────
section "7. XCODE — iOS DeviceSupport (old versions)"
# ─────────────────────────────────────────────────────────────────────────────
# Keep only the 2 most recent versions
DS_DIR=~/Library/Developer/Xcode/iOS\ DeviceSupport
if [[ -d "$DS_DIR" ]]; then
  # Split on newlines only to handle names with spaces like "16.0 (20A362)"
  # Sort by version name (sort -V) instead of mtime so connecting an old device
  # doesn't reorder the list; then reverse so newest comes first
  VERSIONS=(${(f)"$(ls "$DS_DIR" 2>/dev/null | sort -Vr)"})
  COUNT=${#VERSIONS[@]}
  KEEP=2
  if (( COUNT > KEEP )); then
    info "Keeping the $KEEP most recent versions, removing $((COUNT - KEEP)) old ones"
    # zsh arrays are 1-indexed: keep [1..KEEP], remove [KEEP+1..COUNT]
    for (( i=KEEP+1; i<=COUNT; i++ )); do
      info "  Removing: ${VERSIONS[$i]}"
      run rm -rf "$DS_DIR/${VERSIONS[$i]}"
    done
    ok "iOS DeviceSupport cleaned"
  else
    info "Only $COUNT versions present — skipped"
  fi
else
  info "iOS DeviceSupport not found — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "8. ANDROID SDK — old build-tools (< 34) and all RCs"
# ─────────────────────────────────────────────────────────────────────────────
if [[ -x "$SDKMANAGER" ]]; then
  OLD_BUILD_TOOLS=(
    "build-tools;19.1.0" "build-tools;20.0.0" "build-tools;21.1.2"
    "build-tools;22.0.1" "build-tools;23.0.1" "build-tools;23.0.2" "build-tools;23.0.3"
    "build-tools;24.0.0" "build-tools;24.0.1" "build-tools;24.0.2" "build-tools;24.0.3"
    "build-tools;25.0.0" "build-tools;25.0.1" "build-tools;25.0.2" "build-tools;25.0.3"
    "build-tools;26.0.0" "build-tools;26.0.1" "build-tools;26.0.2" "build-tools;26.0.3"
    "build-tools;27.0.0" "build-tools;27.0.1" "build-tools;27.0.2" "build-tools;27.0.3"
    "build-tools;28.0.0" "build-tools;28.0.1" "build-tools;28.0.2" "build-tools;28.0.3"
    "build-tools;29.0.0" "build-tools;29.0.1" "build-tools;29.0.2" "build-tools;29.0.3"
    "build-tools;30.0.0" "build-tools;30.0.1" "build-tools;30.0.2" "build-tools;30.0.3"
    "build-tools;31.0.0" "build-tools;32.0.0" "build-tools;32.1.0-rc1"
    "build-tools;33.0.0" "build-tools;33.0.1" "build-tools;33.0.2" "build-tools;33.0.3"
    "build-tools;34.0.0-rc1" "build-tools;34.0.0-rc2" "build-tools;34.0.0-rc3"
    "build-tools;35.0.0-rc1" "build-tools;35.0.0-rc2" "build-tools;35.0.0-rc3" "build-tools;35.0.0-rc4"
    "build-tools;36.0.0-rc1"
  )
  # Filter only the ones actually installed
  INSTALLED=$($SDKMANAGER --list_installed 2>/dev/null | awk '{print $1}')
  TO_UNINSTALL=()
  for pkg in "${OLD_BUILD_TOOLS[@]}"; do
    echo "$INSTALLED" | grep -qF "$pkg" && TO_UNINSTALL+=("$pkg")
  done
  if (( ${#TO_UNINSTALL[@]} > 0 )); then
    info "Uninstalling ${#TO_UNINSTALL[@]} old build-tools..."
    if $DRY_RUN; then
      echo "  [dry-run] $SDKMANAGER --uninstall ${TO_UNINSTALL[*]}"
    else
      "$SDKMANAGER" --uninstall "${TO_UNINSTALL[@]}" 2>&1 | tail -2 && ok "Old build-tools uninstalled"
    fi
  else
    info "No old build-tools installed — skipped"
  fi
else
  info "sdkmanager not found — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "9. ANDROID SDK — old cmdline-tools"
# ─────────────────────────────────────────────────────────────────────────────
if [[ -x "$SDKMANAGER" ]]; then
  OLD_CMDTOOLS=(
    "cmdline-tools;1.0" "cmdline-tools;2.1" "cmdline-tools;3.0" "cmdline-tools;4.0"
    "cmdline-tools;5.0" "cmdline-tools;6.0" "cmdline-tools;7.0" "cmdline-tools;8.0"
    "cmdline-tools;9.0" "cmdline-tools;10.0" "cmdline-tools;11.0"
  )
  # Re-query to avoid depending on $INSTALLED from section 8
  INSTALLED_CT=$($SDKMANAGER --list_installed 2>/dev/null | awk '{print $1}')
  TO_UNINSTALL=()
  for pkg in "${OLD_CMDTOOLS[@]}"; do
    echo "$INSTALLED_CT" | grep -qF "$pkg" && TO_UNINSTALL+=("$pkg")
  done
  if (( ${#TO_UNINSTALL[@]} > 0 )); then
    info "Uninstalling ${#TO_UNINSTALL[@]} old cmdline-tools..."
    if $DRY_RUN; then
      echo "  [dry-run] $SDKMANAGER --uninstall ${TO_UNINSTALL[*]}"
    else
      "$SDKMANAGER" --uninstall "${TO_UNINSTALL[@]}" 2>&1 | tail -2 && ok "Old cmdline-tools uninstalled"
    fi
  else
    info "No old cmdline-tools installed — skipped"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "10. SYSTEM — macOS logs and cache"
# ─────────────────────────────────────────────────────────────────────────────
info "Emptying Trash"
run rm -rf ~/.Trash/*(N) 2>/dev/null && ok "Trash emptied"

info "Clearing VS Code cache"
run rm -rf ~/Library/Application\ Support/Code/Cache 2>/dev/null
run rm -rf ~/Library/Application\ Support/Code/CachedExtensionVSIXs 2>/dev/null && ok "VS Code cache cleared"

# ─────────────────────────────────────────────────────────────────────────────
section "11. NODE_MODULES — folders not accessed in +60 days"
# ─────────────────────────────────────────────────────────────────────────────
# -atime: days since last read access, not since last entry modification.
# This prevents deleting node_modules from actively-used projects with stable deps.
NM_DIRS=(${(f)"$(find ~ -maxdepth 8 -name "node_modules" -type d -prune -atime +60 \
  -not -path "*/Library/*" -not -path "*/\.*" 2>/dev/null)"})
if (( ${#NM_DIRS[@]} > 0 )); then
  TOTAL=$(du -shc "${NM_DIRS[@]}" 2>/dev/null | tail -1 | awk '{print $1}')
  info "Found ${#NM_DIRS[@]} node_modules folders (total: $TOTAL)"
  for d in "${NM_DIRS[@]}"; do
    info "  $d"
    run rm -rf "$d"
  done
  ok "Orphan node_modules removed"
else
  info "No node_modules not accessed in +60 days — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "12. XCODE — simulator internal data (erase all)"
# ─────────────────────────────────────────────────────────────────────────────
if command -v xcrun &>/dev/null; then
  SIZE=$(du -sh ~/Library/Developer/CoreSimulator/Devices 2>/dev/null | awk '{print $1}')
  info "xcrun simctl erase all — wipes app data, keeps devices ($SIZE)"
  run xcrun simctl erase all 2>/dev/null && ok "Simulator data erased"
else
  info "xcrun not available — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "13. ANDROID — AVD snapshots"
# ─────────────────────────────────────────────────────────────────────────────
if [[ -d ~/.android/avd ]]; then
  SNAPS=($(find ~/.android/avd -maxdepth 2 -name "snapshots" -type d 2>/dev/null))
  if (( ${#SNAPS[@]} > 0 )); then
    SIZE=$(du -shc "${SNAPS[@]}" 2>/dev/null | tail -1 | awk '{print $1}')
    info "Removing snapshots from ${#SNAPS[@]} AVD(s) ($SIZE)"
    for s in "${SNAPS[@]}"; do
      run rm -rf "$s"
    done
    ok "AVD snapshots removed"
  else
    info "No AVD snapshots found — skipped"
  fi
else
  info "~/.android/avd not found — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "14. YARN / PNPM — clean cache"
# ─────────────────────────────────────────────────────────────────────────────
if command -v yarn &>/dev/null; then
  info "yarn cache clean"
  run yarn cache clean 2>/dev/null && ok "yarn cache cleared"
else
  info "yarn not installed — skipped"
fi
if command -v pnpm &>/dev/null; then
  info "pnpm store prune"
  run pnpm store prune 2>/dev/null && ok "pnpm store pruned"
else
  info "pnpm not installed — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "15. SWIFT PM — clean cache"
# ─────────────────────────────────────────────────────────────────────────────
SPM_CACHE=~/Library/Caches/org.swift.swiftpm
if [[ -d "$SPM_CACHE" ]]; then
  SIZE=$(du -sh "$SPM_CACHE" 2>/dev/null | awk '{print $1}')
  info "Removing Swift PM cache ($SIZE)"
  run rm -rf "$SPM_CACHE" && ok "Swift PM cache removed"
else
  info "Swift PM cache not found — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "16. DIAGNOSTIC REPORTS — crash logs older than 30 days"
# ─────────────────────────────────────────────────────────────────────────────
DIAG_DIR=~/Library/Logs/DiagnosticReports
if [[ -d "$DIAG_DIR" ]]; then
  COUNT=$(find "$DIAG_DIR" \( -name "*.crash" -o -name "*.ips" \) -mtime +30 2>/dev/null | wc -l | tr -d ' ')
  if (( COUNT > 0 )); then
    info "Removing $COUNT crash reports older than 30 days"
    run_sh "find \"$DIAG_DIR\" \\( -name '*.crash' -o -name '*.ips' \\) -mtime +30 -delete 2>/dev/null" && ok "Old crash reports removed"
  else
    info "No crash reports older than 30 days — skipped"
  fi
else
  info "DiagnosticReports not found — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "17. GIT — gc on local repositories"
# ─────────────────────────────────────────────────────────────────────────────
GIT_ROOTS=($(find ~ -maxdepth 6 -name ".git" -type d \
  -not -path "*/node_modules/*" -not -path "*/Library/*" 2>/dev/null \
  | sed 's/\/.git$//'))
if (( ${#GIT_ROOTS[@]} > 0 )); then
  info "Running git gc on ${#GIT_ROOTS[@]} repositories"
  for repo in "${GIT_ROOTS[@]}"; do
    info "  $repo"
    run git -C "$repo" gc --prune=now --quiet 2>/dev/null
  done
  ok "git gc complete"
else
  info "No git repositories found — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "18. DOCKER — unused images and containers"
# ─────────────────────────────────────────────────────────────────────────────
if command -v docker &>/dev/null && timeout 15 docker info &>/dev/null 2>&1; then
  # No -a or --volumes: only removes dangling images and stopped containers,
  # leaving reusable images and compose stack volumes untouched
  info "docker system prune -f"
  run docker system prune -f 2>/dev/null && ok "Docker cleaned"
else
  info "Docker not available — skipped"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "FINAL SUMMARY"
# ─────────────────────────────────────────────────────────────────────────────
echo "Current disk usage:"
df -h / | awk 'NR==2 {print "  Used: "$3"  Available: "$4"  Total: "$2}'

echo "\nSize by category (after cleanup):"
du -sh ~/Library/Developer/CoreSimulator/Devices 2>/dev/null | awk '{print "  iOS Simulators:          "$1}'
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport 2>/dev/null | awk '{print "  iOS DeviceSupport:       "$1}'
du -sh ~/Library/Developer/Xcode/Archives 2>/dev/null | awk '{print "  Xcode Archives:          "$1}'
du -sh ~/Library/Android/sdk 2>/dev/null | awk '{print "  Android SDK:             "$1}'
du -sh ~/.android/avd 2>/dev/null | awk '{print "  Android AVDs:            "$1}'
du -sh ~/.gradle/caches 2>/dev/null | awk '{print "  Gradle cache:            "$1}'
du -sh ~/Library/Caches/org.swift.swiftpm 2>/dev/null | awk '{print "  Swift PM cache:          "$1}'

echo "\n${GREEN}✓ Cleanup complete${NC}"
