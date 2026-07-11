# CLAUDE.md

Contexto para Claude Code (u otras instancias de Claude) trabajando en este repo.

## Qué es este repo

`terminal-stack` — configuración reproducible para migrar de un entorno gráfico (VSCode/Antigravity, Lens, Docker Desktop, Warp-only) a un flujo de desarrollo basado en terminal, en cualquier Mac (Apple Silicon o Intel).

Dueño: Jonathan (`jonathanleivag`), senior developer. Trabaja en:

- **Movatec** (empleo) — proyectos en `~/Development/Movatec/`
- **Personal** — proyectos en `~/Development/jonathanleivag/`

Stack de desarrollo: JS/TS con Vue, React, Astro, Next.js, Nest.js. Bases de datos: MySQL, PostgreSQL, MongoDB. Kubernetes en producción.

## Archivos del repo

- `setup-terminal-stack.sh` — script principal de instalación. Es la fuente de verdad de todo el stack.
- `README.md` — documentación para el humano: cómo ejecutar, qué instala, troubleshooting de errores ya resueltos.

## Reglas de oro al modificar `setup-terminal-stack.sh`

1. **Idempotencia siempre.** Toda instalación/configuración debe poder correr múltiples veces sin duplicar líneas, sobreescribir configs existentes, ni fallar si algo ya está instalado. Patrón estándar:

   ```bash
   if <condición de "ya existe">; then
     echo "  X OK, ya instalado"
   else
     warn "X no encontrado. Instalando..."
     <comando de instalación>
   fi
   ```

2. **Nunca sobreescribir archivos de config que el usuario pudo haber personalizado** (`.zshrc`, `extras.lua`, `dashboard.lua`, `.tmux.conf`, etc.). Si el archivo ya existe, se avisa con `warn` y no se toca. Las líneas sueltas en archivos como `.zshrc` se agregan con la función helper `append_once` (evita duplicados).

3. **No asumir fórmulas de Homebrew sin confirmarlas.** Ya hubo un error real en este repo: se asumió que `fzf-tab` era una fórmula de Homebrew (`brew install fzf-tab`) cuando no lo es — causó `source: no such file or directory` en el `.zshrc` del usuario. Ahora se clona directo del repo de GitHub (`Aloxaf/fzf-tab`) a `~/.zsh-plugins/fzf-tab`. Si no hay certeza de que algo existe como fórmula de brew, preferir clonar desde el repo oficial del proyecto.

4. **Validar sintaxis antes de entregar.** Correr `bash -n setup-terminal-stack.sh` tras cualquier cambio. Si es posible, probar la lógica crítica (ej. `git config` con `includeIf`) en un `$HOME` de prueba aislado antes de asumir que funciona.

5. **Numeración de secciones consistente.** El script está dividido en secciones comentadas `# ---------- N. Nombre ----------`. Al insertar una sección nueva en medio, renumerar las siguientes para mantener la secuencia (actualmente van del 0 al 13).

6. **Todo corre en paralelo con las apps gráficas existentes.** Nunca desinstalar Lens, Docker Desktop, VSCode/Antigravity, ni Warp. El objetivo es migración gradual, no reemplazo forzado.

7. **Preguntas interactivas solo cuando sea necesario** (`read -r -p`), siguiendo el patrón ya usado para: cambiar shell por defecto, instalar Docker Desktop, autenticar `gh`, e identidad de git (personal/trabajo). No agregar prompts para cosas que se pueden resolver con un default sensato.

## Qué instala el script (resumen)

Ver tabla completa en `README.md` → sección "Qué instala". En breve: Homebrew, git (identidad dual personal/trabajo vía `includeIf`), gh, nvm+Node+pnpm+yarn, zsh + plugins (completions, fzf-tab, autosuggestions, syntax-highlighting, fzf), Starship, zoxide/bat/eza, Ghostty (tema + fuente), kubectl/k9s/kubectx/stern, Docker+lazydocker, lazysql, vi-mongo+mongosh, Neovim+LazyVim (extras: typescript, vue, astro, tailwind, json, prettier, eslint + dashboard personalizado + `lazyvim_check_order` desactivado), tmux+TPM.

## Identidad de git (importante, no romper)

El script configura **dos identidades de git automáticas por carpeta**:

- Personal (default en `~/.gitconfig`): aplica fuera de la carpeta de trabajo.
- Trabajo (`~/.gitconfig-work`): aplica solo dentro de `~/Development/Movatec/` vía `includeIf "gitdir:...`.

Al modificar esta lógica, **siempre probar con un `$HOME` temporal** (ver ejemplo de prueba en el historial de cambios) antes de tocar el archivo real del usuario.

## Al terminar un cambio

1. `bash -n setup-terminal-stack.sh` → confirmar sintaxis OK.
2. Actualizar `README.md` en las secciones correspondientes: tabla de "Qué instala", y agregar una entrada numerada nueva en "Troubleshooting" si el cambio corrige un error real que el usuario encontró (seguir el formato: Causa → Ya corregido en el script → Arreglar manualmente si hace falta).
3. Recordar al usuario que los cambios en este repo no se reflejan solos en su Mac — debe descargar/copiar el archivo actualizado y luego `git add . && git commit && git push`.

## Cosas explícitamente fuera de alcance de este script

- No instala WebStorm, VSCode, Antigravity, Lens ni Docker Desktop como reemplazo forzado (Docker Desktop sí se ofrece instalar si falta, pero como dependencia de `lazydocker`, no como parte del "stack de terminal").
- No configura SSH keys, GPG signing de commits, ni credenciales de ningún tipo — fuera del alcance de una guía de terminal tooling.
- No gestiona secretos ni variables de entorno de proyectos individuales.
