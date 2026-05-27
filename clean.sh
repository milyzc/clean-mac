#!/bin/zsh
# =============================================================================
#  clean.sh — Limpieza de espacio en macOS (desarrollo mobile / Node / Xcode)
#  Uso: ./clean.sh [--dry-run]
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

# Para comandos con pipes o redirecciones que no pueden pasarse como array
run_sh() {
  if $DRY_RUN; then
    echo "  [dry-run] $1"
  else
    eval "$1"
  fi
}

section() { echo "\n${CYAN}══════════════════════════════════════════${NC}"; echo "${CYAN}  $1${NC}"; echo "${CYAN}══════════════════════════════════════════${NC}" }
ok()      { echo "  ${GREEN}✓${NC} $1" }
info()    { echo "  ${YELLOW}→${NC} $1" }

$DRY_RUN && echo "\n${YELLOW}MODO DRY-RUN: solo se mostrarán los comandos, no se ejecutará nada.${NC}"

# ─────────────────────────────────────────────────────────────────────────────
section "RESUMEN ANTES DE LIMPIAR"
# ─────────────────────────────────────────────────────────────────────────────
echo "Espacio disco actual:"
df -h / | awk 'NR==2 {print "  Usado: "$3"  Disponible: "$4"  Total: "$2}'

echo "\nPesos por categoría:"
du -sh ~/Library/Developer/CoreSimulator/Devices 2>/dev/null | awk '{print "  Simuladores iOS:         "$1}'
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport 2>/dev/null | awk '{print "  iOS DeviceSupport:       "$1}'
du -sh ~/Library/Developer/Xcode/Archives 2>/dev/null | awk '{print "  Xcode Archives:          "$1}'
du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | awk '{print "  Xcode DerivedData:       "$1}'
du -sh ~/Library/Android/sdk 2>/dev/null | awk '{print "  Android SDK:             "$1}'
du -sh ~/.android/avd 2>/dev/null | awk '{print "  Android AVDs:            "$1}'
du -sh ~/.gradle/caches 2>/dev/null | awk '{print "  Gradle cache:            "$1}'
du -sh ~/Library/Caches/CocoaPods 2>/dev/null | awk '{print "  CocoaPods cache:         "$1}'
du -sh ~/Library/Caches/org.swift.swiftpm 2>/dev/null | awk '{print "  Swift PM cache:          "$1}'

# ─────────────────────────────────────────────────────────────────────────────
section "1. NPM — limpiar caché"
# ─────────────────────────────────────────────────────────────────────────────
info "npm cache clean --force"
run npm cache clean --force 2>/dev/null && ok "npm cache limpiado"

# ─────────────────────────────────────────────────────────────────────────────
section "2. BREW — limpiar versiones viejas y dependencias huérfanas"
# ─────────────────────────────────────────────────────────────────────────────
if command -v brew &>/dev/null; then
  info "brew cleanup --prune=all"
  run brew cleanup --prune=all 2>/dev/null && ok "brew cleanup listo"
  info "brew autoremove"
  run brew autoremove 2>/dev/null && ok "brew autoremove listo"
else
  info "brew no instalado — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "3. GRADLE — limpiar caché de Android builds"
# ─────────────────────────────────────────────────────────────────────────────
if [[ -d ~/.gradle/caches ]]; then
  info "Borrando ~/.gradle/caches"
  run rm -rf ~/.gradle/caches && ok "Gradle cache borrado"
else
  info "~/.gradle/caches no encontrado — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "4. COCOAPODS — limpiar caché"
# ─────────────────────────────────────────────────────────────────────────────
if command -v pod &>/dev/null; then
  info "pod cache clean --all"
  run pod cache clean --all 2>/dev/null && ok "CocoaPods cache limpiado"
else
  info "pod no instalado — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "5. XCODE — DerivedData"
# ─────────────────────────────────────────────────────────────────────────────
if [[ -d ~/Library/Developer/Xcode/DerivedData ]]; then
  SIZE=$(du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | awk '{print $1}')
  info "Borrando DerivedData ($SIZE)"
  run rm -rf ~/Library/Developer/Xcode/DerivedData && ok "DerivedData borrado"
else
  info "DerivedData vacío — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "6. XCODE — Simuladores no usados"
# ─────────────────────────────────────────────────────────────────────────────
info "Borrando simuladores marcados como 'unavailable'"
run xcrun simctl delete unavailable 2>/dev/null && ok "Simuladores unavailable borrados"

# ─────────────────────────────────────────────────────────────────────────────
section "7. XCODE — iOS DeviceSupport (versiones viejas)"
# ─────────────────────────────────────────────────────────────────────────────
# Conserva solo las 2 versiones más recientes
DS_DIR=~/Library/Developer/Xcode/iOS\ DeviceSupport
if [[ -d "$DS_DIR" ]]; then
  # Split solo en newlines para manejar nombres con espacios como "16.0 (20A362)"
  # Ordena por nombre de versión (sort -V) en lugar de mtime para evitar que
  # conectar un dispositivo viejo altere el orden; luego invierte (más reciente primero)
  VERSIONS=(${(f)"$(ls "$DS_DIR" 2>/dev/null | sort -Vr)"})
  COUNT=${#VERSIONS[@]}
  KEEP=2
  if (( COUNT > KEEP )); then
    info "Conservando las $KEEP versiones más recientes, borrando $((COUNT - KEEP)) viejas"
    # En zsh los arrays son 1-indexed: keep [1..KEEP], borrar [KEEP+1..COUNT]
    for (( i=KEEP+1; i<=COUNT; i++ )); do
      info "  Borrando: ${VERSIONS[$i]}"
      run rm -rf "$DS_DIR/${VERSIONS[$i]}"
    done
    ok "iOS DeviceSupport limpiado"
  else
    info "Solo $COUNT versiones presentes — omitido"
  fi
else
  info "iOS DeviceSupport no encontrado — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "8. ANDROID SDK — build-tools viejas (< 34) y todas las RCs"
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
  # Filtrar solo las que están realmente instaladas
  INSTALLED=$($SDKMANAGER --list_installed 2>/dev/null | awk '{print $1}')
  TO_UNINSTALL=()
  for pkg in "${OLD_BUILD_TOOLS[@]}"; do
    echo "$INSTALLED" | grep -qF "$pkg" && TO_UNINSTALL+=("$pkg")
  done
  if (( ${#TO_UNINSTALL[@]} > 0 )); then
    info "Desinstalando ${#TO_UNINSTALL[@]} build-tools antiguas..."
    run_sh "$SDKMANAGER --uninstall ${(q)TO_UNINSTALL[@]} 2>&1 | tail -2"
    ok "build-tools antiguas desinstaladas"
  else
    info "No hay build-tools antiguas instaladas — omitido"
  fi
else
  info "sdkmanager no encontrado — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "9. ANDROID SDK — cmdline-tools viejas"
# ─────────────────────────────────────────────────────────────────────────────
if [[ -x "$SDKMANAGER" ]]; then
  OLD_CMDTOOLS=(
    "cmdline-tools;1.0" "cmdline-tools;2.1" "cmdline-tools;3.0" "cmdline-tools;4.0"
    "cmdline-tools;5.0" "cmdline-tools;6.0" "cmdline-tools;7.0" "cmdline-tools;8.0"
    "cmdline-tools;9.0" "cmdline-tools;10.0" "cmdline-tools;11.0"
  )
  # Re-query para no depender de $INSTALLED de la sección 8
  INSTALLED_CT=$($SDKMANAGER --list_installed 2>/dev/null | awk '{print $1}')
  TO_UNINSTALL=()
  for pkg in "${OLD_CMDTOOLS[@]}"; do
    echo "$INSTALLED_CT" | grep -qF "$pkg" && TO_UNINSTALL+=("$pkg")
  done
  if (( ${#TO_UNINSTALL[@]} > 0 )); then
    info "Desinstalando ${#TO_UNINSTALL[@]} cmdline-tools viejas..."
    run_sh "$SDKMANAGER --uninstall ${(q)TO_UNINSTALL[@]} 2>&1 | tail -2"
    ok "cmdline-tools viejas desinstaladas"
  else
    info "No hay cmdline-tools viejas instaladas — omitido"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
section "10. SISTEMA — logs y caché de macOS"
# ─────────────────────────────────────────────────────────────────────────────
info "Vaciando Trash"
run rm -rf ~/.Trash/*(N) 2>/dev/null && ok "Trash vaciado"

info "Limpiando VS Code cache"
run rm -rf ~/Library/Application\ Support/Code/Cache 2>/dev/null
run rm -rf ~/Library/Application\ Support/Code/CachedExtensionVSIXs 2>/dev/null && ok "VS Code cache limpiado"

# ─────────────────────────────────────────────────────────────────────────────
section "11. NODE_MODULES — carpetas sin usar hace +60 días"
# ─────────────────────────────────────────────────────────────────────────────
# -atime: días desde último acceso (lectura), no desde última modificación de entradas.
# Así un proyecto en uso diario con deps estables no es eliminado.
NM_DIRS=(${(f)"$(find ~ -maxdepth 8 -name "node_modules" -type d -prune -atime +60 \
  -not -path "*/Library/*" -not -path "*/\.*" 2>/dev/null)"})
if (( ${#NM_DIRS[@]} > 0 )); then
  TOTAL=$(du -shc "${NM_DIRS[@]}" 2>/dev/null | tail -1 | awk '{print $1}')
  info "Encontradas ${#NM_DIRS[@]} carpetas node_modules (total: $TOTAL)"
  for d in "${NM_DIRS[@]}"; do
    info "  $d"
    run rm -rf "$d"
  done
  ok "node_modules huérfanos borrados"
else
  info "No hay node_modules con +60 días sin acceder — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "12. XCODE — datos internos de simuladores (erase all)"
# ─────────────────────────────────────────────────────────────────────────────
if command -v xcrun &>/dev/null; then
  SIZE=$(du -sh ~/Library/Developer/CoreSimulator/Devices 2>/dev/null | awk '{print $1}')
  info "xcrun simctl erase all — limpia apps/datos, conserva los dispositivos ($SIZE)"
  run xcrun simctl erase all 2>/dev/null && ok "Datos de simuladores borrados"
else
  info "xcrun no disponible — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "13. ANDROID — AVD snapshots"
# ─────────────────────────────────────────────────────────────────────────────
if [[ -d ~/.android/avd ]]; then
  SNAPS=($(find ~/.android/avd -maxdepth 2 -name "snapshots" -type d 2>/dev/null))
  if (( ${#SNAPS[@]} > 0 )); then
    SIZE=$(du -shc "${SNAPS[@]}" 2>/dev/null | tail -1 | awk '{print $1}')
    info "Borrando snapshots de ${#SNAPS[@]} AVD(s) ($SIZE)"
    for s in "${SNAPS[@]}"; do
      run rm -rf "$s"
    done
    ok "AVD snapshots borrados"
  else
    info "No hay snapshots de AVD — omitido"
  fi
else
  info "~/.android/avd no encontrado — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "14. YARN / PNPM — limpiar caché"
# ─────────────────────────────────────────────────────────────────────────────
if command -v yarn &>/dev/null; then
  info "yarn cache clean"
  run yarn cache clean 2>/dev/null && ok "yarn cache limpiado"
else
  info "yarn no instalado — omitido"
fi
if command -v pnpm &>/dev/null; then
  info "pnpm store prune"
  run pnpm store prune 2>/dev/null && ok "pnpm store podado"
else
  info "pnpm no instalado — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "15. SWIFT PM — limpiar caché"
# ─────────────────────────────────────────────────────────────────────────────
SPM_CACHE=~/Library/Caches/org.swift.swiftpm
if [[ -d "$SPM_CACHE" ]]; then
  SIZE=$(du -sh "$SPM_CACHE" 2>/dev/null | awk '{print $1}')
  info "Borrando Swift PM cache ($SIZE)"
  run rm -rf "$SPM_CACHE" && ok "Swift PM cache borrado"
else
  info "Swift PM cache no encontrado — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "16. DIAGNOSTIC REPORTS — crash logs con +30 días"
# ─────────────────────────────────────────────────────────────────────────────
DIAG_DIR=~/Library/Logs/DiagnosticReports
if [[ -d "$DIAG_DIR" ]]; then
  COUNT=$(find "$DIAG_DIR" \( -name "*.crash" -o -name "*.ips" \) -mtime +30 2>/dev/null | wc -l | tr -d ' ')
  if (( COUNT > 0 )); then
    info "Borrando $COUNT crash reports con +30 días"
    run_sh "find \"$DIAG_DIR\" \\( -name '*.crash' -o -name '*.ips' \\) -mtime +30 -delete 2>/dev/null"
    ok "Crash reports viejos borrados"
  else
    info "No hay crash reports con +30 días — omitido"
  fi
else
  info "DiagnosticReports no encontrado — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "17. GIT — gc en repos locales"
# ─────────────────────────────────────────────────────────────────────────────
GIT_ROOTS=($(find ~ -maxdepth 6 -name ".git" -type d \
  -not -path "*/node_modules/*" -not -path "*/Library/*" 2>/dev/null \
  | sed 's/\/.git$//'))
if (( ${#GIT_ROOTS[@]} > 0 )); then
  info "Ejecutando git gc en ${#GIT_ROOTS[@]} repositorios"
  for repo in "${GIT_ROOTS[@]}"; do
    info "  $repo"
    run git -C "$repo" gc --prune=now --quiet 2>/dev/null
  done
  ok "git gc completado"
else
  info "No se encontraron repositorios git — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "18. DOCKER — imágenes y contenedores no usados"
# ─────────────────────────────────────────────────────────────────────────────
if command -v docker &>/dev/null && timeout 15 docker info &>/dev/null 2>&1; then
  # Sin -a ni --volumes: solo elimina imágenes huérfanas (dangling) y contenedores parados,
  # sin borrar imágenes reutilizables ni volúmenes con datos de compose stacks
  info "docker system prune -f"
  run docker system prune -f 2>/dev/null && ok "Docker limpiado"
else
  info "Docker no disponible — omitido"
fi

# ─────────────────────────────────────────────────────────────────────────────
section "RESUMEN FINAL"
# ─────────────────────────────────────────────────────────────────────────────
echo "Espacio disco actual:"
df -h / | awk 'NR==2 {print "  Usado: "$3"  Disponible: "$4"  Total: "$2}'

echo "\nPesos por categoría (post-limpieza):"
du -sh ~/Library/Developer/CoreSimulator/Devices 2>/dev/null | awk '{print "  Simuladores iOS:         "$1}'
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport 2>/dev/null | awk '{print "  iOS DeviceSupport:       "$1}'
du -sh ~/Library/Developer/Xcode/Archives 2>/dev/null | awk '{print "  Xcode Archives:          "$1}'
du -sh ~/Library/Android/sdk 2>/dev/null | awk '{print "  Android SDK:             "$1}'
du -sh ~/.android/avd 2>/dev/null | awk '{print "  Android AVDs:            "$1}'
du -sh ~/.gradle/caches 2>/dev/null | awk '{print "  Gradle cache:            "$1}'
du -sh ~/Library/Caches/org.swift.swiftpm 2>/dev/null | awk '{print "  Swift PM cache:          "$1}'

echo "\n${GREEN}✓ Limpieza completada${NC}"
