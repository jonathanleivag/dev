# Stack de terminal — Jonathan

Configuración reproducible para migrar de entorno gráfico (VSCode/Antigravity, Lens, Docker Desktop) a un flujo 100% en terminal y optimizado para desarrollo con Cursor, en cualquier Mac (Apple Silicon o Intel).

## Contenido

- `config.sh` — script principal, idempotente y con **menú interactivo** (se puede correr varias veces sin duplicar configuración).

## Cómo ejecutarlo (Mac nuevo o reinstalación)

```bash
cd ~/Development/dev/
chmod +x config.sh
./config.sh
```

Al ejecutar `./config.sh` se abrirá un **Menú Interactivo** (impulsado por `fzf`) que te permite seleccionar exactamente qué módulos deseas instalar o actualizar:

* **[Tab] / [Espacio]**: Selecciona o desmarca los módulos que quieras.
* **[Enter]**: Confirma y ejecuta los módulos elegidos.

> 💡 **Modo Automático:** Si deseas instalar/actualizar todo sin abrir el menú interactivo, ejecuta:
> ```bash
> ./config.sh --all
> ```

Al terminar:

```bash
source ~/.zshrc
```

o simplemente cierra y abre una terminal nueva.

## Qué instala

| Categoría          | Herramientas                                                                                           |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| Base               | Homebrew, git (identidad por carpeta: personal/trabajo), gh (GitHub CLI), nvm + Node LTS + pnpm         |
| Shell              | zsh, zsh-completions, fzf-tab, zsh-autosuggestions, fzf, zsh-syntax-highlighting                       |
| Prompt             | Starship (git branch/status, node, duración de comandos, máquina actual)                              |
| CLI moderna        | zoxide (`z`/`cd`), bat (`cat`), eza (`ls`/`ll`/`lt`), lazygit (`gg` con `y` para copiar rama)          |
| Terminal           | Warp                                                                                                   |
| Multiplexor        | tmux + TPM (tmux-sensible, tmux-resurrect, tmux-continuum)                                             |
| Asistentes de IA   | Claude Code, Graphify (Knowledge Graph para IA)                                                        |
| Kubernetes         | kubectl, k9s, kubectx/kubens, stern                                                                    |
| Docker             | lazydocker (+ valida que Docker esté instalado y corriendo)                                            |
| Bases relacionales | Harlequin SQL IDE (con atajos Vim y perfiles guardados) + lazysql                                      |
| MongoDB            | lazymongo, vi-mongo, mongosh, conexiones nombradas (`mgo <nombre>`)                                    |
| Editor Terminal    | Neovim + LazyVim en `~/.config/nvim` (con extras JS/TS/Vue/Astro/Tailwind + dashboard personalizado)   |
| Editor GUI         | Cursor (configuración, atajos de teclado y 80+ extensiones migradas)                                    |
| Apps GUI (Casks)   | Warp, Lens, Docker Desktop, Android Studio, MongoDB Compass, Cursor, Google Chrome, Claude Desktop, Redis Insight |

Nada de esto borra o reemplaza tus datos — todo corre de forma idempotente y segura.

## Menú Interactivo de Módulos

Al ejecutar `./config.sh`, puedes activar o desactivar cualquiera de los 13 módulos:

1. **Git & GitHub CLI**: Identidades por carpeta (personal/trabajo) y `gh`.
2. **Node.js**: NVM + Node.js LTS + pnpm (vía Corepack).
3. **Zsh Plugins, Fuente & Starship Prompt**: Completions, fzf-tab, autosuggestions, JetBrainsMono Nerd Font.
4. **Herramientas CLI**: `zoxide` (`cd`), `bat` (`cat`), `eza` (`ls`/`ll`/`lt`), `speedtest`.
5. **Kubernetes Tools**: `kubectl`, `k9s`, `kubectx`, `kubens`, `stern`.
6. **Docker Tools**: `colima`, `docker`, `lazydocker`.
7. **Bases de Datos SQL**: Harlequin SQL IDE (perfil `vicidial prod`) y `lazysql`.
8. **MongoDB Tools**: `lazymongo`, `mongosh`, `vi-mongo`, alias `mgo`.
9. **Neovim & LazyVim**: Configuración completa en `~/.config/nvim`, LSPs, Mergetool 3-way.
10. **Tmux & TPM**: `~/.tmux.conf` + TPM + plugins de resurgimiento de sesión.
11. **Asistentes de IA CLI**: Claude Code, Graphify.
12. **Aplicaciones GUI (Casks)**: Warp, Lens, Docker Desktop, Android Studio, Compass, Cursor, Chrome, Claude Desktop, Redis Insight.
13. **Cursor Editor**: Sincronización automática de `settings.json`, `keybindings.json` e instalación de 80+ extensiones.

## Alias de CLI moderna

El script agrega estos alias a tu `.zshrc`:

| Alias | Reemplaza | Con                                                    |
| ----- | --------- | ------------------------------------------------------ |
| `cat` | `cat`     | `bat` (resaltado de sintaxis, números de línea)        |
| `ls`  | `ls`      | `eza --icons --group-directories-first`                |
| `ll`  | —         | `eza -la --icons --group-directories-first`            |
| `lt`  | —         | `eza --tree --icons --level=2`                         |
| `cd`  | `cd`      | `z` (zoxide — salto inteligente por frecuencia de uso) |
| `e`   | —         | `exit`                                                 |
| `vi`  | `vi`      | `nvim`                                                 |
| `gg`  | —         | `lazygit`                                              |
| `hq`  | —         | `harlequin-launcher` (selector de conexiones SQL)      |
| `lsql`| —         | `lazysql`                                              |
| `lm`  | —         | `lazymongo`                                            |

## Atajos y Configuración de Cursor

Cursor queda preparado automáticamente con tus ajustes de trabajo e identidades:

* **Sincronización de Ajustes**: `settings.json` y `keybindings.json` se escriben en `~/Library/Application Support/Cursor/User/`.
* **Atajos Destacados**:
  * `Shift + Cmd + G`: Abrir panel de Git / SCM.
  * `Shift + Cmd + A`: Toggle de barra de actividades.
  * `Shift + Cmd + S`: Save All (Guardar todo).
  * `Shift + Cmd + W`: Close All Editors (Cerrar editores).
  * `Shift + Cmd + C`: Fold / Collapse (Plegar código / colapsar carpetas).
  * `Alt + Espacio`: Disparar autocompletado e IntelliSense.
  * `Cmd + G`: Git Graph view.
  * `Shift + Cmd + J`: Maximizar/Restaurar panel de terminal.
* **Extensiones (80+ Plugins)**: Se instalan automáticamente plugins como Catppuccin, GitLens, Prettier, ESLint, Tailwind, Prisma, Volar, Redis for VS Code, ErrorLens, Material Icon Theme, Python, Docker, SQLTools, MongoDB, etc.

## Harlequin SQL IDE & Atajos Vim

Harlequin incluye el perfil **`vicidial prod`** (MySQL `172.16.1.23`) y atajos de navegación integrados:

* **Navegación entre Paneles (Footer visible en todas las pantallas)**:
  * **`F6 Catalog`**: Ir directo al árbol de tablas a la izquierda.
  * **`F2 Editor`**: Ir directo al editor SQL.
  * **`F5 Results`**: Ir directo a la tabla de resultados.
* **Comandos Vim en el Catálogo**:
  * **`j` / `k`**: Subir y bajar por la lista de tablas.
  * **`l`**: Desplegar / Expandir nodo.
  * **`h`**: Minimizar / Colapsar nodo.
* **Comandos Vim en Resultados**:
  * **`h` / `j` / `k` / `l`**: Moverse libremente por filas y celdas.
  * **`y`**: Copiar celda/selección actual.
  * **`Y`** (`Shift + y`): Seleccionar **todos** los registros de la consulta (luego presiona `y` para copiar todo).

## Lazygit

* Presionar **`y`** estando sobre cualquier rama (local o remota) copia el nombre de la rama directamente a tu portapapeles (`pbcopy`).
* Mergetool 3-way integrado con Neovim para resolución de conflictos (`vimdiff` / `git-conflict.nvim`).

## Conexiones nombradas de MongoDB (`mgo`)

Si trabajas con varias conexiones de MongoDB (distintos clientes/entornos), el script agrega una función `mgo` a tu `.zshrc` que lee conexiones nombradas desde `~/.config/mongo-connections.sh` y abre `mongosh` directo con la URI correspondiente.

```bash
mgo                # sin argumentos: lista las conexiones disponibles
mgo cliente-x       # abre mongosh conectado a esa URI
```

## tmux

El script instala tmux con una config lista para usar (`~/.tmux.conf`) y **TPM** (Tmux Plugin Manager):

- **Prefix:** `Ctrl-a` (en vez del default `Ctrl-b`)
- **Splits:** `prefix + |` (vertical), `prefix + -` (horizontal)
- **Navegación:** `prefix + h/j/k/l`
- **Plugins incluidos:** `tmux-sensible`, `tmux-resurrect`, `tmux-continuum`

Primera vez: abre `tmux` y presiona `prefix + I` (Ctrl-a, `I`).

## Primer uso de LazyVim

1. Abre `nvim` por primera vez para que **Mason** descargue los LSPs (TypeScript, Vue, Astro, Tailwind, ESLint, Prettier).
2. Revisa con `:Mason` que todos tengan el ícono verde.
3. Atajos principales: `<leader>ff` (buscar archivo), `<leader>fg` (buscar texto), `<leader>e` (explorador de archivos), `gd` (ir a definición).

## Repo en GitHub

Este repo (`terminal-stack`) está subido a tu cuenta de GitHub. Para clonarlo en un Mac nuevo:

```bash
gh repo clone terminal-stack ~/Development/dev
cd ~/Development/dev
chmod +x config.sh
./config.sh
```

## Notas

- El script es completamente **idempotente**: puedes volver a correrlo cuantas veces quieras y solo aplicará los módulos que selecciones en el menú.
