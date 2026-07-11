# Stack de terminal — Jonathan

Configuración reproducible para migrar de entorno gráfico (VSCode/Antigravity, Lens, Docker Desktop) a un flujo 100% en terminal, en cualquier Mac (Apple Silicon o Intel).

## Contenido

- `setup-terminal-stack.sh` — script principal, idempotente (se puede correr varias veces sin duplicar configuración).

## Cómo ejecutarlo (Mac nuevo o reinstalación)

```bash
cd ~/Development/dev/
chmod +x setup-terminal-stack.sh
./setup-terminal-stack.sh
```

Al terminar:

```bash
source ~/.zshrc
```

o simplemente cierra y abre una terminal nueva.

Luego abre `nvim` una vez para que Mason instale automáticamente los LSPs de los extras de LazyVim (typescript, vue, json, prettier, eslint).

## Qué instala

| Categoría          | Herramientas                                                                     |
| ------------------ | -------------------------------------------------------------------------------- |
| Base               | Homebrew, git, gh (GitHub CLI), nvm + Node LTS                                   |
| Shell              | zsh, zsh-completions, fzf-tab, zsh-autosuggestions, fzf, zsh-syntax-highlighting |
| Prompt             | Starship (git branch/status, node, duración de comandos)                         |
| Terminal           | Ghostty (tema Catppuccin Mocha, fuente JetBrainsMono Nerd Font)                  |
| Kubernetes         | kubectl, k9s, kubectx/kubens, stern                                              |
| Docker             | lazydocker (+ valida que Docker esté instalado y corriendo)                      |
| Bases relacionales | lazysql (MySQL + PostgreSQL)                                                     |
| MongoDB            | vi-mongo, mongosh                                                                |
| Editor             | Neovim + LazyVim en `~/.config/nvim` (con extras JS/TS/Vue)                      |

Nada de esto borra o reemplaza tus apps gráficas actuales — todo corre en paralelo.

## Repo de tu config de Neovim

El script inicializa `~/.config/nvim` como su propio repo git. Para respaldarla en GitHub y poder clonarla en otro Mac en vez de partir de LazyVim/starter desde cero:

```bash
cd ~/.config/nvim
git remote add origin <url-de-tu-repo>
git push -u origin main
```

En un Mac nuevo, antes de correr el script:

```bash
git clone <url-de-tu-repo> ~/.config/nvim
```

---

## Troubleshooting — errores ya resueltos en esta instalación

### 1. Ghostty: `theme "catppuccin-mocha" not found`

**Causa:** el nombre del tema en Ghostty va con mayúsculas y espacio, no en formato `kebab-case`.

**Ver los nombres exactos disponibles:**

```bash
/Applications/Ghostty.app/Contents/MacOS/ghostty +list-themes | grep -i catppuccin
```

**Corregir la config** (`~/.config/ghostty/config`):

```bash
sed -i '' 's/theme = catppuccin-mocha/theme = "Catppuccin Mocha"/' ~/.config/ghostty/config
```

**Confirmar:**

```bash
cat ~/.config/ghostty/config
```

Luego cerrar y volver a abrir Ghostty por completo (no solo "Reload Configuration" si el archivo cambió después de que el diálogo ya estaba abierto).

> Nota: el script `setup-terminal-stack.sh` ya quedó corregido con el nombre correcto para futuras instalaciones (en otro Mac no debería volver a pasar).

### 2. zsh: `compinit: insecure directories, run compaudit for list`

**Causa:** un directorio en el `$FPATH` (usado por zsh-completions) tiene permisos de escritura para group/other, lo cual zsh marca como riesgo de seguridad.

**Ver cuáles directorios están marcados:**

```bash
compaudit
```

→ Resultado en este caso: `/opt/homebrew/share`

**Corregir permisos:**

```bash
chmod go-w /opt/homebrew/share
```

**Confirmar que ya no hay directorios inseguros** (no debe imprimir nada):

```bash
compaudit
```

Abrir una terminal nueva para confirmar que el mensaje ya no aparece al iniciar sesión.

---

### 3. `zsh: command not found: gh`

**Causa:** GitHub CLI no estaba instalado (ya corregido en el script — ahora se instala junto con git, y el script te pregunta si quieres correr `gh auth login` en el momento).

**Instalar/autenticar manualmente si hace falta:**

```bash
brew install gh
gh auth login
```

`gh auth login` te guía para autenticarte (HTTPS o SSH, autorización vía navegador).

---

## Subir este repo a GitHub

```bash
cd ~/Development/dev/
git init
git add .
git commit -m "Setup inicial: stack de terminal"

# Con gh ya instalado y autenticado:
gh repo create terminal-stack --private --source=. --remote=origin --push
```

Alternativa manual (sin `gh`): crear el repo vacío en https://github.com/new y luego:

```bash
git remote add origin https://github.com/TU_USUARIO/terminal-stack.git
git branch -M main
git push -u origin main
```

## Notas

- Si en el futuro `compaudit` vuelve a marcar directorios (por ejemplo tras un `brew upgrade` que cambie permisos), corre de nuevo `compaudit` y aplica `chmod go-w <ruta>` sobre lo que aparezca.
- Si cambias el tema de Ghostty más adelante, usa siempre `+list-themes` primero para copiar el nombre exacto — evita adivinar el formato.
