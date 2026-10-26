#!/usr/bin/env bash

# ==============================================================================
# Script de configuración de idioma, diccionarios, fuentes y parches para WPS
# ==============================================================================

set -u

# Códigos de color para terminal
CLR_RESET="\033[0m"
CLR_INFO="\033[1;34m"
CLR_OK="\033[1;32m"
CLR_WARN="\033[1;33m"
CLR_ERR="\033[1;31m"

msg_step() { echo -e "\n${CLR_INFO}==> $1${CLR_RESET}"; }
msg_ok()   { echo -e " ${CLR_OK}[OK]${CLR_RESET} $1"; }
msg_warn() { echo -e " ${CLR_WARN}[WARN]${CLR_RESET} $1"; }
msg_err()  { echo -e " ${CLR_ERR}[ERROR]${CLR_RESET} $1"; }

# ------------------------------------------------------------------------------
# 1. Validar entorno local de ejecución y carpetas fuente
# ------------------------------------------------------------------------------
msg_step "Paso 1: Verificando archivos fuente locales"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -d "dicts" ] && [ ! -d "mui" ]; then
    msg_err "No se encontraron las carpetas 'dicts' ni 'mui' en: $SCRIPT_DIR"
    exit 1
fi
msg_ok "Carpetas de recursos encontradas en: $SCRIPT_DIR"

# ------------------------------------------------------------------------------
# 2. Validar presencia de WPS Office y determinar el tipo de instalación
# ------------------------------------------------------------------------------
msg_step "Paso 2: Detectando instalación de WPS Office"

INSTALL_TYPE=""
USER_BASE_DIR="$HOME/.local/share/Kingsoft/office6"

# 1. Comprobar si existe la carpeta de usuario (~/.local/share/Kingsoft/office6)
if [ -d "$USER_BASE_DIR" ]; then
    INSTALL_TYPE="user_local"
    msg_ok "Instalación de usuario detectada en: $USER_BASE_DIR"

# 2. Comprobar binarios en el PATH (wps, wpp, et, wpspdf)
elif command -v wps >/dev/null 2>&1 || command -v wpp >/dev/null 2>&1 || command -v et >/dev/null 2>&1; then
    INSTALL_TYPE="native"
    msg_ok "Binario nativo detectado en el PATH del sistema."

# 3. Comprobar paquetes deb/dpkg del sistema
elif command -v dpkg >/dev/null 2>&1 && dpkg -l 2>/dev/null | grep -qE "wps-office|kingsoft-office"; then
    INSTALL_TYPE="native"
    msg_ok "Paquete WPS detectado vía dpkg."

# 4. Comprobar directorios de sistema habituales
elif [ -d "/opt/kingsoft/wps-office" ] || [ -d "/usr/lib/kingsoft/wps-office" ] || [ -d "/usr/share/kingsoft/wps-office" ]; then
    INSTALL_TYPE="native"
    msg_ok "Directorio nativo de sistema detectado."

# 5. Comprobar Flatpak
elif command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -qi "com.wps.Office"; then
    INSTALL_TYPE="flatpak"
    msg_ok "Instalación Flatpak detectada: com.wps.Office"
else
    msg_err "No se detectó ninguna instalación de WPS Office."
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Comprobar e instalar fuentes tipográficas de WPS (ttf-wps-fonts)
# ------------------------------------------------------------------------------
msg_step "Paso 3: Verificando fuentes tipográficas de WPS"

FONTS_INSTALLED=false

if [ -d "/usr/share/fonts/wps-office" ] || [ -d "$HOME/.local/share/fonts/wps-office" ] || [ -d "$HOME/.fonts/wps-office" ]; then
    FONTS_INSTALLED=true
elif command -v fc-list >/dev/null 2>&1 && fc-list : family | grep -qiE "Wingdings|MT Extra|Symbol"; then
    FONTS_INSTALLED=true
fi

if [ "$FONTS_INSTALLED" = true ]; then
    msg_ok "Las fuentes de WPS Office ya están instaladas en el sistema."
else
    msg_warn "Fuentes tipográficas no detectadas. Procediendo con la instalación..."
    
    DEB_FONT_FILE=$(find . -maxdepth 1 -name "ttf-wps-fonts*.deb" | head -n 1)

    if [ -n "$DEB_FONT_FILE" ] && command -v dpkg >/dev/null 2>&1; then
        echo " -> Paquete deb encontrado: $DEB_FONT_FILE. Instalando..."
        if [ "$EUID" -ne 0 ]; then
            sudo dpkg -i "$DEB_FONT_FILE" || sudo apt install -f -y
        else
            dpkg -i "$DEB_FONT_FILE" || apt install -f -y
        fi
        msg_ok "Paquete .deb de fuentes instalado correctamente."
    else
        echo " -> Instalando fuentes en ~/.local/share/fonts/wps-office..."
        USER_FONTS_DIR="$HOME/.local/share/fonts/wps-office"
        mkdir -p "$USER_FONTS_DIR"

        if command -v git >/dev/null 2>&1; then
            TEMP_FONTS_DIR="$(mktemp -d)"
            git clone --depth=1 https://github.com/iamdh4/ttf-wps-fonts.git "$TEMP_FONTS_DIR"
            cp -rf "$TEMP_FONTS_DIR"/*.ttf "$TEMP_FONTS_DIR"/*.TTF "$TEMP_FONTS_DIR"/*.otf "$USER_FONTS_DIR/" 2>/dev/null || true
            rm -rf "$TEMP_FONTS_DIR"
            msg_ok "Fuentes clonadas e instaladas en $USER_FONTS_DIR"
        else
            msg_warn "No se encontró paquete deb local ni 'git' instalado para descargar las fuentes."
        fi
    fi

    if command -v fc-cache >/dev/null 2>&1; then
        echo " -> Actualizando caché de fuentes con fc-cache..."
        fc-cache -f >/dev/null 2>&1
        msg_ok "Caché de fuentes actualizada."
    fi
fi

# ------------------------------------------------------------------------------
# 4. Determinar rutas de destino para MUI y Dicts
# ------------------------------------------------------------------------------
msg_step "Paso 4: Resolviendo rutas de destino"

TARGET_FLATPAK_DIR="$HOME/.var/app/com.wps.Office/data/Kingsoft/office6"
SELECTED_BASE_DIR=""

if [ "$INSTALL_TYPE" = "flatpak" ]; then
    SELECTED_BASE_DIR="$TARGET_FLATPAK_DIR"
else
    # Tanto para Deepin, GNOME o instalación nativa general:
    SELECTED_BASE_DIR="$USER_BASE_DIR"
fi

DEST_MUI="$SELECTED_BASE_DIR/mui"
DEST_DICTS="$SELECTED_BASE_DIR/dicts"

msg_ok "Directorio base seleccionado: $SELECTED_BASE_DIR"
mkdir -p "$DEST_MUI" "$DEST_DICTS"

# ------------------------------------------------------------------------------
# 5. Selector de paquetes de idioma y diccionarios
# ------------------------------------------------------------------------------
msg_step "Paso 5: Selección de paquetes de idioma a instalar"

echo "Opciones disponibles:"
echo "  1) Solo Español de México (es_MX)"
echo "  2) Solo Español de España (es_ES)"
echo "  3) Todas las variantes de Español (es_*)"
echo "  4) Instalar absolutamente TODOS los paquetes disponibles"
echo "  5) Especificar un código manual (ejemplo: pt_BR, fr_FR, de_DE)"
echo ""
read -r -p "Elige una opción [1-5] (Por defecto: 1): " OPT_CHOICE
OPT_CHOICE=${OPT_CHOICE:-1}

TARGET_LANGS=()

case "$OPT_CHOICE" in
    1)
        TARGET_LANGS=("es_MX")
        ;;
    2)
        TARGET_LANGS=("es_ES")
        ;;
    3)
        for dir in mui/es_* dicts/es_*; do
            if [ -d "$dir" ]; then
                lang_code="$(basename "$dir")"
                if [[ ! " ${TARGET_LANGS[*]:-} " =~ " ${lang_code} " ]]; then
                    TARGET_LANGS+=("$lang_code")
                fi
            fi
        done
        ;;
    4)
        TARGET_LANGS=("ALL")
        ;;
    5)
        read -r -p "Escribe el código del idioma tal como se llama la carpeta: " CUSTOM_LANG
        if [ -n "$CUSTOM_LANG" ]; then
            TARGET_LANGS=("$CUSTOM_LANG")
        else
            msg_warn "Entrada vacía. Se utilizará es_MX por defecto."
            TARGET_LANGS=("es_MX")
        fi
        ;;
    *)
        msg_warn "Opción no reconocida. Se instalará es_MX por defecto."
        TARGET_LANGS=("es_MX")
        ;;
esac

echo ""
echo " -> Iniciando copia de archivos..."

if [[ "${TARGET_LANGS[0]}" == "ALL" ]]; then
    if [ -d "mui" ]; then
        cp -rf mui/* "$DEST_MUI/"
        msg_ok "Todos los paquetes de interfaz (MUI) han sido copiados a $DEST_MUI."
    fi
    if [ -d "dicts" ]; then
        cp -rf dicts/* "$DEST_DICTS/"
        # Compatibilidad: si el sistema busca dentro de spellcheck, crear enlace simbólico interno
        mkdir -p "$DEST_DICTS/spellcheck"
        cp -rf dicts/* "$DEST_DICTS/spellcheck/" 2>/dev/null || true
        msg_ok "Todos los diccionarios han sido copiados a $DEST_DICTS."
    fi
else
    for LANG in "${TARGET_LANGS[@]}"; do
        echo " -> Instalando paquete [$LANG]..."
        COPIED=false

        if [ -d "mui/$LANG" ]; then
            mkdir -p "$DEST_MUI/$LANG"
            cp -rf "mui/$LANG"/* "$DEST_MUI/$LANG/"
            msg_ok "Interfaz (MUI) [$LANG] copiada."
            COPIED=true
        else
            msg_warn "No existe la carpeta mui/$LANG localmente."
        fi

        if [ -d "dicts/$LANG" ]; then
            mkdir -p "$DEST_DICTS/$LANG"
            cp -rf "dicts/$LANG"/* "$DEST_DICTS/$LANG/"
            # Asegura redundancia si alguna compilación interna pide dicts/spellcheck/LANG
            mkdir -p "$DEST_DICTS/spellcheck/$LANG"
            cp -rf "dicts/$LANG"/* "$DEST_DICTS/spellcheck/$LANG/" 2>/dev/null || true
            msg_ok "Diccionario [$LANG] copiado."
            COPIED=true
        else
            msg_warn "No existe la carpeta dicts/$LANG localmente."
        fi

        if [ "$COPIED" = false ]; then
            msg_err "El idioma '$LANG' no fue encontrado en ninguna de las carpetas locales."
        fi
    done
fi

# ------------------------------------------------------------------------------
# 6. Corrección de compatibilidad con exportación a PDF (libtiff)
# ------------------------------------------------------------------------------
msg_step "Paso 6: Verificando dependencia de librerías para PDF (libtiff)"

if [ "$INSTALL_TYPE" = "flatpak" ]; then
    msg_ok "Instalación Flatpak contiene sus propios runtimes; no se requiere enlace simbólico."
else
    TIFF_AVAILABLE=$(find /usr/lib /usr/lib64 /usr/lib/x86_64-linux-gnu -maxdepth 2 -name "libtiff.so.[0-9]*" 2>/dev/null | grep -E "libtiff\.so\.(6|7)" | head -n 1 || true)

    if [ -n "$TIFF_AVAILABLE" ]; then
        LIB_DIR="$(dirname "$TIFF_AVAILABLE")"
        TARGET_LINK="$LIB_DIR/libtiff.so.5"

        if [ -e "$TARGET_LINK" ]; then
            msg_ok "$TARGET_LINK ya existe."
        else
            echo " -> Creando enlace simbólico: $TARGET_LINK -> $TIFF_AVAILABLE"
            if [ "$EUID" -ne 0 ]; then
                sudo ln -s "$TIFF_AVAILABLE" "$TARGET_LINK"
            else
                ln -s "$TIFF_AVAILABLE" "$TARGET_LINK"
            fi
            msg_ok "Enlace para libtiff creado exitosamente."
        fi
    else
        msg_warn "No se encontró libtiff.so.6/7 en rutas comunes. Si tienes problemas al exportar PDF, instala el paquete de compatibilidad de tu distro."
    fi
fi

# ------------------------------------------------------------------------------
# 7. Finalización
# ------------------------------------------------------------------------------
msg_step "Resumen del proceso"
msg_ok "Proceso completado con éxito."
echo -e "Si WPS Office está abierto, ciérralo y vuelve a abrirlo."
echo -e "Para seleccionar el idioma en la interfaz:"
echo -e "  Abre WPS -> Clic en el icono de ajustes/engrane (esquina superior derecha) -> 'Switch Language' / 'Cambiar idioma'."