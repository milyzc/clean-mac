# clean.sh — Limpieza de espacio en macOS

Script de limpieza para entornos de desarrollo mobile (iOS + Android) con Node.js, Xcode y Android Studio.

## Uso

```bash
# Ver qué haría sin borrar nada
./clean.sh --dry-run

# Ejecutar limpieza real
./clean.sh
```

## Qué limpia

| # | Categoría | Descripción |
|---|---|---|
| 1 | **npm cache** | `npm cache clean --force` |
| 2 | **Homebrew** | Versiones viejas de paquetes (`brew cleanup --prune=all`) y dependencias huérfanas (`brew autoremove`) |
| 3 | **Gradle cache** | `~/.gradle/caches` — generado por builds de Android |
| 4 | **CocoaPods cache** | `pod cache clean --all` |
| 5 | **Xcode DerivedData** | `~/Library/Developer/Xcode/DerivedData` — artefactos intermedios de compilación |
| 6 | **Simuladores iOS unavailable** | `xcrun simctl delete unavailable` — simuladores sin runtime asociado |
| 7 | **iOS DeviceSupport** | `~/Library/Developer/Xcode/iOS DeviceSupport` — conserva solo las 2 versiones más recientes |
| 8 | **Android SDK build-tools** | Desinstala versiones < 34 y todas las RCs usando `sdkmanager` |
| 9 | **Android SDK cmdline-tools** | Desinstala versiones viejas (1.0 → 11.0), conserva `latest` |
| 10 | **Docker** | `docker system prune -a --volumes -f` — imágenes, contenedores y volúmenes no usados |
| 11 | **Sistema** | Vacía la Papelera (`~/.Trash`) y limpia caché de VS Code |

## Lo que NO toca

- `node_modules` de proyectos (requiere reinstalar dependencias)
- Xcode Archives recientes (2025+)
- Android SDK platforms, system images y `platform-tools` activos
- Simuladores disponibles (solo borra los `unavailable`)
- Datos de usuario en `~/Documents`, `~/Desktop`, etc.

## Salida

Al ejecutar, el script muestra un resumen de espacio **antes y después** para cada categoría:

```
Espacio disco actual:
  Usado: 234G  Disponible: 28G  Total: 460G

Pesos por categoría:
  Simuladores iOS:         11G
  iOS DeviceSupport:       5.4G
  Xcode Archives:          468M
  Android SDK:             9.6G
  Gradle cache:            -
```

## Requisitos

- macOS con zsh
- `xcrun` / Xcode Command Line Tools (para simuladores y DeviceSupport)
- `sdkmanager` en `~/Library/Android/sdk/cmdline-tools/latest/bin/` (para Android SDK)
- `brew`, `pod`, `docker` opcionales — se omiten si no están instalados
