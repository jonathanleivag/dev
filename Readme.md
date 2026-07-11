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

Luego abre `nvim` una vez para que Mason instale automáticamente los LSPs de los extras de LazyVim (typescript, vue, json, prettier, eslint) — ver detalles en la sección "Primer uso de LazyVim" más abajo.

## Qué instala

| Categoría          | Herramientas                                                                                           |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| Base               | Homebrew, git (identidad por carpeta: personal/trabajo), gh (GitHub CLI), nvm + Node LTS + pnpm + yarn |
| Shell              | zsh, zsh-completions, fzf-tab, zsh-autosuggestions, fzf, zsh-syntax-highlighting                       |
| Prompt             | Starship (git branch/status, node, duración de comandos)                                               |
| CLI moderna        | zoxide (`z`/`cd`), bat (`cat`), eza (`ls`/`ll`/`lt`)                                                   |
| Terminal           | Ghostty (tema Catppuccin Mocha, fuente JetBrainsMono Nerd Font)                                        |
| Multiplexor        | tmux + TPM (tmux-sensible, tmux-resurrect, tmux-continuum)                                             |
| Kubernetes         | kubectl, k9s, kubectx/kubens, stern                                                                    |
| Docker             | lazydocker (+ valida que Docker esté instalado y corriendo)                                            |
| Bases relacionales | lazysql (MySQL + PostgreSQL)                                                                           |
| MongoDB            | vi-mongo, mongosh                                                                                      |
| Editor             | Neovim + LazyVim en `~/.config/nvim` (con extras JS/TS/Vue/Astro/Tailwind + dashboard personalizado)   |

Nada de esto borra o reemplaza tus apps gráficas actuales — todo corre en paralelo.

## Alias de CLI moderna

El script agrega estos alias a tu `.zshrc`:

| Alias | Reemplaza | Con                                                    |
| ----- | --------- | ------------------------------------------------------ |
| `cat` | `cat`     | `bat` (resaltado de sintaxis, números de línea)        |
| `ls`  | `ls`      | `eza --icons --group-directories-first`                |
| `ll`  | —         | `eza -la --icons --group-directories-first`            |
| `lt`  | —         | `eza --tree --icons --level=2`                         |
| `cd`  | `cd`      | `z` (zoxide — salto inteligente por frecuencia de uso) |

`zoxide` aprende de tus `cd` con el tiempo: después de visitar una carpeta unas cuantas veces, `z nombre-parcial` te lleva ahí sin necesidad de la ruta completa.

## tmux

El script instala tmux con una config lista para usar (`~/.tmux.conf`) y **TPM** (Tmux Plugin Manager):

- **Prefix:** `Ctrl-a` (en vez del default `Ctrl-b`)
- **Splits:** `prefix + |` (vertical), `prefix + -` (horizontal) — abren en el directorio actual
- **Navegación entre paneles:** `prefix + h/j/k/l` (estilo vim)
- **Mouse:** activado (clic para cambiar de panel, arrastrar para redimensionar, scroll para history)
- **Recargar config:** `prefix + r`
- **Plugins incluidos:** `tmux-sensible`, `tmux-resurrect` (guardar/restaurar sesiones), `tmux-continuum` (autoguardado cada 15 min + restaurar sesión al abrir tmux)

**Primera vez:** abre `tmux` y presiona `prefix + I` (Ctrl-a, luego `I` mayúscula) para que TPM instale los plugins.

## Primer uso de LazyVim

**Paso 1 — Abrir nvim por primera vez**

```bash
nvim
```

La primera vez instala automáticamente todos los plugins de LazyVim (pantalla de progreso) y, con **Mason**, descarga los LSPs de los extras habilitados (typescript-language-server, vue-language-server, astro-language-server, tailwindcss-language-server, eslint-lsp, prettier). Puede tardar 1-2 minutos — espera a que termine antes de cerrar.

**Paso 2 — Verificar que los LSPs quedaron instalados**

Dentro de nvim:

```
:Mason
```

Debes ver `typescript-language-server`, `vue-language-server`, `astro-language-server`, `tailwindcss-language-server`, `eslint-lsp`, `prettier`, etc. con ícono verde (instalados).

**Paso 3 — Atajos básicos para probar en un proyecto real**

```bash
cd ~/algun-proyecto-ts
nvim .
```

| Atajo        | Acción                                |
| ------------ | ------------------------------------- |
| `gd`         | Ir a definición                       |
| `K`          | Ver documentación/tipo bajo el cursor |
| `<leader>ca` | Code actions (autofix, imports, etc.) |
| `<leader>ff` | Buscar archivo                        |
| `<leader>fg` | Buscar texto en el proyecto           |
| `<leader>e`  | File explorer                         |

> El `<leader>` por defecto en LazyVim es la barra espaciadora.

Nota: los plugins de git integrados (`gitsigns`, incluido por defecto) usan tu `~/.gitconfig` global — no requieren configuración adicional en LazyVim.

### Extras agregados manualmente (Astro + Tailwind)

Como tu `~/.config/nvim` ya existía cuando agregamos estos frameworks, el script no los agregó solo (por diseño, para no sobreescribir tus ajustes). Se agregaron a mano en:

```bash
nvim ~/.config/nvim/lua/plugins/extras.lua
```

Contenido final del archivo:

```lua
return {
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.vue" },
  { import = "lazyvim.plugins.extras.lang.astro" },
  { import = "lazyvim.plugins.extras.lang.tailwind" },
  { import = "lazyvim.plugins.extras.lang.json" },
  { import = "lazyvim.plugins.extras.formatting.prettier" },
  { import = "lazyvim.plugins.extras.linting.eslint" },
}
```

React, Next.js y Nest.js no necesitan extras propios — ya quedan cubiertos por `lang.typescript` (JSX/TSX y decoradores incluidos).

Tras editar, reabre `nvim` — Lazy sincroniza los nuevos imports solo. Si no arranca automático: `:Lazy sync`.

### Dashboard de bienvenida personalizado

La pantalla de inicio de LazyVim (antes mostraba "LAZYVIM" en ASCII art) ahora muestra el nombre `Jonathanleivag`. Configurado en:

```bash
~/.config/nvim/lua/plugins/dashboard.lua
```

Usa el plugin `snacks.nvim` (el que trae LazyVim para el dashboard), sobreescribiendo `opts.dashboard.preset.header` con el ASCII art. Si quieres cambiarlo por otro texto o estilo, genera uno nuevo con `figlet` (fuentes: `figlet -l` para listarlas) y reemplaza el contenido entre `[[ ]]` en ese archivo.

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

### 0. Identidad de git: personal vs. trabajo

Como manejas proyectos personales y de trabajo (Movatec) en carpetas separadas, el script configura **dos identidades automáticas por carpeta**, en vez de un solo `user.name`/`user.email` global:

- **Personal (default):** aplica a cualquier repo fuera de la carpeta de trabajo → configurado directamente en `~/.gitconfig`.
- **Trabajo:** aplica solo dentro de `~/Development/Movatec/` (o la ruta que hayas indicado) → vive en un archivo separado, `~/.gitconfig-work`, cargado automáticamente vía `includeIf "gitdir:..."`.

**La primera vez que corres el script**, te pregunta:

1. Carpeta de proyectos personales (default sugerido: `~/Development/jonathanleivag`)
2. Carpeta de proyectos de trabajo (default sugerido: `~/Development/Movatec`)
3. Nombre y email para el perfil personal
4. Nombre y email para el perfil de trabajo

**Verificar que quedó bien**, parado dentro de un repo de cada carpeta:

```bash
cd ~/Development/jonathanleivag/algun-proyecto && git config user.name && git config user.email
cd ~/Development/Movatec/algun-proyecto && git config user.name && git config user.email
```

Cada uno debe mostrar la identidad correspondiente.

**Ver la config resultante:**

```bash
cat ~/.gitconfig
cat ~/.gitconfig-work
```

**Si agregas una nueva carpeta de trabajo más adelante** (otro cliente, otro repo fuera de `Movatec`), agrega un bloque similar a mano en `~/.gitconfig`:

```
[includeIf "gitdir:~/Development/OtraCarpeta/"]
  path = ~/.gitconfig-work
```

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

### 4. LazyVim: `The order of your lazy.nvim imports is incorrect`

**Causa:** es solo una **advertencia**, no un error — los plugins se instalan igual. LazyVim valida el orden esperado de imports (`lazyvim.plugins` → `lazyvim.plugins.extras.*` → tus propios `plugins`), y como agregamos `extras.lua` manualmente (patrón oficial y recomendado por LazyVim), el chequeo a veces da falso positivo.

**Ya corregido en el script:** agrega `vim.g.lazyvim_check_order = false` en `~/.config/nvim/lua/config/options.lua`.

**Aplicar manualmente si hace falta:**

```bash
echo "vim.g.lazyvim_check_order = false" >> ~/.config/nvim/lua/config/options.lua
```

Reabre `nvim` y el aviso no debería volver a aparecer.

---

## Repo en GitHub

Este repo (`terminal-stack`) ya está subido a tu cuenta de GitHub. Para clonarlo en un Mac nuevo:

```bash
gh repo clone terminal-stack ~/Development/dev
cd ~/Development/dev
chmod +x setup-terminal-stack.sh
./setup-terminal-stack.sh
```

**Para futuros cambios** (por ejemplo, si editas el script o este README):

```bash
cd ~/Development/dev/
git add .
git commit -m "Describe aquí el cambio"
git push
```

## Notas

- Si en el futuro `compaudit` vuelve a marcar directorios (por ejemplo tras un `brew upgrade` que cambie permisos), corre de nuevo `compaudit` y aplica `chmod go-w <ruta>` sobre lo que aparezca.
- Si cambias el tema de Ghostty más adelante, usa siempre `+list-themes` primero para copiar el nombre exacto — evita adivinar el formato.
