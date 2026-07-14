#!/usr/bin/env bash
#
# setup-terminal-stack.sh
#
# Instalación reproducible del stack de terminal:
# Warp/Ghostty (+ tema, fuente Nerd Font) + zsh (completions, fzf-tab clonado,
# autosuggestions, syntax-highlighting, fzf) + Starship (prompt) +
# zoxide/bat/eza + git config + pnpm/yarn + kubectl/k9s + Docker/lazydocker +
# lazysql + lazymongo + LazyVim (+ extras typescript/vue/astro/tailwind/json/
# prettier/eslint + dashboard personalizado) + tmux (+ TPM y plugins) +
# Claude Code + Codex CLI + Antigravity CLI
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

# ---------- 1. git ----------

log "Verificando git"
if ! command -v git &>/dev/null; then
  warn "git no encontrado. Instalando Xcode Command Line Tools (incluye git)..."
  xcode-select --install || warn "Si ya se está instalando o falló, revisa manualmente con: xcode-select --install"
else
  echo "  git OK ($(git --version))"
fi

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

log "Configurando lazygit (customCommands con IA)"
LAZYGIT_CONFIG_DIR="$HOME/Library/Application Support/lazygit"
mkdir -p "$LAZYGIT_CONFIG_DIR"
cat > "$LAZYGIT_CONFIG_DIR/config.yml" <<'EOF'
customCommands:
  # --- SECCIÓN DE ARCHIVOS (Files Panel) ---
  # Generar commit automático con IA para los cambios staged
  - key: 'g'
    command: >
      git commit -m "$(git diff --cached | agy -p 'Analiza el diff de git y genera un mensaje de commit convencional corto, conciso y en una sola línea. Devuelve ÚNICAMENTE la línea del mensaje, sin explicaciones ni formato markdown.')"
    context: 'files'
    loadingText: 'Generando commit con IA (Antigravity)...'
    subprocess: true

  # Explicar los cambios del archivo seleccionado (staged y unstaged)
  - key: 'x'
    command: >
      agy -p "Explica de forma concisa los cambios realizados en el archivo {{.SelectedFile.Name}}:\n\n$(git diff HEAD -- {{.SelectedFile.Name}})"
    context: 'files'
    loadingText: 'Explicando cambios del archivo con IA...'
    subprocess: true

  # --- SECCIÓN DE COMMITS (Commits Panel) ---
  # Explicar los cambios y propósito del commit seleccionado
  - key: 'x'
    command: >
      agy -p "Explica qué hace este commit y resume los cambios principales de forma concisa y directa:\n\n$(git show {{.SelectedLocalCommit.Hash}})"
    context: 'commits'
    loadingText: 'Analizando commit con IA...'
    subprocess: true

  # --- SECCIÓN DE RAMAS (Local Branches Panel) ---
  # Resumir todos los cambios de la rama seleccionada en comparación con main
  - key: 'x'
    command: >
      agy -p "Resume los cambios realizados en la rama local '{{.SelectedLocalBranch.Name}}' en comparación con la rama principal (main):\n\n$(git diff main...{{.SelectedLocalBranch.Name}})"
    context: 'localBranches'
    loadingText: 'Resumiendo cambios de la rama con IA...'
    subprocess: true
EOF
echo "  Config de lazygit creada/actualizada en $LAZYGIT_CONFIG_DIR/config.yml"

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

  # Asegurar que quede en .zshrc para futuras sesiones (el instalador de nvm
  # normalmente ya lo agrega, pero lo confirmamos por si acaso)
  touch "$HOME/.zshrc"
  append_once 'export NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc"
  append_once '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' "$HOME/.zshrc"
  append_once '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' "$HOME/.zshrc"
else
  echo "  nvm OK ($(nvm --version))"
fi

# Instalar Node LTS si no hay ninguna versión de node instalada vía nvm
if command -v nvm &>/dev/null && [ -z "$(nvm ls --no-colors 2>/dev/null | grep -v 'N/A')" ]; then
  log "No hay versiones de Node instaladas vía nvm, instalando LTS"
  nvm install --lts
  nvm alias default lts/*
fi

log "Verificando pnpm y yarn (vía corepack, incluido con Node)"
if command -v corepack &>/dev/null; then
  corepack enable 2>/dev/null || warn "corepack enable falló, revisa permisos o corre manualmente"

  if command -v pnpm &>/dev/null; then
    echo "  pnpm OK ($(pnpm --version))"
  else
    warn "Activando pnpm vía corepack..."
    corepack prepare pnpm@latest --activate
  fi

  if command -v yarn &>/dev/null; then
    echo "  yarn OK ($(yarn --version))"
  else
    warn "Activando yarn vía corepack..."
    corepack prepare yarn@stable --activate
  fi
else
  warn "corepack no encontrado (viene con Node 16.10+). Instalando pnpm/yarn como paquetes globales de npm en su lugar..."
  npm install -g pnpm yarn
fi

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

# ---------- 4. Terminal emulator ----------

log "Verificando Ghostty"
if [ -d "/Applications/Ghostty.app" ] || brew list --cask ghostty &>/dev/null; then
  echo "  Ghostty OK, ya instalado"
else
  warn "Ghostty no encontrado. Instalando..."
  brew install --cask ghostty
fi

log "Configurando Ghostty (tema, fuente, transparencia)"
GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
GHOSTTY_CONFIG_FILE="$GHOSTTY_CONFIG_DIR/config"
mkdir -p "$GHOSTTY_CONFIG_DIR"

if [ -f "$GHOSTTY_CONFIG_FILE" ]; then
  warn "Ya existe $GHOSTTY_CONFIG_FILE — no se sobreescribe para no perder tus ajustes."
  echo "  Config sugerida disponible en: $GHOSTTY_CONFIG_FILE.suggested"
  cat > "$GHOSTTY_CONFIG_FILE.suggested" <<'EOF'
# Config sugerida de Ghostty — copia lo que quieras a tu config real
theme = "Catppuccin Mocha"
font-family = "JetBrainsMono Nerd Font"
font-size = 14
background-opacity = 0.95
window-padding-x = 10
window-padding-y = 10
cursor-style = block
mouse-hide-while-typing = true

# Keybind explícito de paste (texto). NO habilita pegado de imágenes —
# Ghostty aún no lo soporta (confirmado revisando su código fuente, v1.3.1).
keybind = super+v=paste_from_clipboard
EOF
else
  cat > "$GHOSTTY_CONFIG_FILE" <<'EOF'
# Config inicial generada por setup-terminal-stack.sh
theme = "Catppuccin Mocha"
font-family = "JetBrainsMono Nerd Font"
font-size = 14
background-opacity = 0.95
window-padding-x = 10
window-padding-y = 10
cursor-style = block
mouse-hide-while-typing = true

# Keybind explícito de paste (texto). NO habilita pegado de imágenes —
# Ghostty aún no lo soporta (confirmado revisando su código fuente, v1.3.1).
keybind = super+v=paste_from_clipboard
EOF
  echo "  Config creada en $GHOSTTY_CONFIG_FILE"
fi

log "Verificando fuente JetBrainsMono Nerd Font (usada en la config de Ghostty)"
if brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
  echo "  Fuente OK, ya instalada"
else
  warn "Fuente no encontrada. Instalando..."
  brew install --cask font-jetbrains-mono-nerd-font
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

log "Configurando alias (cat, ls, cd -> bat, eza, zoxide)"
append_once 'alias cat="bat"' "$ZSHRC"
append_once 'alias ls="eza --icons --group-directories-first"' "$ZSHRC"
append_once 'alias ll="eza -la --icons --group-directories-first"' "$ZSHRC"
append_once 'alias lt="eza --tree --icons --level=2"' "$ZSHRC"
append_once 'alias cd="z"' "$ZSHRC"
append_once 'alias e="exit"' "$ZSHRC"
append_once 'alias vi="nvim"' "$ZSHRC"
append_once 'alias gg="lazygit"' "$ZSHRC"
append_once 'alias lazymongo="~/go/bin/lazymongo"' "$ZSHRC"
append_once 'alias lezymongo="lazymongo"' "$ZSHRC"
append_once 'alias lm="lazymongo"' "$ZSHRC"
append_once 'alias tm="tmux-mosaic"' "$ZSHRC"

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

log "Instalando k9s (+ kubectx/kubens, stern)"
brew install k9s kubectx stern

# ---------- 9. Docker ----------

log "Verificando Docker"
if command -v docker &>/dev/null; then
  echo "  Docker CLI OK ($(docker --version))"
  if docker info &>/dev/null; then
    echo "  Docker daemon corriendo OK"
  else
    warn "Docker está instalado pero el daemon no responde. Abre Docker Desktop (o inicia el daemon) antes de usar lazydocker."
  fi
else
  warn "Docker no encontrado."
  read -r -p "  ¿Quieres instalar Docker Desktop ahora? (y/n) " respuesta_docker
  if [ "$respuesta_docker" = "y" ] || [ "$respuesta_docker" = "Y" ]; then
    brew install --cask docker
    warn "Docker Desktop se instaló pero necesita abrirse manualmente al menos una vez"
    warn "(aceptar términos, dar permisos) antes de que lazydocker pueda usarlo."
  else
    warn "Se omite Docker. lazydocker se instalará igual, pero no funcionará hasta que tengas Docker corriendo."
  fi
fi

log "Instalando lazydocker"
brew install lazydocker

# ---------- 10. Bases de datos relacionales ----------

log "Instalando lazysql (MySQL + PostgreSQL)"
brew install lazysql

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
  { import = "lazyvim.plugins.extras.formatting.prettier" },
  { import = "lazyvim.plugins.extras.linting.eslint" },
}
EOF
  echo "  Extras creados en $EXTRAS_FILE"
  echo "  (typescript, vue, astro, tailwind, json, prettier, eslint — Mason los instalará al abrir nvim por primera vez)"
fi

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
    _               _   _              _     _
 _ | |___ _ _  __ _| |_| |_  __ _ _ _ | |___(_)_ ____ _ __ _
| || / _ \ ' \/ _` |  _| ' \/ _` | ' \| / -_) \ V / _` / _` |
 \__/\___/_||_\__,_|\__|_||_\__,_|_||_|_\___|_|\_/\__,_\__, |
                                                       |___/ ]],
        },
      },
    },
  },
}
EOF
  echo "  Dashboard personalizado creado en $DASHBOARD_FILE"
fi

log "Desactivando chequeo de orden de imports de LazyVim (falso positivo con extras.lua manual)"
OPTIONS_FILE="$NVIM_CONFIG/lua/config/options.lua"
if [ -f "$OPTIONS_FILE" ]; then
  append_once "vim.g.lazyvim_check_order = false" "$OPTIONS_FILE"
else
  mkdir -p "$NVIM_CONFIG/lua/config"
  echo "vim.g.lazyvim_check_order = false" > "$OPTIONS_FILE"
  echo "  Creado $OPTIONS_FILE"
fi

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

# Mouse: click para cambiar de panel, arrastrar para redimensionar, scroll para history
set -g mouse on

# Splits más intuitivos (mantienen el directorio actual)
unbind '"'
unbind %
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
# tmux-mosaic
#
# Abre todas las subcarpetas (proyectos) de un directorio como paneles (splits)
# en un mosaico perfectamente ordenado utilizando tmux.
#
# Uso:
#   tmux-mosaic [/ruta/a/la/carpeta]
#

set -euo pipefail

# Directorio base (por defecto el directorio actual)
TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# Obtener subcarpetas
directories=()
while IFS= read -r -d '' dir; do
  directories+=("$dir")
done < <(find -L "$TARGET_DIR" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)

if [ ${#directories[@]} -eq 0 ]; then
  echo "No se encontraron subcarpetas (proyectos) en: $TARGET_DIR"
  exit 1
fi

SESSION_NAME="mosaico-$(basename "$TARGET_DIR" | tr '.' '-')"

# Matar sesión si ya existe una con el mismo nombre para evitar conflictos
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux kill-session -t "$SESSION_NAME"
fi

# Iniciar la sesión de tmux en segundo plano con la primera carpeta
cd "${directories[0]}"
tmux new-session -d -s "$SESSION_NAME"

# Crear un panel (split) para cada una de las carpetas restantes
for ((i=1; i<${#directories[@]}; i++)); do
  dir="${directories[i]}"
  # Crear split horizontal en el directorio correspondiente
  tmux split-window -t "$SESSION_NAME" -c "$dir"
  # Reordenar automáticamente los paneles como mosaico (grid)
  tmux select-layout -t "$SESSION_NAME" tiled
done

# Balancear el mosaico final por si acaso
tmux select-layout -t "$SESSION_NAME" tiled

# Acoplarse a la sesión de tmux
tmux attach-session -t "$SESSION_NAME"
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

# ---------- 14. Asistentes de código con IA (CLIs) ----------

log "Verificando Claude Code"
if brew list --cask claude-code &>/dev/null; then
  echo "  Claude Code OK, ya instalado"
else
  warn "Claude Code no encontrado. Instalando..."
  brew install --cask claude-code
fi

log "Verificando Codex CLI"
if brew list --cask codex &>/dev/null; then
  echo "  Codex CLI OK, ya instalado"
else
  warn "Codex CLI no encontrado. Instalando..."
  brew install --cask codex
fi

log "Verificando Antigravity CLI"
if brew list --cask antigravity-cli &>/dev/null; then
  echo "  Antigravity CLI OK, ya instalado"
else
  warn "Antigravity CLI no encontrado. Instalando..."
  brew install --cask antigravity-cli
fi

# ---------- Fin ----------

log "Listo. Resumen de lo instalado:"
echo "  - gh (GitHub CLI) + identidad de git por carpeta (personal/trabajo)"
echo "  - nvm + Node LTS + pnpm + yarn (vía corepack)"
echo "  - Ghostty (terminal alterno, opcional junto a Warp) + config visual + fuente Nerd Font"
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
echo "  - Claude Code + Codex CLI + Antigravity CLI (asistentes de código con IA)"
echo ""
echo "Siguiente paso: abre una terminal nueva o corre 'source ~/.zshrc' para aplicar los cambios de shell."
echo "Luego abre 'nvim' una vez para que Mason instale los LSPs de los extras habilitados."
echo "Y abre 'tmux', presiona prefix+I (Ctrl-a, I) para instalar los plugins de TPM."
echo ""
echo "Recuerda: si versionas $NVIM_CONFIG en tu propio repo de GitHub, en tu próximo Mac"
echo "solo necesitas clonar tu fork en vez de LazyVim/starter, y luego correr este script"
echo "para el resto de las herramientas."
