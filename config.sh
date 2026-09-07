#!/usr/bin/env bash
#
# setup-terminal-stack.sh
#
# Instalación reproducible del stack de terminal:
# Warp (+ tema, fuente Nerd Font) + zsh (completions, fzf-tab clonado,
# autosuggestions, syntax-highlighting, fzf) + Starship (prompt) +
# zoxide/bat/eza + git config + pnpm + kubectl/k9s + Docker/lazydocker +
# lazysql + lazymongo + LazyVim (+ extras typescript/vue/astro/tailwind/json/
# prettier/eslint + dashboard personalizado) + tmux (+ TPM y plugins) +
# Claude Code + Antigravity CLI
#
# Diseñado para correr en cualquier Mac (Apple Silicon o Intel) sin romper
# nada existente. Es idempotente: puedes correrlo varias veces.
#
# Uso:
#   chmod +x setup-terminal-stack.sh
#   ./setup-terminal-stack.sh
#
set -euo pipefail

ZSHRC="$HOME/.zshrc"
NVIM_CONFIG="$HOME/.config/nvim"

# ---------- helpers ----------

log() {
  echo -e "\n\033[1;32m==> $1\033[0m"
}

warn() {
  echo -e "\033[1;33m!! $1\033[0m"
}

append_once() {
  # append_once "línea a agregar" "$ZSHRC"
  local line="$1"
  local file="$2"
  if ! grep -qF "$line" "$file" 2>/dev/null; then
    echo "$line" >> "$file"
    echo "  + agregado a $file"
  else
    echo "  = ya estaba en $file, se omite"
  fi
}

# ---------- 0. Homebrew ----------

log "Verificando Homebrew"
if ! command -v brew &>/dev/null; then
  warn "Homebrew no encontrado. Instalando..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Cargar brew en esta misma sesión del script (ruta distinta según arquitectura)
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"   # Apple Silicon
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"      # Intel
  else
    echo "No se pudo localizar brew tras la instalación. Cierra y abre una terminal nueva y vuelve a correr este script."
    exit 1
  fi

  # Dejarlo persistente para futuras sesiones de shell
  touch "$ZSHRC"
  if [ -x "/opt/homebrew/bin/brew" ]; then
    append_once 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$ZSHRC"
  elif [ -x "/usr/local/bin/brew" ]; then
    append_once 'eval "$(/usr/local/bin/brew shellenv)"' "$ZSHRC"
  fi
else
  echo "  Homebrew OK ($(brew --version | head -1))"
fi

# ---------- Interactive Menu & Options ----------

RUN_ALL=false
SELECTED_MODULES=""

for arg in "$@"; do
  if [ "$arg" = "--all" ] || [ "$arg" = "-a" ] || [ "$arg" = "--yes" ] || [ "$arg" = "-y" ]; then
    RUN_ALL=true
  fi
done

should_run() {
  local num="$1"
  if [ "$RUN_ALL" = "true" ] || [ -z "$SELECTED_MODULES" ] || echo "$SELECTED_MODULES" | grep -q "^$num\."; then
    return 0
  else
    return 1
  fi
}

if [ "$RUN_ALL" = "false" ]; then
  echo -e "
[1;36m=========================================================[0m"
  echo -e "[1;36m  🚀 SELECCIONA QUÉ MÓDULOS INSTALAR / CONFIGURAR     [0m"
  echo -e "[1;36m=========================================================[0m"
  echo -e "Uso: Usa [TAB] o [ESPACIO] para seleccionar/desmarcar."
  echo -e "     Presiona [ENTER] para confirmar y comenzar."
  echo -e "     (o ejecuta './config.sh --all' para instalar todo sin menú)
"

  # Asegurar que fzf esté disponible
  if ! command -v fzf &>/dev/null; then
    echo -e "[1;33mInstalando fzf para el menú interactivo...[0m"
    brew install fzf &>/dev/null || true
  fi

  if command -v fzf &>/dev/null; then
    SELECTED_MODULES=$(cat <<'EOF_FZF' | fzf --multi --prompt="Selecciona módulos > " --header="[TAB/ESPACIO]: Marcar/Desmarcar | [ENTER]: Confirmar" --height=50% --border=rounded --color=dark
1. Git & GitHub CLI (gh + identidades por carpeta)
2. Node.js (NVM + Node LTS + pnpm)
3. Zsh Plugins, Fuente Nerd Font & Starship Prompt
4. Herramientas CLI (zoxide, bat, eza, fd, ripgrep, speedtest)
5. Kubernetes Tools (kubectl, k9s, kubectx, stern)
6. Docker Tools (Colima, Docker CLI, lazydocker)
7. Bases de Datos SQL (Harlequin + Lazysql)
8. MongoDB Tools (Lazymongo + mongosh + vi-mongo + alias mgo)
9. Neovim & LazyVim (LSPs, extras, Mergetool 3-way)
10. Tmux & TPM Plugins
11. Asistentes de IA CLI (Claude Code + Graphify)
12. Aplicaciones GUI Casks (Warp, Lens, Docker Desktop, Android Studio, Compass, Cursor, Chrome, Claude Desktop, Redis Insight)
13. Configuración, Atajos y Extensiones de Cursor (80+ plugins)
EOF_FZF
    )
    if [ -z "$SELECTED_MODULES" ]; then
      echo -e "
[1;33mNo se seleccionó ningún módulo. Saliendo sin realizar cambios.[0m"
      exit 0
    fi
  else
    RUN_ALL=true
  fi
fi

if should_run 1; then
# ---------- 1. git ----------

log "Verificando git"
if ! command -v git &>/dev/null; then
  warn "git no encontrado. Instalando Xcode Command Line Tools (incluye git)..."
  xcode-select --install || warn "Si ya se está instalando o falló, revisa manualmente con: xcode-select --install"
else
  echo "  git OK ($(git --version))"
fi

log "Configurando git mergetool con Neovim (nvim -d)"
git config --global merge.tool nvim
git config --global mergetool.nvim.cmd 'nvim -d "$LOCAL" "$REMOTE" "$MERGED"'
git config --global mergetool.nvim.trustExitCode true

log "Configurando identidad de git por carpeta (personal vs. trabajo)"
GIT_NAME="$(git config --global user.name || true)"
GIT_EMAIL="$(git config --global user.email || true)"

if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ] && [ -f "$HOME/.gitconfig-work" ]; then
  echo "  Identidad personal (default): $GIT_NAME <$GIT_EMAIL>"
  echo "  Identidad de trabajo: ya configurada en ~/.gitconfig-work"
else
  warn "Configurando identidad por primera vez."

  read -r -p "  Carpeta de proyectos personales [$HOME/Development/jonathanleivag]: " personal_dir
  personal_dir="${personal_dir:-$HOME/Development/jonathanleivag}"

  read -r -p "  Carpeta de proyectos de trabajo [$HOME/Development/Movatec]: " work_dir
  work_dir="${work_dir:-$HOME/Development/Movatec}"

  # Asegurar slash final (requisito de git para includeIf "gitdir:")
  [[ "$personal_dir" != */ ]] && personal_dir="$personal_dir/"
  [[ "$work_dir" != */ ]] && work_dir="$work_dir/"

  if [ -z "$GIT_NAME" ]; then
    read -r -p "  Tu nombre (perfil PERSONAL): " personal_name
  else
    personal_name="$GIT_NAME"
  fi
  if [ -z "$GIT_EMAIL" ]; then
    read -r -p "  Tu email (perfil PERSONAL): " personal_email
  else
    personal_email="$GIT_EMAIL"
  fi

  read -r -p "  Tu nombre (perfil TRABAJO): " work_name
  read -r -p "  Tu email (perfil TRABAJO): " work_email

  # Identidad por defecto = personal (aplica a cualquier carpeta que no sea la de trabajo)
  git config --global user.name "$personal_name"
  git config --global user.email "$personal_email"

  # Config separada para trabajo
  cat > "$HOME/.gitconfig-work" <<EOF
[user]
  name = $work_name
  email = $work_email
EOF

  # includeIf: cuando el repo esté dentro de la carpeta de trabajo, usa .gitconfig-work
  if ! grep -qF "gitdir:$work_dir" "$HOME/.gitconfig" 2>/dev/null; then
    cat >> "$HOME/.gitconfig" <<EOF

[includeIf "gitdir:$work_dir"]
  path = ~/.gitconfig-work
EOF
  fi

  echo "  Personal (default): $personal_name <$personal_email> — aplica fuera de $work_dir"
  echo "  Trabajo: $work_name <$work_email> — aplica dentro de $work_dir"
fi

log "Verificando GitHub CLI (gh)"
if command -v gh &>/dev/null; then
  echo "  gh OK ($(gh --version | head -1))"
else
  warn "gh no encontrado. Instalando..."
  brew install gh
fi

log "Verificando autenticación de gh"
if gh auth status &>/dev/null; then
  echo "  Ya autenticado con GitHub ($(gh auth status 2>&1 | grep 'Logged in' | head -1 | xargs))"
else
  warn "No hay sesión activa de GitHub CLI."
  read -r -p "  ¿Quieres autenticarte ahora con 'gh auth login'? (y/n) " respuesta_gh
  if [ "$respuesta_gh" = "y" ] || [ "$respuesta_gh" = "Y" ]; then
    gh auth login
  else
    warn "Se omite. Corre 'gh auth login' manualmente cuando quieras conectar tu cuenta."
  fi
fi

log "Verificando lazygit"
if brew list lazygit &>/dev/null; then
  echo "  lazygit OK, ya instalado"
else
  warn "lazygit no encontrado. Instalando..."
  brew install lazygit
fi

log "Configurando lazygit (customCommands con IA y Mergetool Neovim)"
LAZYGIT_CONFIG_DIR="$HOME/Library/Application Support/lazygit"
mkdir -p "$LAZYGIT_CONFIG_DIR"
cat > "$LAZYGIT_CONFIG_DIR/config.yml" <<'EOF'
git:
  mergetool:
    cmd: 'nvim -d "$LOCAL" "$REMOTE" "$MERGED"'
    prompt: false
os:
  editPreset: 'nvim'

customCommands:
  # --- SECCIÓN DE ARCHIVOS (Files Panel) ---
  # Generar commit automático con IA en INGLÉS y revisar/confirmar antes de hacer commit
  - key: 'g'
    command: >
      git commit -e -m "$(git diff --cached | agy --dangerously-skip-permissions -p 'Analyze the staged git diff and generate a concise Conventional Commit message in ENGLISH in a single line. Return ONLY the commit message text, with no quotes, explanations or markdown formatting.')"
    context: 'files'
    loadingText: 'Generating AI commit message in English...'
    subprocess: true

  # Explicar los cambios del archivo seleccionado (staged y unstaged)
  - key: 'x'
    command: >
      agy --dangerously-skip-permissions -p "Explica de forma concisa los cambios realizados en el archivo {{.SelectedFile.Name}}:\n\n$(git diff HEAD -- {{.SelectedFile.Name}})"
    context: 'files'
    loadingText: 'Explicando cambios del archivo con IA...'
    subprocess: true

  # --- SECCIÓN DE COMMITS (Commits Panel) ---
  # Explicar los cambios y propósito del commit seleccionado
  - key: 'x'
    command: >
      agy --dangerously-skip-permissions -p "Explica qué hace este commit y resume los cambios principales de forma concisa y directa:\n\n$(git show {{.SelectedLocalCommit.Hash}})"
    context: 'commits'
    loadingText: 'Analizando commit con IA...'
    subprocess: true

  # --- SECCIÓN DE RAMAS (Local Branches Panel) ---
  # Copiar el nombre de la rama seleccionada al portapapeles con 'y'
  - key: 'y'
    command: 'printf "%s" {{.SelectedLocalBranch.Name | quote}} | pbcopy'
    context: 'localBranches'
    description: 'Copiar nombre de la rama local al portapapeles'

  # Resumir todos los cambios de la rama seleccionada en comparación con main
  - key: 'x'
    command: >
      agy --dangerously-skip-permissions -p "Resume los cambios realizados en la rama local '{{.SelectedLocalBranch.Name}}' en comparación con la rama principal (main):\n\n$(git diff main...{{.SelectedLocalBranch.Name}})"
    context: 'localBranches'
    loadingText: 'Resumiendo cambios de la rama con IA...'
    subprocess: true

  # --- SECCIÓN DE RAMAS REMOTAS (Remote Branches Panel) ---
  # Copiar el nombre de la rama remota seleccionada al portapapeles con 'y'
  - key: 'y'
    command: 'printf "%s" {{.SelectedRemoteBranch.Name | quote}} | pbcopy'
    context: 'remoteBranches'
    description: 'Copiar nombre de la rama remota al portapapeles'
EOF
echo "  Config de lazygit creada/actualizada en $LAZYGIT_CONFIG_DIR/config.yml"

fi

if should_run 2; then
# ---------- 2. nvm (Node Version Manager) ----------

log "Verificando nvm"
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh"
fi

if ! command -v nvm &>/dev/null; then
  warn "nvm no encontrado. Instalando..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

  # Cargarlo en esta misma sesión del script
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
else
  echo "  nvm OK ($(nvm --version))"
fi

# Asegurar que quede en .zshrc para futuras sesiones (el instalador de nvm
# normalmente ya lo agrega, pero lo confirmamos por si acaso)
touch "$HOME/.zshrc"
append_once 'export NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc"
append_once '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' "$HOME/.zshrc"
append_once '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' "$HOME/.zshrc"

# Instalar Node LTS si no hay ninguna versión de node instalada vía nvm
if command -v nvm &>/dev/null && [ -z "$(nvm ls --no-colors 2>/dev/null | grep -v 'N/A')" ]; then
  log "No hay versiones de Node instaladas vía nvm, instalando LTS"
  nvm install --lts
  nvm alias default lts/*
fi

log "Verificando pnpm (vía corepack, incluido con Node)"
if command -v corepack &>/dev/null; then
  corepack enable 2>/dev/null || warn "corepack enable falló, revisa permisos o corre manualmente"

  if command -v pnpm &>/dev/null; then
    echo "  pnpm OK ($(pnpm --version))"
  else
    warn "Activando pnpm vía corepack..."
    corepack prepare pnpm@latest --activate
  fi
else
  warn "corepack no encontrado (viene con Node 16.10+). Instalando pnpm como paquete global de npm en su lugar..."
  npm install -g pnpm
fi

fi

if should_run 3; then
# ---------- 3. zsh ----------

log "Verificando zsh"
if command -v zsh &>/dev/null; then
  echo "  zsh OK ($(zsh --version))"
else
  warn "zsh no encontrado. Instalando..."
  brew install zsh
fi

log "Verificando que zsh sea tu shell por defecto"
if [ "$SHELL" != "$(command -v zsh)" ] && [ "$SHELL" != "/bin/zsh" ]; then
  warn "Tu shell actual es '$SHELL', no zsh."
  read -r -p "  ¿Quieres que este script lo cambie a zsh como default? (y/n) " respuesta
  if [ "$respuesta" = "y" ] || [ "$respuesta" = "Y" ]; then
    ZSH_PATH="$(command -v zsh)"
    # chsh necesita que el shell esté listado en /etc/shells
    if ! grep -qF "$ZSH_PATH" /etc/shells; then
      echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$ZSH_PATH"
    echo "  Shell cambiado a $ZSH_PATH. Se aplicará al abrir una terminal nueva."
  else
    warn "Se omite el cambio de shell. El resto de la configuración (.zshrc) se deja lista de todas formas,"
    warn "pero no tendrá efecto hasta que uses zsh como shell activo."
  fi
else
  echo "  zsh ya es tu shell por defecto"
fi

# ---------- 4. Fuentes de Letras (Warp & Cursor) ----------

log "Verificando fuente JetBrainsMono Nerd Font (usada por Warp Terminal)"
if brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
  echo "  JetBrainsMono Nerd Font OK, ya instalada"
else
  warn "JetBrainsMono Nerd Font no encontrada. Instalando..."
  brew install --cask font-jetbrains-mono-nerd-font
fi

log "Verificando fuente Victor Mono (usada por Cursor Editor & Neovim)"
if brew list --cask font-victor-mono &>/dev/null; then
  echo "  Victor Mono OK, ya instalada"
else
  warn "Victor Mono no encontrada. Instalando..."
  brew install --cask font-victor-mono
fi

# ---------- 5. Shell: zsh plugins ----------

touch "$ZSHRC"

log "Verificando zsh-completions"
if brew list zsh-completions &>/dev/null; then
  echo "  zsh-completions OK, ya instalado"
else
  warn "zsh-completions no encontrado. Instalando..."
  brew install zsh-completions
fi
# fpath debe agregarse ANTES de compinit
append_once "FPATH=$(brew --prefix)/share/zsh-completions:\$FPATH" "$ZSHRC"
append_once "autoload -Uz compinit && compinit" "$ZSHRC"

log "Verificando fzf-tab"
FZF_TAB_DIR="$HOME/.zsh-plugins/fzf-tab"
if [ -d "$FZF_TAB_DIR" ]; then
  echo "  fzf-tab OK, ya instalado en $FZF_TAB_DIR"
else
  warn "fzf-tab no encontrado. Clonando desde GitHub..."
  mkdir -p "$HOME/.zsh-plugins"
  git clone --depth=1 https://github.com/Aloxaf/fzf-tab "$FZF_TAB_DIR"
fi

# Limpiar línea rota de una versión anterior del script (usaba brew, ruta inexistente)
# No se usa `sed -i` porque falla si $ZSHRC es un symlink (ej. dotfiles gestionados
# aparte, como ~/.zshrc -> ~/.gemini/.zshrc): "in-place editing only works for
# regular files". En vez de eso, se reescribe vía archivo temporal + redirección,
# que sigue el symlink y preserva el archivo real al que apunta.
if grep -qF "brew)/share/fzf-tab/fzf-tab.plugin.zsh" "$ZSHRC" 2>/dev/null; then
  warn "Eliminando línea rota de fzf-tab de una instalación anterior en $ZSHRC"
  grep -v '/share/fzf-tab/fzf-tab.plugin.zsh' "$ZSHRC" > "$ZSHRC.tmp"
  cat "$ZSHRC.tmp" > "$ZSHRC"
  rm -f "$ZSHRC.tmp"
fi

# fzf-tab debe cargarse DESPUÉS de compinit y ANTES de autosuggestions/syntax-highlighting
append_once "source $FZF_TAB_DIR/fzf-tab.plugin.zsh" "$ZSHRC"

log "Verificando zsh-autosuggestions"
if brew list zsh-autosuggestions &>/dev/null; then
  echo "  zsh-autosuggestions OK, ya instalado"
else
  warn "zsh-autosuggestions no encontrado. Instalando..."
  brew install zsh-autosuggestions
fi
append_once "source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "$ZSHRC"

log "Verificando fzf"
if brew list fzf &>/dev/null; then
  echo "  fzf OK, ya instalado"
else
  warn "fzf no encontrado. Instalando..."
  brew install fzf
fi
# --key-bindings y --completion sin prompts interactivos, --no-update-rc porque lo manejamos manual
"$(brew --prefix)"/opt/fzf/install --key-bindings --completion --no-update-rc
append_once "[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh" "$ZSHRC"

log "Verificando zsh-syntax-highlighting"
if brew list zsh-syntax-highlighting &>/dev/null; then
  echo "  zsh-syntax-highlighting OK, ya instalado"
else
  warn "zsh-syntax-highlighting no encontrado. Instalando..."
  brew install zsh-syntax-highlighting
fi
# IMPORTANTE: syntax-highlighting debe ir al FINAL del .zshrc, siempre
append_once "source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" "$ZSHRC"

# ---------- 6. Starship (prompt) ----------

log "Verificando Starship"
if brew list starship &>/dev/null; then
  echo "  Starship OK, ya instalado"
else
  warn "Starship no encontrado. Instalando..."
  brew install starship
fi
# El init de starship debe ir al final del .zshrc (después de syntax-highlighting)
append_once 'eval "$(starship init zsh)"' "$ZSHRC"

STARSHIP_CONFIG_DIR="$HOME/.config"
STARSHIP_CONFIG_FILE="$STARSHIP_CONFIG_DIR/starship.toml"

# Identificador de equipo (usuario - modelo de Mac + chip/procesador), cacheado
# en un archivo porque `system_profiler` es lento para correr en cada prompt.
STARSHIP_MACHINE_FILE="$HOME/.config/starship/machine.txt"
mkdir -p "$(dirname "$STARSHIP_MACHINE_FILE")"
MAC_MODEL_NAME="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/{print $2; exit}')"
MAC_CHIP="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/^ *Chip/{print $2; exit}')"
if [ -z "$MAC_CHIP" ]; then
  # Macs Intel no tienen línea "Chip", sino "Processor Name"
  MAC_CHIP="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Processor Name/{print $2; exit}')"
fi
echo "jonathanleivag - ${MAC_MODEL_NAME} ${MAC_CHIP}" > "$STARSHIP_MACHINE_FILE"

if [ -f "$STARSHIP_CONFIG_FILE" ]; then
  warn "Ya existe $STARSHIP_CONFIG_FILE — no se sobreescribe."
  if ! grep -q '\[custom.machine\]' "$STARSHIP_CONFIG_FILE"; then
    cat >> "$STARSHIP_CONFIG_FILE" <<'EOF'

# Oculta la cuenta de gcloud (símbolo ☁️  por defecto) y muestra en su lugar
# el equipo actual, cacheado en ~/.config/starship/machine.txt
[gcloud]
disabled = true

[custom.machine]
command = "cat ~/.config/starship/machine.txt 2>/dev/null"
when = true
symbol = "</> "
format = "on [$symbol$output]($style) "
EOF
    echo "  + segmento de equipo agregado a $STARSHIP_CONFIG_FILE"
  else
    echo "  OK, segmento de equipo ya presente en $STARSHIP_CONFIG_FILE"
  fi
else
  mkdir -p "$STARSHIP_CONFIG_DIR"
  cat > "$STARSHIP_CONFIG_FILE" <<'EOF'
# Config inicial de Starship — muestra git branch/estado, node, y tiempo de ejecución
add_newline = false

[git_branch]
symbol = " "

[git_status]
disabled = false

[nodejs]
symbol = " "

[cmd_duration]
min_time = 500
format = "took [$duration]($style) "

# Oculta la cuenta de gcloud (símbolo ☁️  por defecto) y muestra en su lugar
# el equipo actual, cacheado en ~/.config/starship/machine.txt
[gcloud]
disabled = true

[custom.machine]
command = "cat ~/.config/starship/machine.txt 2>/dev/null"
when = true
symbol = "</> "
format = "on [$symbol$output]($style) "
EOF
  echo "  Config creada en $STARSHIP_CONFIG_FILE"
fi

fi

if should_run 4; then
# ---------- 7. Utilidades modernas de CLI (zoxide, bat, eza) ----------

log "Verificando zoxide (cd inteligente)"
if brew list zoxide &>/dev/null; then
  echo "  zoxide OK, ya instalado"
else
  warn "zoxide no encontrado. Instalando..."
  brew install zoxide
fi
append_once 'eval "$(zoxide init zsh)"' "$ZSHRC"

log "Verificando bat (cat con resaltado de sintaxis)"
if brew list bat &>/dev/null; then
  echo "  bat OK, ya instalado"
else
  warn "bat no encontrado. Instalando..."
  brew install bat
fi

log "Verificando eza (ls moderno)"
if brew list eza &>/dev/null; then
  echo "  eza OK, ya instalado"
else
  warn "eza no encontrado. Instalando..."
  brew install eza
fi

log "Verificando Speedtest de Ookla (CLI oficial de prueba de velocidad)"
if brew list speedtest &>/dev/null; then
  echo "  speedtest OK, ya instalado"
else
  warn "speedtest no encontrado. Instalando..."
  brew tap teamookla/speedtest
  brew trust teamookla/speedtest 2>/dev/null || true
  brew install speedtest --force
fi

log "Verificando Harlequin (IDE SQL interactivo para terminal)"
if brew list harlequin &>/dev/null; then
  echo "  harlequin OK, ya instalado"
else
  warn "harlequin no encontrado. Instalando..."
  brew install harlequin
fi

log "Configurando perfiles de conexión y keymap Vim de Harlequin (~/.config/harlequin/config.toml)"
mkdir -p "$HOME/.config/harlequin"
cat > "$HOME/.config/harlequin/config.toml" <<'EOF'
default_profile = "vicidial prod"

[profiles."vicidial prod"]
adapter = "mysql"
host = "172.16.1.23"
port = 3306
user = "root"
password = "T3c4dmin1234."
database = "asterisk"
theme = "catppuccin-frappe"
viewer_max_rows = 100000
keymap_name = ["vscode", "lazygit_keys"]

[keymaps]
lazygit_keys = [
  { action = "focus_data_catalog", keys = "f6", key_display = "f6 Catalog" },
  { action = "code_editor.focus_data_catalog", keys = "f6", key_display = "f6 Catalog" },
  { action = "results_viewer.focus_data_catalog", keys = "f6", key_display = "f6 Catalog" },

  { action = "focus_query_editor", keys = "f2", key_display = "f2 Editor" },
  { action = "data_catalog.focus_query_editor", keys = "f2", key_display = "f2 Editor" },
  { action = "results_viewer.focus_query_editor", keys = "f2", key_display = "f2 Editor" },

  { action = "focus_results_viewer", keys = "f5", key_display = "f5 Results" },
  { action = "data_catalog.focus_results_viewer", keys = "f5", key_display = "f5 Results" },
  { action = "code_editor.focus_results_viewer", keys = "f5", key_display = "f5 Results" },

  { action = "data_catalog.cursor_down", keys = "j, down" },
  { action = "data_catalog.cursor_up", keys = "k, up" },
  { action = "data_catalog.toggle_node", keys = "l, h, space" },
  { action = "data_catalog.select_cursor", keys = "l, enter" },

  { action = "results_viewer.cursor_down", keys = "j, down" },
  { action = "results_viewer.cursor_up", keys = "k, up" },
  { action = "results_viewer.cursor_left", keys = "h, left" },
  { action = "results_viewer.cursor_right", keys = "l, right" },
  { action = "results_viewer.copy_selection", keys = "y, ctrl+c", key_display = "y Copy" },
  { action = "results_viewer.select_all", keys = "shift+y, Y", key_display = "Y Select All" }
]
EOF
cp "$HOME/.config/harlequin/config.toml" "$HOME/.harlequin.toml"
echo "  Perfiles y keymaps de Harlequin respaldados en ~/.config/harlequin/config.toml y ~/.harlequin.toml"

log "Configurando alias (cat, ls, cd -> bat, eza, zoxide)"
append_once 'alias cat="bat"' "$ZSHRC"
append_once 'alias ls="eza --icons --group-directories-first"' "$ZSHRC"
append_once 'alias ll="eza -la --icons --group-directories-first"' "$ZSHRC"
append_once 'alias lt="eza --tree --icons --level=2"' "$ZSHRC"
append_once 'alias cd="z"' "$ZSHRC"
append_once 'alias e="exit"' "$ZSHRC"
append_once 'alias cl="clear"' "$ZSHRC"
append_once 'alias vi="nvim"' "$ZSHRC"
append_once 'alias gg="lazygit"' "$ZSHRC"
append_once 'alias lazymongo="~/go/bin/lazymongo"' "$ZSHRC"
append_once 'alias lezymongo="lazymongo"' "$ZSHRC"
append_once 'alias lm="$HOME/go/bin/lazymongo"' "$ZSHRC"
append_once 'alias tm="tmux-mosaic"' "$ZSHRC"
append_once 'alias hq="$HOME/.local/bin/harlequin-launcher"' "$ZSHRC"
append_once 'alias hsql="$HOME/.local/bin/harlequin-launcher"' "$ZSHRC"
append_once 'alias harlequin="$HOME/.local/bin/harlequin-launcher"' "$ZSHRC"
append_once 'alias lsql="lazysql"' "$ZSHRC"

# Alias de Colima & Docker
append_once 'alias cos="colima start --cpu 2 --memory 4"' "$ZSHRC"
append_once 'alias cox="colima stop"' "$ZSHRC"
append_once 'alias coh="colima status"' "$ZSHRC"
append_once 'alias d="docker"' "$ZSHRC"
append_once 'alias dc="docker compose"' "$ZSHRC"
append_once 'alias dps="docker ps --format '\''table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'\''"' "$ZSHRC"
append_once 'alias di="docker images"' "$ZSHRC"
append_once 'alias dexec="docker exec -it"' "$ZSHRC"
append_once 'alias dlogs="docker logs -f"' "$ZSHRC"
append_once 'alias dclean="docker system prune -a --volumes"' "$ZSHRC"
append_once 'alias ld="lazydocker"' "$ZSHRC"

if ! grep -q "ia()" "$ZSHRC" 2>/dev/null; then
  cat <<'EOF' >> "$ZSHRC"

# ia: Abre un mosaico de terminales (mosaico tmux) con Antigravity (arriba) y Claude Code (abajo)
ia() {
  if [ -n "$TMUX" ]; then
    # Ya estamos dentro de una sesión de tmux: creamos una nueva ventana
    local p1=$(tmux new-window -n "AI-Mosaic" -P -F "#{pane_id}" 'zsh')
    # Dividimos verticalmente para crear el panel inferior (Claude)
    local p2=$(tmux split-window -v -t "$p1" -P -F "#{pane_id}" 'zsh')
    
    # Enviamos los comandos correspondientes
    tmux send-keys -t "$p1" 'agy' C-m
    tmux send-keys -t "$p2" 'claude' C-m
    tmux select-pane -t "$p2"
  else
    # Fuera de tmux: creamos una nueva sesión o nos reconectamos a una existente
    if tmux has-session -t ia 2>/dev/null; then
      tmux attach-session -t ia
    else
      local p1=$(tmux new-session -d -s ia -n "AI-Mosaic" -x "${COLUMNS:-200}" -y "${LINES:-50}" -P -F "#{pane_id}" 'zsh')
      local p2=$(tmux split-window -v -t "$p1" -P -F "#{pane_id}" 'zsh')
      
      tmux send-keys -t "$p1" 'agy' C-m
      tmux send-keys -t "$p2" 'claude' C-m
      tmux select-pane -t "$p2"
      
      tmux attach-session -t ia
    fi
  fi
}
EOF
  echo "  + función 'ia' agregada a $ZSHRC"
fi

fi

if should_run 5; then
# ---------- 8. Kubernetes ----------

log "Verificando kubectl"
if command -v kubectl &>/dev/null; then
  echo "  kubectl OK ($(kubectl version --client --short 2>/dev/null || echo 'instalado'))"
else
  warn "kubectl no encontrado. Instalando..."
  brew install kubectl
fi

log "Verificando contextos de kubeconfig"
if kubectl config get-contexts &>/dev/null && [ -n "$(kubectl config get-contexts -o name 2>/dev/null)" ]; then
  echo "  Contextos encontrados en ~/.kube/config, k9s podrá usarlos directamente"
else
  warn "No se encontraron contextos de Kubernetes configurados (~/.kube/config vacío o ausente)."
  warn "k9s se instalará igual, pero necesitarás configurar tu kubeconfig antes de usarlo"
  warn "(por ejemplo, exportando el config de tu proveedor cloud o copiándolo desde donde ya lo usas con Lens)."
fi

# Configurar cargador dinámico de kubeconfigs en .zshrc
if ! grep -qF "Cargar dinámicamente todos los archivos de configuración de Kubernetes" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" <<'EOF'

# Cargar dinámicamente todos los archivos de configuración de Kubernetes (config-*) en ~/.kube/
export KUBECONFIG="$HOME/.kube/config"
for config_file in "$HOME"/.kube/config-*(N); do
  if [ -f "$config_file" ]; then
    export KUBECONFIG="$KUBECONFIG:$config_file"
  fi
done
EOF
  echo "  + cargador dinámico de Kubeconfig agregado a $ZSHRC"
else
  echo "  OK, cargador dinámico de Kubeconfig ya configurado en $ZSHRC"
fi

log "Instalando k9s (+ kubectx/kubens, stern)"
brew install k9s kubectx stern

log "Configurando k9s (Skin Catppuccin Mocha y soporte para mouse)"
if [ "$(uname)" = "Darwin" ]; then
  K9S_CONFIG_DIR="$HOME/Library/Application Support/k9s"
else
  K9S_CONFIG_DIR="$HOME/.config/k9s"
fi
mkdir -p "$K9S_CONFIG_DIR/skins"

cat > "$K9S_CONFIG_DIR/config.yaml" <<'EOF'
k9s:
  refreshRate: 2
  maxRequestsCol: 500
  infoColor:
    fg: lightskyblue
  ui:
    enableMouse: true
    skin: catppuccin-mocha
  headless: false
  logoless: false
  crumbsless: false
  readOnly: false
  noIcons: false
  logger:
    tail: 100
    buffer: 5000
    limit: 100
    wrap: true
    showTime: false
  thresholds:
    cpu:
      critical: 90
      warn: 70
    memory:
      critical: 90
      warn: 70
EOF

cat > "$K9S_CONFIG_DIR/skins/catppuccin-mocha.yaml" <<'EOF'
# Catppuccin Mocha Skin for K9s
k9s:
  body:
    fgColor: "#cdd6f4"
    bgColor: default
    logoColor: "#cba6f7"
  prompt:
    fgColor: "#cdd6f4"
    bgColor: default
    suggestColor: "#89b4fa"
  help:
    fgColor: "#cdd6f4"
    bgColor: default
    sectionColor: "#a6e3a1"
    keyColor: "#89b4fa"
    numKeyColor: "#eba0ac"
  dialog:
    fgColor: "#cdd6f4"
    bgColor: default
    buttonFgColor: "#11111b"
    buttonBgColor: "#cba6f7"
    activeButtonFgColor: "#11111b"
    activeButtonBgColor: "#a6e3a1"
    maskBgColor: default
  frame:
    border:
      fgColor: "#585b70"
      focusColor: "#cba6f7"
    menu:
      fgColor: "#bac2de"
      keyColor: "#f38ba8"
      numKeyColor: "#fab387"
    crumbs:
      fgColor: "#11111b"
      bgColor: "#f5c2e7"
      activeBgColor: "#cba6f7"
    status:
      newColor: "#89b4fa"
      modifyColor: "#f9e2af"
      deleteColor: "#f38ba8"
      pendingColor: "#fab387"
      errorColor: "#f38ba8"
      highlightColor: "#a6e3a1"
      killColor: "#f38ba8"
      completedColor: "#bac2de"
    title:
      fgColor: "#89b4fa"
      bgColor: default
      highlightColor: "#f5c2e7"
      counterColor: "#cba6f7"
      filterColor: "#f38ba8"
  views:
    charts:
      bgColor: default
      defaultDialColor: "#89b4fa"
      defaultChartColor: "#89b4fa"
      resourceColors:
        cpu:
          - "#89b4fa"
          - "#f9e2af"
          - "#f38ba8"
        mem:
          - "#89b4fa"
          - "#f9e2af"
          - "#f38ba8"
    table:
      fgColor: "#cdd6f4"
      bgColor: default
      cursorFgColor: "#11111b"
      cursorBgColor: "#cba6f7"
      cursorLineFgColor: "#cdd6f4"
      cursorLineBgColor: "#313244"
      markFgColor: "#a6e3a1"
      markBgColor: default
      header:
        fgColor: "#f9e2af"
        bgColor: default
        sorterFgColor: "#cba6f7"
    xray:
      fgColor: "#cdd6f4"
      bgColor: default
      cursorFgColor: "#11111b"
      cursorBgColor: "#cba6f7"
      graphicColor: "#cba6f7"
      showVisualizer: true
    yaml:
      keyColor: "#f38ba8"
      valueColor: "#cdd6f4"
      colonColor: "#bac2de"
    logs:
      fgColor: "#cdd6f4"
      bgColor: default
      indicator:
        fgColor: "#cba6f7"
        bgColor: default
EOF
echo "  Configuración y skin de k9s creados exitosamente."

log "Configurando editor por defecto en .zshrc para k9s y kubectl"
if ! grep -qF "K9S_EDITOR" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" <<'EOF'

# Editor preferido para herramientas CLI (k9s, git, kubectl, etc.)
export EDITOR="nvim"
export K9S_EDITOR="nvim"
EOF
  echo "  + EDITOR y K9S_EDITOR agregados a $ZSHRC"
else
  echo "  OK, EDITOR y K9S_EDITOR ya configurados en $ZSHRC"
fi

fi

if should_run 6; then
# ---------- 9. Colima & Docker ----------

log "Verificando Colima (Docker sin Docker Desktop)"
if command -v colima &>/dev/null; then
  echo "  Colima OK ($(colima version | head -n 1))"
else
  warn "Colima no encontrado. Instalando Colima y Docker CLI..."
  brew install colima docker docker-buildx
  # Configurar plugin de buildx para que Docker lo reconozca
  mkdir -p "$HOME/.docker/cli-plugins"
  ln -sfn "$(brew --prefix)/opt/docker-buildx/bin/docker-buildx" "$HOME/.docker/cli-plugins/docker-buildx"
fi

log "Verificando si Colima está corriendo"
if colima status &>/dev/null; then
  echo "  Colima está corriendo y el socket de Docker está activo."
else
  warn "Colima no está iniciado. Iniciando Colima..."
  # Iniciamos Colima con recursos balanceados (2 CPUs, 4GB RAM)
  colima start --cpu 2 --memory 4
fi

log "Verificando Docker Daemon"
if docker info &>/dev/null; then
  echo "  Docker daemon responde correctamente."
else
  warn "El daemon de Docker no responde. Intenta ejecutar 'colima start' manualmente."
fi

log "Instalando lazydocker"
brew install lazydocker

log "Configurando dbx (función Zsh para compilar Docker local y multi-plataforma)"
if ! grep -qF "dbx: Compilar imágenes Docker" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" <<'EOF'

# dbx: Compilar imágenes Docker local y multi-plataforma
dbx() {
  local dockerfile="Dockerfile"
  local proyecto=""
  local tag="latest"
  local push_flag=false

  # Separar el flag --push de los argumentos posicionales
  local args=()
  for arg in "$@"; do
    if [[ "$arg" == "--push" ]]; then
      push_flag=true
    else
      args+=("$arg")
    fi
  done

  # Parsear argumentos posicionales
  if [[ ${#args[@]} -eq 3 ]]; then
    dockerfile="${args[1]}"
    proyecto="${args[2]}"
    tag="${args[3]}"
  elif [[ ${#args[@]} -eq 2 ]]; then
    # Si el primer argumento es un archivo que existe, asumimos que es el Dockerfile
    if [[ -f "${args[1]}" ]]; then
      dockerfile="${args[1]}"
      proyecto="${args[2]}"
    else
      proyecto="${args[1]}"
      tag="${args[2]}"
    fi
  elif [[ ${#args[@]} -eq 1 ]]; then
    proyecto="${args[1]}"
  else
    echo "Uso: dbx [dockerfile] <proyecto> [tag] [--push]"
    echo "Ejemplos:"
    echo "  dbx mi-app                          # Construye localmente (M1/arm64)"
    echo "  dbx mi-app 1.0.0 --push             # Multi-plataforma (amd64/arm64) y hace push"
    echo "  dbx Dockerfile.dev mi-app 1.0       # Usa Dockerfile.dev de forma local"
    echo "  dbx Dockerfile.dev mi-app 1.0 --push"
    return 1
  fi

  if [[ -z "$proyecto" ]]; then
    echo "Error: Debes especificar el nombre del proyecto/imagen."
    return 1
  fi

  if [[ ! -f "$dockerfile" ]]; then
    echo "Error: El archivo Dockerfile '$dockerfile' no existe."
    return 1
  fi

  local full_tag="${proyecto}:${tag}"

  if [ "$push_flag" = true ]; then
    echo "Compilando multi-plataforma (linux/amd64, linux/arm64) y haciendo push..."
    docker buildx build --platform linux/amd64,linux/arm64 -f "$dockerfile" -t "$full_tag" --push .
  else
    echo "Compilando localmente para tu arquitectura (M1/arm64) y cargando en Docker local..."
    docker buildx build -f "$dockerfile" -t "$full_tag" --load .
  fi
}
EOF
  echo "  + función dbx agregada a $ZSHRC"
fi

log "Configurando dpx (función Zsh para hacer push de imágenes locales)"
if ! grep -qF "dpx: Hacer push de una imagen local" "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" <<'EOF'

# dpx: Hacer push de una imagen local de Docker al registro
dpx() {
  local proyecto=""
  local tag="latest"

  if [[ $# -eq 2 ]]; then
    proyecto="$1"
    tag="$2"
  elif [[ $# -eq 1 ]]; then
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
      echo "Uso: dpx <proyecto> [tag]"
      echo "  dpx mi-app                          # Hace push de mi-app:latest"
      echo "  dpx mi-app 1.0.0                    # Hace push de mi-app:1.0.0"
      return 0
    fi
    proyecto="$1"
  else
    echo "Error: Argumentos inválidos."
    echo "Uso: dpx <proyecto> [tag]"
    return 1
  fi

  local full_tag="${proyecto}:${tag}"
  echo "Haciendo push de la imagen local: ${full_tag}..."
  docker push "$full_tag"
}
EOF
  echo "  + función dpx agregada a $ZSHRC"
else
  echo "  OK, función dpx ya configurada en $ZSHRC"
fi



fi

if should_run 7; then
# ---------- 10. Bases de datos relacionales ----------

log "Instalando lazysql (MySQL + PostgreSQL)"
brew install lazysql

fi

if should_run 8; then
# ---------- 11. MongoDB ----------

log "Instalando lazymongo (requiere Go)"
if ! command -v go &>/dev/null; then
  warn "Go no está instalado. Instalando go vía brew..."
  brew install go
fi
# `go install` y `go build` colocan los binarios en ~/go/bin
append_once 'export PATH="$HOME/go/bin:$PATH"' "$ZSHRC"
if [ -d "$HOME/Development/jonathanleivag/lazymongo" ]; then
  log "  Instalando lazymongo localmente desde $HOME/Development/jonathanleivag/lazymongo..."
  (cd "$HOME/Development/jonathanleivag/lazymongo" && go install .)
else
  log "  Instalando lazymongo remotamente desde GitHub..."
  go install github.com/jonathanleivag/lazymongo@latest || warn "lazymongo falló al instalar remotamente, puedes clonar e instalar localmente: https://github.com/jonathanleivag/lazymongo"
fi

log "Instalando mongosh (respaldo oficial de MongoDB)"
brew install mongosh

log "Instalando vi-mongo (TUI para MongoDB con atajos Vim)"
if brew list vi-mongo &>/dev/null; then
  echo "  vi-mongo OK, ya instalado"
else
  warn "vi-mongo no encontrado. Instalando..."
  brew tap kopecmaciej/vi-mongo
  brew trust kopecmaciej/vi-mongo 2>/dev/null || true
  brew install vi-mongo
fi

log "Configurando vi-mongo para omitir la ventana emergente inicial"
VI_MONGO_CONFIG_DIR="$HOME/Library/Application Support/vi-mongo"
mkdir -p "$VI_MONGO_CONFIG_DIR"
cat > "$VI_MONGO_CONFIG_DIR/config.yaml" <<'EOF'
version: v0.3.0
log:
    path: /tmp/vi-mongo.log
    level: info
    prettyPrint: true
editor:
    command: ""
    env: EDITOR
ui:
    databasePanelWidth: 30
showConnectionPage: true
showWelcomePage: false
currentConnection: ""
connections: []
styles:
    betterSymbols: true
    currentStyle: default.yaml
EOF

log "Configurando conexiones nombradas de MongoDB (comando 'mgo')"
MONGO_CONNECTIONS_FILE="$HOME/.config/mongo-connections.sh"
if [ -f "$MONGO_CONNECTIONS_FILE" ]; then
  echo "  OK, ya existe $MONGO_CONNECTIONS_FILE — no se sobreescribe."
else
  cat > "$MONGO_CONNECTIONS_FILE" <<'EOF'
# Conexiones de MongoDB nombradas, usadas por la función `mgo` de .zshrc.
# Este archivo NO se sube a ningún repo — solo vive en esta Mac.
# Formato: [nombre]="uri completa de mongodb"

declare -A MONGO_CONNECTIONS=(
  [ejemplo-local]="mongodb://localhost:27017"
  # [cliente-x]="mongodb+srv://usuario:password@cluster.mongodb.net/db"
  # [cliente-y]="mongodb://usuario:password@10.0.0.5:27017/db2"
)
EOF
  echo "  Config creada en $MONGO_CONNECTIONS_FILE (edítala para agregar tus conexiones reales)"
fi

if ! grep -qF 'mgo()' "$ZSHRC" 2>/dev/null; then
  cat >> "$ZSHRC" <<'EOF'

# Conexiones de MongoDB nombradas (ver ~/.config/mongo-connections.sh)
[ -f ~/.config/mongo-connections.sh ] && source ~/.config/mongo-connections.sh

mgo() {
  if [ -z "$1" ]; then
    echo "Uso: mgo <nombre>"
    echo "Conexiones disponibles:"
    for nombre in "${(@k)MONGO_CONNECTIONS}"; do
      echo "  - $nombre"
    done
    return 1
  fi

  local uri="${MONGO_CONNECTIONS[$1]}"
  if [ -z "$uri" ]; then
    echo "No existe la conexión '$1'. Agrégala en ~/.config/mongo-connections.sh"
    return 1
  fi

  mongosh "$uri"
}
EOF
  echo "  + función mgo agregada a $ZSHRC"
else
  echo "  OK, función mgo ya presente en $ZSHRC"
fi

fi

if should_run 9; then
# ---------- 12. Editor: Neovim + LazyVim ----------

log "Instalando Neovim"
brew install neovim ripgrep fd  # ripgrep y fd son dependencias comunes de LazyVim

if [ -d "$NVIM_CONFIG" ]; then
  warn "Ya existe $NVIM_CONFIG — no se sobreescribe. Si quieres reinstalar LazyVim desde cero:"
  echo "    mv $NVIM_CONFIG $NVIM_CONFIG.bak"
  echo "    git clone https://github.com/LazyVim/starter $NVIM_CONFIG"
else
  log "Clonando LazyVim starter"
  git clone https://github.com/LazyVim/starter "$NVIM_CONFIG"
  rm -rf "$NVIM_CONFIG/.git"
  log "Inicializando repo propio para tu config de nvim (recomendado para versionarla)"
  git -C "$NVIM_CONFIG" init -q
  git -C "$NVIM_CONFIG" add -A
  git -C "$NVIM_CONFIG" commit -q -m "LazyVim starter inicial"
fi

log "Habilitando extras de LazyVim para JS/TS/Vue"
EXTRAS_FILE="$NVIM_CONFIG/lua/plugins/extras.lua"
if [ -f "$EXTRAS_FILE" ]; then
  warn "Ya existe $EXTRAS_FILE — no se sobreescribe para no perder tus ajustes."
else
  mkdir -p "$NVIM_CONFIG/lua/plugins"
  cat > "$EXTRAS_FILE" <<'EOF'
-- Extras de LazyVim habilitados para el stack Vue/React/Astro/Next/Nest (TS)
-- Generado por setup-terminal-stack.sh
-- Mason instalará automáticamente los LSPs/formatters la primera vez que abras nvim
return {
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.vue" },
  { import = "lazyvim.plugins.extras.lang.astro" },
  { import = "lazyvim.plugins.extras.lang.tailwind" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.lang.markdown" },
  { import = "lazyvim.plugins.extras.formatting.prettier" },
  { import = "lazyvim.plugins.extras.linting.eslint" },
}
EOF
  echo "  Extras creados en $EXTRAS_FILE"
  echo "  (typescript, vue, astro, tailwind, json, prettier, eslint — Mason los instalará al abrir nvim por primera vez)"
fi

log "Configurando plugin git-conflict.nvim para resolución visual de conflictos en Neovim"
GIT_CONFLICT_FILE="$NVIM_CONFIG/lua/plugins/git-conflict.lua"
cat > "$GIT_CONFLICT_FILE" <<'EOF'
return {
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    config = function()
      require("git-conflict").setup({
        default_mappings = true, -- co (ours), ct (theirs), cb (both), c0 (none), ]x (next), [x] (prev)
        default_commands = true,
        disable_diagnostics = true,
        highlights = {
          incoming = "DiffAdd",
          current = "DiffText",
        },
      })
    end,
  },
}
EOF
echo "  Plugin git-conflict.nvim configurado en $GIT_CONFLICT_FILE"

log "Configurando formateo respetando reglas del proyecto (Prettier / ESLint / .editorconfig)"
if ! command -v eslint_d &>/dev/null; then
  log "Instalando eslint_d globalmente para soporte de autofix ultra rápido con ESLint"
  npm install -g eslint_d || warn "No se pudo instalar eslint_d globalmente, se omitió."
fi

FORMATTING_FILE="$NVIM_CONFIG/lua/plugins/formatting.lua"
mkdir -p "$NVIM_CONFIG/lua/plugins"
cat > "$FORMATTING_FILE" <<'EOF'
-- Configuración de formateo automático perfecto al guardar (Cmd+S / :w)
-- Usa Prettier (con comillas simples y sin punto y coma) + eslint_d para dejar el código 100% libre de errores ESLint
return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- Formateo automático al guardar
      opts.format_on_save = {
        timeout_ms = 3000,
        async = false,
        quiet = true,
        lsp_format = "never", -- NUNCA usar formateadores LSP de html/cssls
      }

      opts.formatters = opts.formatters or {}

      -- Configurar Prettier con opciones por defecto: comillas simples ('') y sin punto y coma (no semi)
      opts.formatters.prettier = {
        prepend_args = { "--single-quote", "--no-semi" },
      }

      -- ESLint (vía eslint_d) solo se ejecuta si el proyecto tiene configuración de ESLint (.eslintrc* o eslint.config.*)
      local eslint_condition = function(self, ctx)
        return vim.fs.find({
          ".eslintrc",
          ".eslintrc.js",
          ".eslintrc.cjs",
          ".eslintrc.yaml",
          ".eslintrc.yml",
          ".eslintrc.json",
          "eslint.config.js",
          "eslint.config.mjs",
          "eslint.config.cjs",
          "eslint.config.ts",
        }, { path = ctx.filename, upward = true })[1] ~= nil
      end

      opts.formatters.eslint_d = { condition = eslint_condition }

      opts.formatters_by_ft = opts.formatters_by_ft or {}

      local js_formatters = { "prettier", "eslint_d", stop_after_first = false }

      opts.formatters_by_ft.vue = js_formatters
      opts.formatters_by_ft.javascript = js_formatters
      opts.formatters_by_ft.javascriptreact = js_formatters
      opts.formatters_by_ft.typescript = js_formatters
      opts.formatters_by_ft.typescriptreact = js_formatters
      opts.formatters_by_ft.json = { "prettier" }
      opts.formatters_by_ft.jsonc = { "prettier" }
      opts.formatters_by_ft.html = { "prettier" }
      opts.formatters_by_ft.css = { "prettier" }
      opts.formatters_by_ft.scss = { "prettier" }
      opts.formatters_by_ft.less = { "prettier" }
      opts.formatters_by_ft.yaml = { "prettier" }
      opts.formatters_by_ft.markdown = { "prettier" }

      return opts
    end,
  },

  -- Desactivar formateadores de LSPs para que NUNCA alteren o colapsen el código de Vue/HTML
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        html = {
          on_attach = function(client)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
        },
        cssls = {
          filetypes = { "css", "scss", "less", "vue" },
          on_attach = function(client)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
        },
        vtsls = {
          settings = {
            typescript = { format = { enable = false } },
            javascript = { format = { enable = false } },
          },
        },
        ts_ls = {
          settings = {
            typescript = { format = { enable = false } },
            javascript = { format = { enable = false } },
          },
        },
      },
    },
  },
}
EOF
echo "  Configuración de formateo actualizada en $FORMATTING_FILE"

log "Configurando dashboard de bienvenida (header personalizado)"
DASHBOARD_FILE="$NVIM_CONFIG/lua/plugins/dashboard.lua"
if [ -f "$DASHBOARD_FILE" ]; then
  warn "Ya existe $DASHBOARD_FILE — no se sobreescribe para no perder tus ajustes."
else
  mkdir -p "$NVIM_CONFIG/lua/plugins"
  cat > "$DASHBOARD_FILE" <<'EOF'
-- Header personalizado del dashboard de inicio (snacks.nvim)
-- Generado por setup-terminal-stack.sh
return {
  {
    "snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = [[
                        ===             
             -        -==:==-           
           ===       :==   ===          
        -==-        -=-      ===        
      ===          -==        =++=      
    ===:          =+-          =++-     
      ===        ++-         +**        
        ++=     ++        =**+          
         =++-  ++       +**             
           ++***                        
            -** ]],
        },
      },
    },
  },
}
EOF
  echo "  Dashboard personalizado creado en $DASHBOARD_FILE"
fi

log "Configurando transparencia de tema en Neovim (~/.config/nvim/lua/plugins/theme.lua)"
THEME_FILE="$NVIM_CONFIG/lua/plugins/theme.lua"
if [ -f "$THEME_FILE" ]; then
  warn "Ya existe $THEME_FILE — no se sobreescribe para no perder tus ajustes."
else
  mkdir -p "$NVIM_CONFIG/lua/plugins"
  cat > "$THEME_FILE" <<'EOF'
-- Configuración de transparencia para el tema tokyonight
-- Generado por setup-terminal-stack.sh
return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
}
EOF
  echo "  Configuración de transparencia creada en $THEME_FILE"
fi

log "Configurando minimapa en Neovim (~/.config/nvim/lua/plugins/minimap.lua)"
MINIMAP_FILE="$NVIM_CONFIG/lua/plugins/minimap.lua"
if [ -f "$MINIMAP_FILE" ]; then
  warn "Ya existe $MINIMAP_FILE — no se sobreescribe para no perder tus ajustes."
else
  mkdir -p "$NVIM_CONFIG/lua/plugins"
  cat > "$MINIMAP_FILE" <<'EOF'
-- Minimapa estilo VS Code para Neovim / LazyVim (neominimap.nvim)
-- Proporciona vista previa en miniatura, resaltado Treesitter, rectángulo de viewport y soporte de mouse
return {
  {
    "Isrothy/neominimap.nvim",
    version = "v3.*",
    enabled = true,
    lazy = false,
    init = function()
      vim.opt.wrap = false
      vim.g.neominimap_config = {
        auto_enable = true,
        layout = "float",
        float = {
          minimap_width = 16,
          window_border = "none",
        },
        click = {
          enabled = true,
        },
        treesitter = {
          enabled = true,
        },
      }
    end,
    keys = {
      { "<leader>um", "<cmd>Neominimap toggle<cr>", desc = "Toggle Minimap (VS Code style)" },
      { "<leader>mo", "<cmd>Neominimap on<cr>", desc = "Open Minimap" },
      { "<leader>mc", "<cmd>Neominimap off<cr>", desc = "Close Minimap" },
      { "<leader>mf", "<cmd>Neominimap focus<cr>", desc = "Focus Minimap" },
    },
  },
}
EOF
  echo "  Configuración de minimapa creada en $MINIMAP_FILE"
fi

log "Configurando Workspaces (workspaces.nvim) en Neovim"
WORKSPACES_FILE="$NVIM_CONFIG/lua/plugins/workspaces.lua"
if [ -f "$WORKSPACES_FILE" ]; then
  echo "  Workspaces OK, ya configurado en $WORKSPACES_FILE"
else
  mkdir -p "$NVIM_CONFIG/lua/plugins"
  cat > "$WORKSPACES_FILE" <<'EOF'
-- Gestión de Workspaces (Grupos de proyectos Backend + Frontend)
-- Permite agrupar varios proyectos sin usar enlaces simbólicos ni romper la búsqueda
return {
  {
    "natecraddock/workspaces.nvim",
    opts = {
      hooks = {
        open = function(name, path)
          pcall(function()
            require("persistence").load()
          end)
        end,
      },
    },
    keys = {
      { "<leader>wo", "<cmd>WorkspacesOpen<cr>", desc = "Abrir Workspace (Grupo de proyectos)" },
      { "<leader>wa", "<cmd>WorkspacesAdd<cr>", desc = "Agregar carpeta actual a Workspaces" },
      { "<leader>wl", "<cmd>WorkspacesList<cr>", desc = "Listar Workspaces" },
      { "<leader>wr", "<cmd>WorkspacesRemove<cr>", desc = "Eliminar Workspace" },
    },
  },
}
EOF
  echo "  Configuración de Workspaces creada en $WORKSPACES_FILE"
fi

log "Configurando Multi-Project Group Workspace Manager en Neovim"
GROUPS_JSON="$NVIM_CONFIG/project_groups.json"
cat > "$GROUPS_JSON" <<'EOF'
{
  "Front + Gateway + Global Form": [
    "/Users/jonathanleivag/Development/Movatec/front-movatec-hadda",
    "/Users/jonathanleivag/Development/Movatec/haddacloud-api-gateway-graphql",
    "/Users/jonathanleivag/Development/Movatec/mfe/haddacloud-mfe-global-form"
  ],
  "Auth & User Stack": [
    "/Users/jonathanleivag/Development/Movatec/front-movatec-hadda",
    "/Users/jonathanleivag/Development/Movatec/backend/haddacloud-user-backend",
    "/Users/jonathanleivag/Development/Movatec/mfe/haddacloud-mfe-auth"
  ]
}
EOF
echo "  Configuración de Workspaces JSON creada en $GROUPS_JSON"

MULTIROOT_FILE="$NVIM_CONFIG/lua/plugins/multiroot.lua"
mkdir -p "$NVIM_CONFIG/lua/plugins"
cat > "$MULTIROOT_FILE" <<'EOF'
-- Multi-Root Workspace Manager para LazyVim (Estilo VSCode Multi-Root)
-- Permite agrupar proyectos independientes (Frontend + Backends + MFEs)
-- sin usar enlaces simbólicos y manteniendo búsqueda rápida, Explorer filtrado y soporte LSP.

local M = {}
local config_path = vim.fn.stdpath("config") .. "/project_groups.json"

-- Leer grupos de workspaces desde JSON
local function get_groups()
  local f = io.open(config_path, "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()
  local ok, res = pcall(vim.json.decode, content)
  return ok and res or {}
end

-- Guardar grupos en JSON
local function save_groups(groups)
  local f = io.open(config_path, "w")
  if not f then
    vim.notify("Error guardando " .. config_path, vim.log.levels.ERROR)
    return false
  end
  f:write(vim.json.encode(groups))
  f:close()
  return true
end

-- Verificar si un directorio es un proyecto real (tiene .git, package.json, go.mod, etc.)
local function is_real_project(dir)
  if vim.fn.isdirectory(dir .. "/.git") == 1 then return true end
  if vim.fn.filereadable(dir .. "/package.json") == 1 then return true end
  if vim.fn.filereadable(dir .. "/go.mod") == 1 then return true end
  if vim.fn.filereadable(dir .. "/Cargo.toml") == 1 then return true end
  if vim.fn.filereadable(dir .. "/pyproject.toml") == 1 then return true end
  if vim.fn.filereadable(dir .. "/requirements.txt") == 1 then return true end
  return false
end

-- Calcular directorio raíz común para un grupo de carpetas
local function get_common_cwd(dirs)
  if not dirs or #dirs == 0 then return nil end
  if #dirs == 1 then return dirs[1] end

  local split_paths = {}
  for _, d in ipairs(dirs) do
    table.insert(split_paths, vim.split(d, "/", { plain = true }))
  end

  local common = {}
  local first = split_paths[1]
  for i = 1, #first do
    local part = first[i]
    local match = true
    for j = 2, #split_paths do
      if split_paths[j][i] ~= part then
        match = false
        break
      end
    end
    if match then
      table.insert(common, part)
    else
      break
    end
  end

  local res = table.concat(common, "/")
  if res == "" then return "/" end
  return res
end

-- Verificar si un path está permitido en el workspace
local function is_path_allowed(path, dirs)
  path = path:gsub("/$", "")
  for _, d in ipairs(dirs) do
    d = d:gsub("/$", "")
    if path == d or path:sub(1, #d + 1) == d .. "/" then
      return true
    end
    if d:sub(1, #path + 1) == path .. "/" then
      return true
    end
  end
  return false
end

-- Generar lista de exclusión dinámica para ocultar todo lo que no pertenece al workspace
local function get_workspace_excludes(common_dir, dirs)
  if not common_dir or not dirs or #dirs == 0 then return {} end
  local excludes = {}

  local function scan(dir, depth)
    if depth > 4 then return end
    local entries = vim.fn.readdir(dir)
    if not entries then return end

    for _, entry in ipairs(entries) do
      local full_path = dir .. "/" .. entry
      if not is_path_allowed(full_path, dirs) then
        local rel = full_path:sub(#common_dir + 2)
        table.insert(excludes, "/" .. rel)
        table.insert(excludes, "/" .. rel .. "/**")
      else
        local is_exact_target = false
        for _, d in ipairs(dirs) do
          d = d:gsub("/$", "")
          if full_path == d or full_path:sub(1, #d + 1) == d .. "/" then
            is_exact_target = true
            break
          end
        end
        if not is_exact_target and vim.fn.isdirectory(full_path) == 1 then
          scan(full_path, depth + 1)
        end
      end
    end
  end

  scan(common_dir, 1)
  return excludes
end

function M.open_workspace_explorer()
  if not vim.g.active_workspace_dirs or #vim.g.active_workspace_dirs == 0 then
    Snacks.explorer({
      hidden = true,
      ignored = true,
    })
    return
  end

  local common_dir = get_common_cwd(vim.g.active_workspace_dirs)

  Snacks.explorer({
    cwd = common_dir,
    hidden = true,
    ignored = true,
    title = "Explorer Workspace (" .. vim.g.active_workspace_name .. ")",
    transform = function(item)
      if item.file and not is_path_allowed(item.file, vim.g.active_workspace_dirs) then
        return false
      end
    end,
  })
end

function M.activate_workspace(name, dirs)
  vim.g.active_workspace_name = name
  vim.g.active_workspace_dirs = dirs

  for _, dir in ipairs(dirs) do
    pcall(function()
      vim.lsp.buf.add_workspace_folder(dir)
    end)
  end

  local common_dir = get_common_cwd(dirs)
  if common_dir and vim.fn.isdirectory(common_dir) == 1 then
    pcall(function()
      vim.cmd("cd " .. vim.fn.fnameescape(common_dir))
    end)
  end

  pcall(M.open_workspace_explorer)

  local msg = "Workspace activo: " .. name .. "\nCarpetas (" .. #dirs .. "):\n • " .. table.concat(dirs, "\n • ")
  vim.notify(msg, vim.log.levels.INFO, { title = "Multi-Root Workspace" })
end

function M.select_workspace()
  local groups = get_groups()
  local items = {}
  for name, dirs in pairs(groups) do
    table.insert(items, {
      text = "📁 " .. name .. " (" .. #dirs .. " proyectos)",
      name = name,
      dirs = dirs,
    })
  end

  if #items == 0 then
    vim.notify("No hay workspaces definidos en " .. config_path, vim.log.levels.WARN)
    return
  end

  Snacks.picker.select(items, {
    prompt = "Seleccionar Workspace (Grupo Multi-Root):",
    format_item = function(item)
      return item.text
    end,
  }, function(selected)
    if selected then
      M.activate_workspace(selected.name, selected.dirs)
    end
  end)
end

function M.deactivate_workspace()
  vim.g.active_workspace_name = nil
  vim.g.active_workspace_dirs = nil
  pcall(function()
    Snacks.explorer()
  end)
  vim.notify("Workspace desactivado. Búsqueda y Explorer restablecidos.", vim.log.levels.INFO, { title = "Multi-Root Workspace" })
end

function M.remove_workspace()
  local groups = get_groups()
  local items = {}
  for name, dirs in pairs(groups) do
    table.insert(items, {
      text = "🗑️ " .. name .. " (" .. #dirs .. " proyectos)",
      name = name,
    })
  end

  if #items == 0 then
    vim.notify("No hay workspaces para eliminar.", vim.log.levels.WARN)
    return
  end

  Snacks.picker.select(items, {
    prompt = "Seleccionar Workspace a Eliminar:",
    format_item = function(item)
      return item.text
    end,
  }, function(selected)
    if selected then
      groups[selected.name] = nil
      save_groups(groups)

      if vim.g.active_workspace_name == selected.name then
        vim.g.active_workspace_name = nil
        vim.g.active_workspace_dirs = nil
        pcall(function() Snacks.explorer() end)
      end

      vim.notify("Workspace '" .. selected.name .. "' eliminado correctamente.", vim.log.levels.INFO)
    end
  end)
end

function M.create_workspace()
  vim.ui.input({ prompt = "Nombre del nuevo Workspace: " }, function(name)
    if not name or name:gsub("%s+", "") == "" then
      vim.notify("Creación de workspace cancelada.", vim.log.levels.WARN)
      return
    end

    local base_dir = "/Users/jonathanleivag/Development"
    local found_projects = {}

    local handle = io.popen("find " .. base_dir .. " -mindepth 1 -maxdepth 4 -type d \\( ! -name '.*' ! -name 'node_modules' ! -name 'dist' ! -name 'target' ! -name 'build' \\)")
    if handle then
      for line in handle:lines() do
        if is_real_project(line) then
          table.insert(found_projects, line)
        end
      end
      handle:close()
    end
    table.sort(found_projects)

    if #found_projects == 0 then
      vim.notify("No se encontraron proyectos válidos en " .. base_dir, vim.log.levels.ERROR)
      return
    end

    local selected_dirs = {}
    local function pick_folder()
      local items = { { text = "✅ [FINALIZAR Y CREAR WORKSPACE]", finish = true } }
      for _, p in ipairs(found_projects) do
        local rel = p:sub(#base_dir + 2)
        local already = false
        for _, s in ipairs(selected_dirs) do
          if s == p then already = true; break end
        end
        if not already then
          table.insert(items, { text = "📁 " .. rel, path = p })
        end
      end

      Snacks.picker.select(items, {
        prompt = "Seleccionar proyectos para '" .. name .. "' (Seleccionados: " .. #selected_dirs .. "):",
        format_item = function(item) return item.text end,
      }, function(selected)
        if not selected or selected.finish then
          if #selected_dirs == 0 then
            vim.notify("No agregaste ningún proyecto. Cancelado.", vim.log.levels.WARN)
            return
          end
          local groups = get_groups()
          groups[name] = selected_dirs
          save_groups(groups)
          M.activate_workspace(name, selected_dirs)
          vim.notify("Workspace '" .. name .. "' creado y activado con " .. #selected_dirs .. " proyectos.", vim.log.levels.INFO)
        else
          table.insert(selected_dirs, selected.path)
          pick_folder()
        end
      end)
    end

    pick_folder()
  end)
end

function M.add_project_to_workspace()
  local groups = get_groups()
  local group_names = {}
  for name, _ in pairs(groups) do
    table.insert(group_names, name)
  end
  table.sort(group_names)

  if #group_names == 0 then
    vim.notify("No hay workspaces creados aún. Usa <leader>wn para crear uno.", vim.log.levels.WARN)
    return
  end

  local function select_project_for_group(target_group_name)
    local base_dir = "/Users/jonathanleivag/Development"
    local found_projects = {}

    local handle = io.popen("find " .. base_dir .. " -mindepth 1 -maxdepth 4 -type d \\( ! -name '.*' ! -name 'node_modules' ! -name 'dist' ! -name 'target' ! -name 'build' \\)")
    if handle then
      for line in handle:lines() do
        if is_real_project(line) then
          table.insert(found_projects, line)
        end
      end
      handle:close()
    end
    table.sort(found_projects)

    local current_dirs = groups[target_group_name] or {}
    local items = {}
    for _, p in ipairs(found_projects) do
      local already = false
      for _, existing in ipairs(current_dirs) do
        if existing == p then already = true; break end
      end
      if not already then
        local rel = p:sub(#base_dir + 2)
        table.insert(items, { text = "📁 " .. rel, path = p })
      end
    end

    if #items == 0 then
      vim.notify("Todos los proyectos de " .. base_dir .. " ya pertenecen a este workspace.", vim.log.levels.INFO)
      return
    end

    Snacks.picker.select(items, {
      prompt = "Seleccionar proyecto para agregar a '" .. target_group_name .. "':",
      format_item = function(item) return item.text end,
    }, function(selected)
      if selected and selected.path then
        table.insert(groups[target_group_name], selected.path)
        save_groups(groups)

        if vim.g.active_workspace_name == target_group_name then
          M.activate_workspace(target_group_name, groups[target_group_name])
        else
          M.activate_workspace(target_group_name, groups[target_group_name])
        end

        vim.notify("Proyecto '" .. selected.path .. "' agregado a '" .. target_group_name .. "'.", vim.log.levels.INFO)
      end
    end)
  end

  if vim.g.active_workspace_name and groups[vim.g.active_workspace_name] then
    select_project_for_group(vim.g.active_workspace_name)
  else
    local items = {}
    for _, name in ipairs(group_names) do
      table.insert(items, { text = "📁 " .. name .. " (" .. #groups[name] .. " proyectos)", name = name })
    end

    Snacks.picker.select(items, {
      prompt = "Seleccionar Workspace al que deseas agregar un proyecto:",
      format_item = function(item) return item.text end,
    }, function(selected)
      if selected then
        select_project_for_group(selected.name)
      end
    end)
  end
end

function M.remove_project_from_workspace_target(target_group_name)
  local groups = get_groups()
  local current_dirs = groups[target_group_name] or {}

  if #current_dirs == 0 then
    vim.notify("El workspace '" .. target_group_name .. "' no tiene proyectos.", vim.log.levels.WARN)
    return
  end

  local base_dir = "/Users/jonathanleivag/Development"
  local items = {}
  for _, p in ipairs(current_dirs) do
    local rel = p
    if p:sub(1, #base_dir) == base_dir then
      rel = p:sub(#base_dir + 2)
    end
    table.insert(items, { text = "❌ " .. rel, path = p })
  end

  Snacks.picker.select(items, {
    prompt = "Quitar proyecto de '" .. target_group_name .. "':",
    format_item = function(item) return item.text end,
  }, function(selected)
    if selected and selected.path then
      local new_dirs = {}
      for _, p in ipairs(current_dirs) do
        if p ~= selected.path then
          table.insert(new_dirs, p)
        end
      end

      groups[target_group_name] = new_dirs
      save_groups(groups)

      if vim.g.active_workspace_name == target_group_name then
        if #new_dirs == 0 then
          M.deactivate_workspace()
        else
          M.activate_workspace(target_group_name, new_dirs)
        end
      end

      vim.notify("Proyecto '" .. selected.path .. "' quitado del workspace '" .. target_group_name .. "'.", vim.log.levels.INFO)
    end
  end)
end

function M.remove_project_from_workspace()
  local groups = get_groups()
  local target_group_name = vim.g.active_workspace_name

  if not target_group_name or not groups[target_group_name] then
    local group_names = {}
    for name, _ in pairs(groups) do
      table.insert(group_names, name)
    end
    table.sort(group_names)

    if #group_names == 0 then
      vim.notify("No hay workspaces creados.", vim.log.levels.WARN)
      return
    end

    local items = {}
    for _, name in ipairs(group_names) do
      table.insert(items, { text = "📁 " .. name .. " (" .. #groups[name] .. " proyectos)", name = name })
    end

    Snacks.picker.select(items, {
      prompt = "Seleccionar Workspace del cual quitar un proyecto:",
      format_item = function(item) return item.text end,
    }, function(selected)
      if selected then
        M.remove_project_from_workspace_target(selected.name)
      end
    end)
    return
  end

  M.remove_project_from_workspace_target(target_group_name)
end

function M.copy_workspace_or_config_path()
  if vim.g.active_workspace_dirs and #vim.g.active_workspace_dirs > 0 then
    local paths_str = table.concat(vim.g.active_workspace_dirs, "\n")
    vim.fn.setreg("+", paths_str)
    vim.fn.setreg('"', paths_str)

    local msg = "📋 Rutas del Workspace '" .. (vim.g.active_workspace_name or "Activo") .. "' copiadas al portapapeles:\n • " .. table.concat(vim.g.active_workspace_dirs, "\n • ")
    vim.notify(msg, vim.log.levels.INFO, { title = "Multi-Root Workspace" })
  else
    vim.fn.setreg("+", config_path)
    vim.fn.setreg('"', config_path)

    local msg = "📋 Sin workspace activo. Ruta del JSON de configuración copiada:\n" .. config_path
    vim.notify(msg, vim.log.levels.INFO, { title = "Multi-Root Workspace" })
  end
end

function M.add_current_dir()
  if not vim.g.active_workspace_name or not vim.g.active_workspace_dirs then
    vim.notify("Primero activa un workspace con <leader>ws para agregarle carpetas.", vim.log.levels.WARN)
    return
  end

  local current_dir = vim.fn.getcwd()
  for _, d in ipairs(vim.g.active_workspace_dirs) do
    if d == current_dir then
      vim.notify("La carpeta actual ya pertenece a este workspace.", vim.log.levels.INFO)
      return
    end
  end

  table.insert(vim.g.active_workspace_dirs, current_dir)
  local groups = get_groups()
  groups[vim.g.active_workspace_name] = vim.g.active_workspace_dirs
  save_groups(groups)
  M.activate_workspace(vim.g.active_workspace_name, vim.g.active_workspace_dirs)
end

function M.edit_json()
  vim.cmd("edit " .. config_path)
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>ws", M.select_workspace, desc = "Seleccionar Workspace" },
      { "<leader>wn", M.create_workspace, desc = "Crear nuevo Workspace" },
      { "<leader>wp", M.add_project_to_workspace, desc = "Agregar proyecto a Workspace" },
      { "<leader>wx", M.remove_project_from_workspace, desc = "Quitar proyecto de Workspace" },
      { "<leader>wd", M.deactivate_workspace, desc = "Desactivar Workspace" },
      { "<leader>wr", M.remove_workspace, desc = "Eliminar Workspace completo" },
      { "<leader>wy", M.copy_workspace_or_config_path, desc = "Copiar rutas de Workspace / JSON al portapapeles" },
      { "<leader>yp", M.copy_workspace_or_config_path, desc = "Copiar rutas de Workspace / JSON al portapapeles" },
      { "<leader>wa", M.add_current_dir, desc = "Agregar carpeta actual a Workspace" },
      { "<leader>we", M.edit_json, desc = "Editar JSON de Workspaces" },
      { "<leader>Ws", M.select_workspace, desc = "Seleccionar Workspace" },
      { "<leader>Wn", M.create_workspace, desc = "Crear nuevo Workspace" },
      { "<leader>Wp", M.add_project_to_workspace, desc = "Agregar proyecto a Workspace" },
      { "<leader>Wx", M.remove_project_from_workspace, desc = "Quitar proyecto de Workspace" },
      { "<leader>Wd", M.deactivate_workspace, desc = "Desactivar Workspace" },
      { "<leader>Wr", M.remove_workspace, desc = "Eliminar Workspace completo" },
      { "<leader>Wy", M.copy_workspace_or_config_path, desc = "Copiar rutas de Workspace / JSON al portapapeles" },
      { "<leader>Wa", M.add_current_dir, desc = "Agregar carpeta actual a Workspace" },
      { "<leader>We", M.edit_json, desc = "Editar JSON de Workspaces" },
    },
    opts = function(_, opts)
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.explorer = vim.tbl_deep_extend("force", opts.picker.sources.explorer or {}, {
        hidden = true,
        ignored = true,
      })

      -- Intercept Búsqueda de Archivos
      vim.keymap.set("n", "<leader><space>", function()
        if vim.g.active_workspace_dirs and #vim.g.active_workspace_dirs > 0 then
          Snacks.picker.files({
            dirs = vim.g.active_workspace_dirs,
            title = "Archivos Workspace (" .. vim.g.active_workspace_name .. ")",
          })
        else
          Snacks.picker.smart()
        end
      end, { desc = "Buscar Archivos (Workspace o Local)" })

      vim.keymap.set("n", "<leader>ff", function()
        if vim.g.active_workspace_dirs and #vim.g.active_workspace_dirs > 0 then
          Snacks.picker.files({
            dirs = vim.g.active_workspace_dirs,
            title = "Archivos Workspace (" .. vim.g.active_workspace_name .. ")",
          })
        else
          Snacks.picker.files()
        end
      end, { desc = "Buscar Archivos (Workspace o Local)" })

      -- Intercept Grep Texto
      vim.keymap.set("n", "<leader>/", function()
        if vim.g.active_workspace_dirs and #vim.g.active_workspace_dirs > 0 then
          Snacks.picker.grep({
            dirs = vim.g.active_workspace_dirs,
            title = "Grep Workspace (" .. vim.g.active_workspace_name .. ")",
          })
        else
          Snacks.picker.grep()
        end
      end, { desc = "Grep Texto (Workspace o Local)" })

      vim.keymap.set("n", "<leader>sg", function()
        if vim.g.active_workspace_dirs and #vim.g.active_workspace_dirs > 0 then
          Snacks.picker.grep({
            dirs = vim.g.active_workspace_dirs,
            title = "Grep Workspace (" .. vim.g.active_workspace_name .. ")",
          })
        else
          Snacks.picker.grep()
        end
      end, { desc = "Grep Texto (Workspace o Local)" })

      vim.keymap.set("n", "<leader>sw", function()
        if vim.g.active_workspace_dirs and #vim.g.active_workspace_dirs > 0 then
          Snacks.picker.grep_word({
            dirs = vim.g.active_workspace_dirs,
            title = "Palabra Workspace (" .. vim.g.active_workspace_name .. ")",
          })
        else
          Snacks.picker.grep_word()
        end
      end, { desc = "Buscar Palabra bajo el Cursor (Workspace o Local)" })

      -- Intercept Explorer
      vim.keymap.set("n", "<leader>e", M.open_workspace_explorer, { desc = "Explorer (Workspace o Local)" })
      vim.keymap.set("n", "<leader>fe", M.open_workspace_explorer, { desc = "Explorer (Workspace o Local)" })
    end,
  },
}
EOF
echo "  Configuración Multi-root creada en $MULTIROOT_FILE"

LUALINE_FILE="$NVIM_CONFIG/lua/plugins/lualine.lua"
cat > "$LUALINE_FILE" <<'EOF'
-- Indicador de Workspace Activo en Lualine
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}
      table.insert(opts.sections.lualine_x, 1, {
        function()
          if vim.g.active_workspace_name then
            local count = #(vim.g.active_workspace_dirs or {})
            return "📁 [" .. vim.g.active_workspace_name .. " (" .. count .. ")]"
          end
          return ""
        end,
        color = { fg = "#7aa2f7", gui = "bold" },
      })
    end,
  },
}
EOF
echo "  Configuración Lualine Workspace creada en $LUALINE_FILE"

WORKSPACES_FILE="$NVIM_CONFIG/lua/plugins/workspaces.lua"
cat > "$WORKSPACES_FILE" <<'EOF'
-- Reemplazado por multiroot.lua
return {}
EOF


log "Configurando Kulala.nvim (REST Client para .http/.rest)"
KULALA_FILE="$NVIM_CONFIG/lua/plugins/kulala.lua"
if [ -f "$KULALA_FILE" ]; then
  echo "  Kulala OK, ya configurado en $KULALA_FILE"
else
  mkdir -p "$NVIM_CONFIG/lua/plugins"
  cat > "$KULALA_FILE" <<'EOF'
return {
  -- mistweaverco/kulala.nvim
  {
    "mistweaverco/kulala.nvim",
    ft = { "http", "rest" },
    keys = {
      { "<leader>R", "", desc = "+Rest Client (Kulala)", mode = { "n" } },
      { "<leader>Rr", function() require("kulala").run() end, desc = "Run request under cursor" },
      { "<leader>Ra", function() require("kulala").run_all() end, desc = "Run all requests" },
      { "<leader>Rp", function() require("kulala").scratchpad() end, desc = "Toggle scratchpad" },
      { "<leader>Ri", function() require("kulala").inspect() end, desc = "Inspect request under cursor" },
      { "<leader>Rn", function() require("kulala").jump_next() end, desc = "Jump to next request" },
      { "<leader>RN", function() require("kulala").jump_prev() end, desc = "Jump to previous request" },
      { "<leader>Rco", function() require("kulala").copy() end, desc = "Copy request under cursor as curl" },
      { "<leader>Rcl", function() require("kulala").clear() end, desc = "Clear response" },
    },
    opts = {
      split_direction = "vertical",
      default_view = "body",
      formatters = {
        json = { "jq", "." },
        xml = { "xmllint", "--format", "-" },
        html = { "tidy", "-i", "-q", "--show-body-only", "yes", "--show-warnings", "no" },
      },
    },
  },

  -- Ensure treesitter has http and xml parsers for syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "http", "xml", "json", "graphql" })
      end
    end,
  },
}
EOF
  echo "  Config de Kulala creada en $KULALA_FILE"
fi

log "Configurando soporte de colores visuales y autocompletado CSS en Vue (~/.config/nvim/lua/plugins/vue-colors-css.lua)"
VUE_COLORS_CSS_FILE="$NVIM_CONFIG/lua/plugins/vue-colors-css.lua"
cat > "$VUE_COLORS_CSS_FILE" <<'EOF'
return {
  -- Highlighting de colores CSS (previsualización de colores como green, #00ff00, bg-red-500 en .vue, .css, .js)
  {
    "brenoprata10/nvim-highlight-colors",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      render = "background",
      enable_named_colors = true,
      enable_tailwinds = true,
    },
  },

  -- Asegurar que Mason instale css-lsp, html-lsp, emmet-ls y tailwindcss-language-server
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "css-lsp", "html-lsp", "emmet-ls", "tailwindcss-language-server" })
    end,
  },

  -- Configurar autocompletado de HTML, Emmet, CSS y Tailwind CSS dentro de archivos .vue
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Autocompletado de Tailwind CSS (flex, grid, bg-blue-500, p-4, items-center, etc.)
        tailwindcss = {
          filetypes = { "html", "css", "scss", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte", "astro" },
          init_options = {
            userLanguages = {
              vue = "html",
            },
          },
          settings = {
            tailwindCSS = {
              experimental = {
                classRegex = {
                  { "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]* construct)?[\"'`]" },
                  { "cx\\(([^)]*)\\)", "(?:[\"'`]([^\"'`]* construct)?[\"'`]|(\\w+))" },
                  "class:\\s*['\"]([^'\"]*)['\"]",
                  ":class=\"([^\"]*)\"",
                },
              },
              validate = true,
            },
          },
        },
        -- Autocompletado de etiquetas y atributos HTML (div, section, input, class, placeholder, etc.) en .vue
        html = {
          filetypes = { "html", "templ", "vue" },
          on_attach = function(client)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
        },
        -- Expansión ultra rápida de abreviaciones Emmet (ej: div.container>ul>li*3) en .vue
        emmet_ls = {
          filetypes = { "html", "vue", "css", "scss", "javascriptreact", "typescriptreact" },
        },
        -- Autocompletado de CSS dentro de bloques <style> en .vue
        cssls = {
          filetypes = { "css", "scss", "less", "vue" },
          on_attach = function(client)
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
          end,
          settings = {
            css = { validate = true, lint = { unknownAtRules = "ignore" } },
            scss = { validate = true, lint = { unknownAtRules = "ignore" } },
            less = { validate = true, lint = { unknownAtRules = "ignore" } },
          },
        },
      },
    },
  },
}
EOF
echo "  Configuración de colores y CSS Vue creada en $VUE_COLORS_CSS_FILE"


log "Desactivando chequeo de orden de imports de LazyVim (falso positivo con extras.lua manual)"
OPTIONS_FILE="$NVIM_CONFIG/lua/config/options.lua"
if [ -f "$OPTIONS_FILE" ]; then
  append_once "vim.g.lazyvim_check_order = false" "$OPTIONS_FILE"
else
  mkdir -p "$NVIM_CONFIG/lua/config"
  echo "vim.g.lazyvim_check_order = false" > "$OPTIONS_FILE"
  echo "  Creado $OPTIONS_FILE"
fi

log "Configurando atajos de Neovim (~/.config/nvim/lua/config/keymaps.lua)"
KEYMAPS_FILE="$NVIM_CONFIG/lua/config/keymaps.lua"
mkdir -p "$(dirname "$KEYMAPS_FILE")"
cat > "$KEYMAPS_FILE" <<'EOF'
-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Guardar archivo con Cmd+S (<D-s>) y Ctrl+S (<C-s>) en todos los modos (Normal, Insert, Visual)
vim.keymap.set({ "i", "x", "n", "s" }, "<D-s>", "<cmd>w<cr>", { desc = "Guardar archivo (Cmd+S)" })
vim.keymap.set({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr>", { desc = "Guardar archivo (Ctrl+S)" })

-- Función robusta para abrir LazyMongo usando el ejecutable exacto
local function open_lazymongo()
  local bin = vim.fn.expand("$HOME/go/bin/lazymongo")
  local cmd = vim.fn.executable(bin) == 1 and bin or "lazymongo"

  if Snacks and Snacks.terminal then
    Snacks.terminal({ cmd }, { esc_esc = false, ctrl_hjkl = false })
  elseif LazyVim and LazyVim.terminal then
    LazyVim.terminal({ cmd }, { esc_esc = false, ctrl_hjkl = false })
  else
    vim.cmd("terminal " .. cmd)
  end
end

-- Abrir lazymongo con "<leader>lm" o "lm" directamente
vim.keymap.set("n", "<leader>lm", open_lazymongo, { desc = "LazyMongo" })
vim.keymap.set("n", "lm", open_lazymongo, { desc = "LazyMongo (Directo)" })

-- Copiar la ruta del archivo actual al portapapeles
vim.keymap.set("n", "<leader>cp", function()
  local path = vim.fn.expand("%")
  vim.fn.setreg("+", path)
  vim.notify('Ruta relativa copiada: "' .. path .. '"', vim.log.levels.INFO, { title = "Copiar Ruta" })
end, { desc = "Copiar ruta relativa" })

vim.keymap.set("n", "<leader>cP", function()
  local path = vim.fn.expand("%:p")
  vim.fn.setreg("+", path)
  vim.notify('Ruta absoluta copiada: "' .. path .. '"', vim.log.levels.INFO, { title = "Copiar Ruta" })
end, { desc = "Copiar ruta absoluta" })
EOF
echo "  Configuración de atajos en $KEYMAPS_FILE actualizada."

log "Compilando dependencias de markdown-preview.nvim"
# Forzar descarga de los extras de markdown en modo headless
nvim --headless "+Lazy! sync" +qa &>/dev/null

MARKDOWN_PREVIEW_APP_DIR="$HOME/.local/share/nvim/lazy/markdown-preview.nvim/app"
if [ -d "$MARKDOWN_PREVIEW_APP_DIR" ]; then
  (cd "$MARKDOWN_PREVIEW_APP_DIR" && npm install --silent)
  echo "  + npm install completado para markdown-preview.nvim"
fi

fi

if should_run 10; then
# ---------- 13. tmux ----------

log "Verificando tmux"
if brew list tmux &>/dev/null; then
  echo "  tmux OK, ya instalado"
else
  warn "tmux no encontrado. Instalando..."
  brew install tmux
fi

log "Configurando tmux (~/.tmux.conf)"
TMUX_CONF="$HOME/.tmux.conf"
if [ -f "$TMUX_CONF" ]; then
  warn "Ya existe $TMUX_CONF — no se sobreescribe para no perder tus ajustes."
else
  cat > "$TMUX_CONF" <<'EOF'
# ~/.tmux.conf — generado por setup-terminal-stack.sh

# Prefix más cómodo: Ctrl-a en vez de Ctrl-b
unbind C-b
set -g prefix C-a
bind C-a send-prefix
bind a send-prefix

# Mouse: click para cambiar de panel, arrastrar para redimensionar, scroll para history
set -g mouse on

# Splits fáciles y cómodos (mantienen el directorio actual)
unbind '"'
unbind %
bind v split-window -h -c "#{pane_current_path}"  # Ctrl+a + v -> Panel a la derecha
bind s split-window -v -c "#{pane_current_path}"  # Ctrl+a + s -> Panel abajo
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Nuevas ventanas también respetan el directorio actual
bind c new-window -c "#{pane_current_path}"

# Recargar config con prefix + r
bind r source-file ~/.tmux.conf \; display "Config recargada"

# Navegación de paneles estilo vim (h j k l)
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Moverse entre paneles con Prefix + Número (Ctrl+a 1-9)
bind-key 1 select-pane -t 1
bind-key 2 select-pane -t 2
bind-key 3 select-pane -t 3
bind-key 4 select-pane -t 4
bind-key 5 select-pane -t 5
bind-key 6 select-pane -t 6
bind-key 7 select-pane -t 7
bind-key 8 select-pane -t 8
bind-key 9 select-pane -t 9

# Mostrar el número y nombre del proyecto en el borde superior de cada panel
set -g pane-border-status top
set -g pane-border-format " #[fg=cyan,bold] Panel #P #[fg=white,nobold]» #[fg=white,bold]#{b:pane_current_path} #[fg=green,dim](#{pane_current_command}) "
set -g pane-active-border-style fg=cyan,bold
set -g pane-border-style fg=colour240

# Evitar truncado de texto en la barra de estado (permitir nombres largos)
set -g status-left-length 100
set -g status-right-length 100
set -g status-right " #[fg=black,bold]#H #[fg=black,nobold]» %H:%M %d-%b-%Y "


# Empezar a contar ventanas/paneles desde 1, no 0
set -g base-index 1
setw -g pane-base-index 1

# Historial de scroll más largo
set -g history-limit 10000

# Colores de 256/truecolor (para que Neovim y themes se vean bien)
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# ---- Plugins (vía TPM) ----
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# tmux-continuum: autoguardado de sesión cada 15 min + restaurar al abrir tmux
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'

# Inicializar TPM (debe ir al final del archivo)
run '~/.tmux/plugins/tpm/tpm'
EOF
  echo "  Config creada en $TMUX_CONF"
fi

log "Instalando script tmux-mosaic en ~/go/bin"
mkdir -p "$HOME/go/bin"
cat > "$HOME/go/bin/tmux-mosaic" <<'EOF'
#!/usr/bin/env bash
#
# tmux-mosaic (tm / tmm / tmx)
#
# Crea un mosaico (grid/tiled layout) en Tmux con todas las rutas de proyectos especificadas.
#
# Formas de uso:
#   1. Argumentos directos: tm /ruta/1 /ruta/2 /ruta/3
#   2. Desde portapapeles: Copia con <leader>wy en LazyVim y ejecuta simplemente: tm
#   3. Desde pipe: echo "/ruta/1\n/ruta/2" | tm
#

set -euo pipefail

paths=()

# 1. Si hay argumentos pasados en la terminal
if [ $# -gt 0 ]; then
  for p in "$@"; do
    p="$(echo "$p" | xargs)"
    if [ -n "$p" ] && [ -d "$p" ]; then
      paths+=("$p")
    fi
  done
# 2. Si se están pasando datos por tubería (pipe / stdin)
elif [ ! -t 0 ]; then
  while IFS= read -r line; do
    line="$(echo "$line" | xargs)"
    if [ -n "$line" ] && [ -d "$line" ]; then
      paths+=("$line")
    fi
  done
# 3. Si no hay argumentos ni pipe, leer del portapapeles de macOS (pbpaste)
else
  clip="$(pbpaste 2>/dev/null || true)"
  if [ -n "$clip" ]; then
    while IFS= read -r line; do
      line="$(echo "$line" | xargs)"
      if [ -n "$line" ] && [ -d "$line" ]; then
        paths+=("$line")
      fi
    done <<< "$clip"
  fi
fi

if [ ${#paths[@]} -eq 0 ]; then
  echo -e "\033[1;31m❌ Error: No se encontraron rutas válidas de proyectos.\033[0m"
  echo -e "Formas de uso:"
  echo -e "  1. Pasa las rutas como argumentos: \033[1;36mtm /ruta/1 /ruta/2 /ruta/3\033[0m"
  echo -e "  2. O copia las rutas con \033[1;33m<leader>wy\033[0m en LazyVim y ejecuta simplemente: \033[1;36mtm\033[0m"
  exit 1
fi

count=${#paths[@]}
echo -e "\033[1;32m🚀 Creando mosaico Tmux para ${count} proyecto(s)...\033[0m"

if [ -n "${TMUX:-}" ]; then
  # Dentro de una sesión activa de Tmux: crear una nueva ventana "Mosaico"
  win_id="$(tmux new-window -P -n "Mosaico" -c "${paths[0]}")"

  for (( i=1; i<count; i++ )); do
    tmux split-window -t "$win_id" -c "${paths[$i]}"
    tmux select-layout -t "$win_id" tiled
  done

  tmux select-layout -t "$win_id" tiled
  tmux select-pane -t "$win_id.0"
else
  # Fuera de Tmux: crear una nueva sesión y conectarse
  session_name="mosaic_$(date +%s)"
  tmux new-session -d -s "$session_name" -n "Mosaico" -c "${paths[0]}"

  for (( i=1; i<count; i++ )); do
    tmux split-window -t "$session_name:Mosaico" -c "${paths[$i]}"
    tmux select-layout -t "$session_name:Mosaico" tiled
  done

  tmux select-layout -t "$session_name:Mosaico" tiled
  tmux select-pane -t "$session_name:Mosaico.0"
  tmux attach-session -t "$session_name"
fi
EOF
chmod +x "$HOME/go/bin/tmux-mosaic"
echo "  Script tmux-mosaic creado y marcado como ejecutable."


log "Instalando TPM (Tmux Plugin Manager)"
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ -d "$TPM_DIR" ]; then
  echo "  TPM OK, ya instalado"
else
  git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  echo "  TPM instalado. Con tmux abierto, presiona 'prefix + I' (Ctrl-a luego I) para instalar los plugins."
fi

fi

if should_run 11; then
# ---------- 14. Asistentes de código con IA (CLIs) ----------

log "Verificando Claude Code"
if brew list --cask claude-code &>/dev/null; then
  echo "  Claude Code OK, ya instalado"
else
  warn "Claude Code no encontrado. Instalando..."
  brew install --cask claude-code
fi



log "Verificando Graphify (Knowledge Graph para asistentes de IA)"
if command -v graphify &>/dev/null; then
  echo "  Graphify OK ($(graphify --version 2>/dev/null || echo 'instalado'))"
else
  warn "Graphify no encontrado. Instalando vía pip3..."
  pip3 install graphifyy

  GRAPHIFY_BIN="$(find /Library/Frameworks/Python.framework/Versions/*/bin ~/.local/bin -name graphify 2>/dev/null | head -n 1)"
  if [ -n "$GRAPHIFY_BIN" ]; then
    mkdir -p "$HOME/.local/bin" "$HOME/go/bin"
    ln -sf "$GRAPHIFY_BIN" "$HOME/.local/bin/graphify"
    ln -sf "$GRAPHIFY_BIN" "$HOME/go/bin/graphify"
  fi
fi

fi

if should_run 12; then
# ---------- 15. Aplicaciones GUI (Casks) ----------

log "Verificando Lens (Kubernetes IDE)"
if [ -d "/Applications/Lens.app" ] || brew list --cask lens &>/dev/null; then
  echo "  Lens OK, ya instalado"
else
  warn "Lens no encontrado. Instalando..."
  brew install --cask lens
fi

log "Verificando Docker Desktop"
if [ -d "/Applications/Docker.app" ] || brew list --cask docker &>/dev/null || brew list --cask docker-desktop &>/dev/null; then
  echo "  Docker Desktop OK, ya instalado"
else
  warn "Docker Desktop no encontrado. Instalando..."
  brew install --cask docker
fi

log "Verificando Warp (Terminal)"
if [ -d "/Applications/Warp.app" ] || brew list --cask warp &>/dev/null; then
  echo "  Warp OK, ya instalado"
else
  warn "Warp no encontrado. Instalando..."
  brew install --cask warp
fi

log "Configurando tema Catppuccin Frappé y ajustes para Warp Terminal"
WARP_CONFIG_DIR="$HOME/.warp"
WARP_THEMES_DIR="$WARP_CONFIG_DIR/themes"
mkdir -p "$WARP_THEMES_DIR"

cat > "$WARP_THEMES_DIR/catppuccin_frappe.yml" <<'EOF_WARP_THEME'
background: '#303446'
accent: '#f2d5cf'
foreground: '#c6d0f5'
details: darker
terminal_colors:
  normal:
    black: '#51576d'
    red: '#e78284'
    green: '#a6d189'
    yellow: '#e5c890'
    blue: '#8caaee'
    magenta: '#f4b8e4'
    cyan: '#81c8be'
    white: '#b5bfe2'
  bright:
    black: '#626880'
    red: '#e78284'
    green: '#a6d189'
    yellow: '#e5c890'
    blue: '#8caaee'
    magenta: '#f4b8e4'
    cyan: '#81c8be'
    white: '#a5adce'
EOF_WARP_THEME

if [ ! -f "$WARP_CONFIG_DIR/settings.toml" ]; then
  cat > "$WARP_CONFIG_DIR/settings.toml" <<EOF_WARP_SETTINGS
[appearance]
[appearance.vertical_tabs]
enabled = true

[appearance.themes]
system_theme = false
theme = { custom = { name = "Catppuccin Frappe", path = "$HOME/.warp/themes/catppuccin_frappe.yml" } }

[appearance.text]
font_size = 13.0
font_name = "JetBrainsMono Nerd Font Mono"

[general]
default_session_mode = "terminal"
restore_session = true
EOF_WARP_SETTINGS
fi
echo "  Ajustes y tema Catppuccin Frappé configurados en $WARP_CONFIG_DIR"

log "Verificando Android Studio"
if [ -d "/Applications/Android Studio.app" ] || brew list --cask android-studio &>/dev/null; then
  echo "  Android Studio OK, ya instalado"
else
  warn "Android Studio no encontrado. Instalando..."
  brew install --cask android-studio
fi

log "Verificando MongoDB Compass"
if [ -d "/Applications/MongoDB Compass.app" ] || brew list --cask mongodb-compass &>/dev/null; then
  echo "  MongoDB Compass OK, ya instalado"
else
  warn "MongoDB Compass no encontrado. Instalando..."
  brew install --cask mongodb-compass
fi

log "Verificando Cursor (Editor de código con IA)"
if [ -d "/Applications/Cursor.app" ] || brew list --cask cursor &>/dev/null; then
  echo "  Cursor OK, ya instalado"
else
  warn "Cursor no encontrado. Instalando..."
  brew install --cask cursor
fi

log "Configurando Google Chrome"
if [ -d "/Applications/Google Chrome.app" ] || brew list --cask google-chrome &>/dev/null; then
  echo "  Google Chrome OK, ya instalado"
else
  warn "Google Chrome no encontrado. Instalando..."
  brew install --cask google-chrome
fi

log "Verificando Claude Desktop (Aplicación Oficial de Claude AI)"
if [ -d "/Applications/Claude.app" ] || brew list --cask claude &>/dev/null; then
  echo "  Claude Desktop OK, ya instalado"
else
  warn "Claude Desktop no encontrado. Instalando..."
  brew install --cask claude
fi

log "Verificando Redis Insight (GUI para Redis)"
if [ -d "/Applications/Redis Insight.app" ] || [ -d "/Applications/RedisInsight.app" ] || brew list --cask redis-insight &>/dev/null; then
  echo "  Redis Insight OK, ya instalado"
else
  warn "Redis Insight no encontrado. Instalando..."
  brew install --cask redis-insight
fi

fi

if should_run 13; then
log "Configurando atajos de teclado y ajustes en Cursor"
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
mkdir -p "$CURSOR_USER_DIR"

cat > "$CURSOR_USER_DIR/keybindings.json" <<'EOF_CURSOR_KB'
// Place your key bindings in this file to override the defaults
[
  {
    "key": "alt+w",
    "command": "editor.emmet.action.wrapWithAbbreviation"
  },
  {
    "key": "shift+cmd+g",
    "command": "-workbench.action.terminal.findPrevious",
    "when": "terminalFindFocused && terminalHasBeenCreated || terminalFindFocused && terminalProcessSupported || terminalFocus && terminalHasBeenCreated || terminalFocus && terminalProcessSupported"
  },
  {
    "key": "shift+cmd+g",
    "command": "-editor.action.previousMatchFindAction",
    "when": "editorFocus"
  },
  {
    "key": "shift+cmd+g",
    "command": "workbench.view.scm",
    "when": "workbench.scm.active"
  },
  {
    "key": "ctrl+shift+g",
    "command": "-workbench.view.scm",
    "when": "workbench.scm.active"
  },
  {
    "key": "shift+cmd+g",
    "command": "workbench.view.scm",
    "when": "workbench.scm.active && !gitlens:disabled && config.gitlens.keymap == 'chorded'"
  },
  {
    "key": "ctrl+shift+g",
    "command": "-workbench.view.scm",
    "when": "workbench.scm.active && !gitlens:disabled && config.gitlens.keymap == 'chorded'"
  },
  {
    "key": "shift+cmd+c",
    "command": "-workbench.action.terminal.openNativeConsole",
    "when": "!terminalFocus"
  },
  {
    "key": "shift+cmd+z",
    "command": "-redo"
  },
  {
    "key": "cmd+k z",
    "command": "-workbench.action.toggleZenMode"
  },
  {
    "key": "shift+cmd+a",
    "command": "workbench.action.toggleActivityBarVisibility"
  },
  {
    "key": "shift+cmd+s",
    "command": "-workbench.action.files.saveLocalFile",
    "when": "remoteFileDialogVisible"
  },
  {
    "key": "shift+cmd+s",
    "command": "-workbench.action.files.saveAs"
  },
  {
    "key": "shift+cmd+s",
    "command": "saveAll"
  },
  {
    "key": "alt+cmd+s",
    "command": "-saveAll"
  },
  {
    "key": "shift+cmd+w",
    "command": "-workbench.action.closeWindow"
  },
  {
    "key": "shift+cmd+w",
    "command": "workbench.action.closeAllEditors"
  },
  {
    "key": "cmd+k cmd+w",
    "command": "-workbench.action.closeAllEditors"
  },
  {
    "key": "shift+cmd+c",
    "command": "workbench.files.action.collapseExplorerFolders",
    "when": "explorerViewletVisible && explorerViewletFocus && !inputFocus"
  },
  {
    "key": "shift+cmd+c",
    "command": "editor.toggleFold",
    "when": "editorFocus"
  },
  {
    "key": "shift+alt+c",
    "command": "editor.foldAll",
    "when": "editorTextFocus"
  },
  {
    "key": "ctrl+cmd+c",
    "command": "editor.unfoldAll",
    "when": "editorTextFocus"
  },
  {
    "key": "shift+cmd+t",
    "command": "-workbench.action.reopenClosedEditor"
  },
  {
    "key": "shift+cmd+b",
    "command": "-workbench.action.tasks.build",
    "when": "taskCommandsRegistered"
  },
  {
    "key": "shift+cmd+b",
    "command": "github.cweijan.mysql.focus"
  },
  {
    "key": "shift+cmd+r",
    "command": "-rerunSearchEditorSearch",
    "when": "inSearchEditor"
  },
  {
    "key": "shift+cmd+r",
    "command": "-reactSnippets.search",
    "when": "editorTextFocus"
  },
  {
    "key": "alt+space",
    "command": "editor.action.triggerSuggest",
    "when": "editorHasCompletionItemProvider && textInputFocus && !editorReadonly && !suggestWidgetVisible"
  },
  {
    "key": "ctrl+space",
    "command": "-editor.action.triggerSuggest",
    "when": "editorHasCompletionItemProvider && textInputFocus && !editorReadonly && !suggestWidgetVisible"
  },
  {
    "key": "alt+space",
    "command": "focusSuggestion",
    "when": "suggestWidgetVisible && textInputFocus && !suggestWidgetHasFocusedSuggestion"
  },
  {
    "key": "ctrl+space",
    "command": "-focusSuggestion",
    "when": "suggestWidgetVisible && textInputFocus && !suggestWidgetHasFocusedSuggestion"
  },
  {
    "key": "alt+space",
    "command": "workbench.action.terminal.sendSequence",
    "when": "terminalFocus && terminalShellIntegrationEnabled && !accessibilityModeEnabled && terminalShellType == 'pwsh'"
  },
  {
    "key": "ctrl+space",
    "command": "-workbench.action.terminal.sendSequence",
    "when": "terminalFocus && terminalShellIntegrationEnabled && !accessibilityModeEnabled && terminalShellType == 'pwsh'"
  },
  {
    "key": "alt+space",
    "command": "workbench.action.terminal.sendSequence",
    "when": "config.terminal.integrated.shellIntegration.suggestEnabled && terminalFocus && terminalShellIntegrationEnabled && !accessibilityModeEnabled && terminalShellType == 'pwsh'"
  },
  {
    "key": "ctrl+space",
    "command": "-workbench.action.terminal.sendSequence",
    "when": "config.terminal.integrated.shellIntegration.suggestEnabled && terminalFocus && terminalShellIntegrationEnabled && !accessibilityModeEnabled && terminalShellType == 'pwsh'"
  },
  {
    "key": "shift+cmd+z",
    "command": "redo"
  },
  {
    "key": "shift+cmd+b",
    "command": "workbench.action.toggleAuxiliaryBar"
  },
  {
    "key": "alt+cmd+b",
    "command": "-workbench.action.toggleAuxiliaryBar"
  },
  {
    "key": "cmd+k cmd+c",
    "command": "-editor.action.addCommentLine",
    "when": "editorTextFocus && !editorReadonly"
  },
  {
    "key": "shift+cmd+t",
    "command": "-headwind.sortTailwindClasses",
    "when": "editorFocus"
  },
  {
    "key": "shift+cmd+t",
    "command": "-mergeEditor.toggleBetweenInputs",
    "when": "isMergeEditor"
  },
  {
    "key": "ctrl+shift+`",
    "command": "-workbench.action.terminal.new",
    "when": "terminalProcessSupported || terminalWebExtensionContributedProfile"
  },
  {
    "key": "cmd+g",
    "command": "git-graph.view"
  },
  {
    "key": "shift+cmd+t",
    "command": "-workbench.action.terminal.new",
    "when": "terminalProcessSupported || terminalWebExtensionContributedProfile"
  },
  {
    "key": "shift+cmd+t",
    "command": "workbench.action.terminal.openNativeConsole",
    "when": "!terminalFocus"
  },
  {
    "key": "shift+cmd+r",
    "command": "npm.focus"
  },
  {
    "key": "shift+cmd+j",
    "command": "workbench.action.toggleMaximizedPanel",
    "when": "panelAlignment == 'center' || panelPosition != 'bottom' && panelPosition != 'top'"
  }
]
EOF_CURSOR_KB

cat > "$CURSOR_USER_DIR/settings.json" <<'EOF_CURSOR_ST'
{
  "editor.inlineSuggest.enabled": true,
  "editor.renderWhitespace": "none",
  "editor.tabSize": 2,
  "editor.fontWeight": "400",
  "editor.fontLigatures": true,
  "editor.acceptSuggestionOnEnter": "on",
  "editor.fontSize": 14,
  "editor.guides.bracketPairs": true,
  "editor.fontFamily": "Victor Mono",
  "editor.suggestSelection": "first",
  "editor.formatOnPaste": false,
  "editor.tokenColorCustomizations": {
    "textMateRules": [
      {
        "scope": "punctuation.definition.template-expression",
        "settings": {
          "foreground": "#fa2b7d"
        }
      },
      {
        "scope": "meta.template.expression",
        "settings": {
          "foreground": "#dcdcdc"
        }
      }
    ]
  },
  "editor.wordBasedSuggestions": "off",
  "editor.scrollbar.vertical": "hidden",
  "indenticator.width": 0.1,
  "indenticator.color.dark": "rgba(255, 255, 255, 0.1)",
  "editor.rulers": [],
  "editor.wordWrapColumn": 80,
  "editor.minimap.maxColumn": 50,
  "editor.formatOnType": false,
  "explorer.confirmDelete": true,
  "explorer.confirmDragAndDrop": true,
  "explorer.autoReveal": false,
  "emmet.triggerExpansionOnTab": true,
  "terminal.integrated.fontFamily": "victor mono",
  "terminal.integrated.fontSize": 14,
  "terminal.integrated.shellIntegration.enabled": true,
  "search.exclude": {
    "**/node_modules": true,
    "**/.next": true,
    "**/bower_components": true
  },
  "git.autofetch": true,
  "git.ignoreRebaseWarning": true,
  "gitlens.advanced.messages": {
    "suppressGitDisabledWarning": true
  },
  "files.trimTrailingWhitespace": true,
  "files.exclude": {
    ".next": false,
    "node_modules": false,
    ".idea": false
  },
  "liveServer.settings.port": 3000,
  "liveServer.settings.donotVerifyTags": true,
  "liveServer.settings.donotShowInfoMsg": true,
  "editor.colorDecorators": true,
  "editor.colorDecoratorsLimit": 500,
  "html.autoClosingTags": true,
  "javascript.autoClosingTags": true,
  "typescript.autoClosingTags": true,
  "markdown.preview.breaks": false,
  "markdown.preview.linkify": true,
  "markdown.preview.typographer": true,
  "markdown.validate.enabled": true,
  "editor.matchBrackets": false,
  "typescript.updateImportsOnFileMove.enabled": "always",
  "typescript.suggest.autoImports": true,
  "typescript.inlayHints.parameterNames.enabled": "all",
  "javascript.inlayHints.parameterTypes.enabled": true,
  "javascript.inlayHints.parameterNames.enabled": "all",
  "javascript.suggest.autoImports": true,
  "javascript.updateImportsOnFileMove.enabled": "always",
  "javascript.inlayHints.variableTypes.enabled": true,
  "javascript.validate.enable": true,
  "javascript.inlayHints.functionLikeReturnTypes.enabled": true,
  "javascript.inlayHints.propertyDeclarationTypes.enabled": true,
  "html.hover.documentation": false,
  "html.hover.references": false,
  "vscodeGoogleTranslate.preferredLanguage": "Spanish",
  "docwriter.hotkey.mac": "⌥ + .",
  "editor.accessibilitySupport": "off",
  "editor.bracketPairColorization.enabled": true,
  "editor.linkedEditing": true,
  "errorLens.excludeBySource": [
    "dart(file_names)"
  ],
  "workbench.activityBar.location": "top",
  "gitlens.graph.minimap.additionalTypes": [
    "localBranches",
    "stashes",
    "remoteBranches",
    "tags"
  ],
  "security.promptForLocalFileProtocolHandling": false,
  "diffEditor.ignoreTrimWhitespace": false,
  "git.confirmSync": false,
  "gitlens.graph.showRemoteNames": true,
  "gitHistory.sideBySide": true,
  "debug.showVariableTypes": true,
  "terminal.integrated.suggest.enabled": true,
  "workbench.colorTheme": "Catppuccin Frappé",
  "editor.copyWithSyntaxHighlighting": false,
  "editor.emptySelectionClipboard": true,
  "window.newWindowDimensions": "inherit",
  "editor.snippetSuggestions": "top",
  "editor.detectIndentation": false,
  "files.insertFinalNewline": true,
  "files.trimFinalNewlines": true,
  "editor.lineNumbers": "on",
  "editor.guides.indentation": false,
  "editor.hover.delay": 1500,
  "git.decorations.enabled": false,
  "editor.lightbulb.enabled": "off",
  "editor.overviewRulerBorder": false,
  "editor.renderLineHighlight": "none",
  "editor.occurrencesHighlight": "off",
  "problems.decorations.enabled": false,
  "editor.renderControlCharacters": false,
  "editor.gotoLocation.multipleReferences": "goto",
  "editor.gotoLocation.multipleDefinitions": "goto",
  "editor.gotoLocation.multipleDeclarations": "goto",
  "editor.gotoLocation.multipleImplementations": "goto",
  "editor.gotoLocation.multipleTypeDefinitions": "goto",
  "editor.wordWrap": "on",
  "cSpell.userWords": [
    "jonathanleivagomez"
  ],
  "terminal.integrated.minimumContrastRatio": 1,
  "terminal.explorerKind": "integrated",
  "workbench.settings.editor": "json",
  "editor.formatOnSave": true,
  "githubPullRequests.createOnPublishBranch": "never",
  "workbench.statusBar.visible": true,
  "workbench.tips.enabled": false,
  "workbench.view.alwaysShowHeaderActions": true,
  "workbench.view.showQuietly": {
    "workbench.panel.output": false
  },
  "breadcrumbs.enabled": false,
  "workbench.editor.enablePreview": false,
  "workbench.editor.empty.hint": "hidden",
  "workbench.editor.showTabs": "multiple",
  "zenMode.centerLayout": false,
  "window.dialogStyle": "custom",
  "editor.scrollbar.horizontal": "hidden",
  "editor.minimap.enabled": true,
  "editor.minimap.autohide": "none",
  "workbench.startupEditor": "readme",
  "terminal.external.osxExec": "Warp.app",
  "terminal.integrated.env.osx": {},
  "workbench.sideBar.location": "right",
  "workbench.colorCustomizations": {},
  "redhat.telemetry.enabled": true,
  "diffEditor.codeLens": true,
  "[dockercompose]": {
    "editor.insertSpaces": true,
    "editor.tabSize": 2,
    "editor.autoIndent": "advanced",
    "editor.defaultFormatter": "redhat.vscode-yaml"
  },
  "[github-actions-workflow]": {
    "editor.defaultFormatter": "redhat.vscode-yaml"
  },
  "[typescript]": {
    "editor.defaultFormatter": "vscode.typescript-language-features"
  },
  "terminal.integrated.inheritEnv": true,
  "claudeCode.preferredLocation": "panel",
  "claudeCode.useTerminal": true,
  "chat.commandCenter.enabled": false,
  "http.systemCertificatesNode": true,
  "workbench.iconTheme": "catppuccin-frappe",
  "typescript.experimental.useTsgo": true,
  "window.commandCenter": false,
  "workbench.quickOpen.closeOnFocusLost": false,
  "workbench.layoutControl.enabled": true
}
EOF_CURSOR_ST

echo "  Ajustes y atajos de teclado creados en $CURSOR_USER_DIR"

CURSOR_STATE_DB="$CURSOR_USER_DIR/globalStorage/state.vscdb"
mkdir -p "$CURSOR_USER_DIR/globalStorage"
if command -v sqlite3 &>/dev/null; then
  sqlite3 "$CURSOR_STATE_DB" "CREATE TABLE IF NOT EXISTS ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value TEXT);" 2>/dev/null || true
  sqlite3 "$CURSOR_STATE_DB" "INSERT INTO ItemTable(key, value) VALUES('cursor/agentLayout.quickMenu.lastSelectedLayoutId', 'default-agent') ON CONFLICT(key) DO UPDATE SET value='default-agent';" 2>/dev/null || true
  echo "  Layout predeterminado configurado en 'Agente' (Agent)"
fi

log "Instalando extensiones de Cursor (migradas desde Antigravity IDE)"
if command -v cursor &>/dev/null; then
  CURSOR_EXTS=(
    "aaron-bond.better-comments"
    "adpyke.codesnap"
    "adrianwilczynski.alpine-js-intellisense"
    "anthropic.claude-code"
    "apollographql.vscode-apollo"
    "astro-build.astro-vscode"
    "axetroy.vscode-npm-import-package-version"
    "aykutsarac.jsoncrack-vscode"
    "bradlc.vscode-tailwindcss"
    "catppuccin.catppuccin-vsc"
    "catppuccin.catppuccin-vsc-icons"
    "christian-kohler.path-intellisense"
    "cipchk.cssrem"
    "clinyong.vscode-css-modules"
    "csstools.postcss"
    "cweijan.vscode-database-client2"
    "dbaeumer.vscode-eslint"
    "donjayamanne.githistory"
    "dracula-theme.theme-dracula"
    "dsznajder.es7-react-js-snippets"
    "eamodio.gitlens"
    "esbenp.prettier-vscode"
    "expo.vscode-expo-tools"
    "funkyremi.vscode-google-translate"
    "github.vscode-pull-request-github"
    "golang.go"
    "googlecloudtools.datacloud"
    "gruntfuggly.todo-tree"
    "heybourn.headwind"
    "idered.npm"
    "intellsmi.comment-translate"
    "irongeek.vscode-env"
    "johnpapa.vscode-cloak"
    "llvm-vs-code-extensions.vscode-clangd"
    "mechatroner.rainbow-csv"
    "mguellsegarra.highlight-on-copy"
    "mhutchie.git-graph"
    "midudev.better-svg"
    "mikestead.dotenv"
    "mintlify.document"
    "mongodb.mongodb-vscode"
    "ms-azuretools.vscode-docker"
    "ms-python.debugpy"
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-toolsai.jupyter"
    "ms-vscode-remote.remote-containers"
    "ms-vscode.live-server"
    "msjsdiag.vscode-react-native"
    "mtxr.sqltools"
    "mtxr.sqltools-driver-mysql"
    "mtxr.sqltools-driver-pg"
    "mtxr.sqltools-driver-sqlite"
    "pepeelpollo.pepe-csv-editor"
    "pepeelpollo.pepe-ident"
    "pepeelpollo.pepe-json-viewer"
    "pepeelpollo.pepe-logs"
    "pepeelpollo.purple-neon-pepe"
    "pflannery.vscode-versionlens"
    "pkief.material-icon-theme"
    "pmneo.tsimporter"
    "pranaygp.vscode-css-peek"
    "prisma.prisma"
    "purocean.drawio-preview"
    "quicktype.quicktype"
    "rafamel.subtle-brackets"
    "redhat.vscode-yaml"
    "redis.redis-for-vscode"
    "sdras.night-owl"
    "shopify.ruby-lsp"
    "sirtori.indenticator"
    "solnurkarim.html-to-css-autocompletion"
    "sporiley.css-auto-prefix"
    "stackbreak.comment-divider"
    "streetsidesoftware.code-spell-checker"
    "streetsidesoftware.code-spell-checker-spanish"
    "tobermory.es6-string-html"
    "tomoki1207.pdf"
    "tyriar.lorem-ipsum"
    "usernamehw.errorlens"
    "vscodevim.vim"
    "vue.volar"
    "sdras.vue-vscode-snippets"
    "Vue.vscode-typescript-vue-plugin"
    "vunguyentuan.vscode-css-variables"
    "wix.vscode-import-cost"
    "xabikos.javascriptsnippets"
    "yoavbls.pretty-ts-errors"
    "zignd.html-css-class-completion"
    "zitup.classnametocss"
  )
  for ext in "${CURSOR_EXTS[@]}"; do
    cursor --install-extension "$ext" &>/dev/null || true
  done
  echo "  Extensiones de Cursor instaladas y actualizadas"
fi

fi

# ---------- Fin ----------

log "Listo. Resumen de lo instalado:"
echo "  - gh (GitHub CLI) + identidad de git por carpeta (personal/trabajo)"
echo "  - nvm + Node LTS + pnpm (vía corepack)"
echo "  - Warp + Lens + Docker Desktop + Android Studio + MongoDB Compass + Cursor + Google Chrome + Claude Desktop + Redis Insight (Aplicaciones GUI)"
echo "  - zsh-completions + fzf-tab + zsh-autosuggestions + zsh-syntax-highlighting + fzf"
echo "  - Starship (prompt con git/node/duración de comandos)"
echo "  - zoxide + bat + eza (+ alias cd/ls/ll/lt/cat)"
echo "  - kubectl + k9s + kubectx/kubens + stern (Kubernetes)"
echo "  - Docker + lazydocker"
echo "  - lazysql (MySQL/PostgreSQL)"
echo "  - lazymongo + mongosh (MongoDB) + conexiones nombradas ('mgo <nombre>')"
echo "  - Neovim + LazyVim en $NVIM_CONFIG (+ extras typescript/vue/astro/tailwind/json/prettier/eslint)"
echo "  - Dashboard de bienvenida personalizado con tu nombre"
echo "  - tmux + TPM (tmux-sensible, tmux-resurrect, tmux-continuum)"
echo "  - Claude Code + Graphify (asistentes de código con IA y grafo de conocimiento)"
echo ""
echo "Siguiente paso: abre una terminal nueva o corre 'source ~/.zshrc' para aplicar los cambios de shell."
echo "Luego abre 'nvim' una vez para que Mason instale los LSPs de los extras habilitados."
echo "Y abre 'tmux', presiona prefix+I (Ctrl-a, I) para instalar los plugins de TPM."
echo ""
echo "Recuerda: si versionas $NVIM_CONFIG en tu propio repo de GitHub, en tu próximo Mac"
echo "solo necesitas clonar tu fork en vez de LazyVim/starter, y luego correr este script"
echo "para el resto de las herramientas."
