# 🚀 Script de Configuración Multilingüe y Parches para WPS Office en Linux

Este script de Bash, denominado `install.sh`, automatiza la configuración avanzada, adición de paquetes de idioma, diccionarios ortográficos, instalación de fuentes complementarias y corrección de errores comunes para **WPS Office** en sistemas GNU/Linux (incluyendo Debian, Ubuntu, Deepin, Fedora, Arch y entornos GNOME).

A diferencia de métodos tradicionales intrusivos, este instalador **no elimina configuraciones existentes ni fuerza desinstalaciones**. Detecta dinámicamente el entorno de ejecución (instalaciones nativas en `.deb`/RPM, configuraciones locales de usuario en `~/.local/share/Kingsoft/office6` o empaquetadas en Flatpak) y aplica las configuraciones de manera modular y segura.

---

## ✨ Características Principales

* **Detección Dinámica y Compatibilidad Universal (Deepin, GNOME, Flatpak):**
  * Reconoce automáticamente perfiles locales de usuario (`~/.local/share/Kingsoft/office6`), binarios en `$PATH` (`wps`, `wpp`, `et`), paquetes del gestor del sistema (`dpkg`) o contenedores **Flatpak** (`com.wps.Office`).
  * No requiere permisos de superusuario para copiar idiomas y diccionarios al perfil del usuario.
* **Soporte Multilingüe con Selector Interactivo:**
  * Integra diccionarios de corrección ortográfica (`dicts/`) y traducciones completas de interfaz (`mui/`).
  * Estructura los diccionarios con compatibilidad dual (`dicts/LANG` y `dicts/spellcheck/LANG`) para garantizar reconocimiento en cualquier versión o compilación.
  * Menú interactivo para elegir instalar:
    1. Solo Español de México (`es_MX`) *(Por defecto)*
    2. Solo Español de España (`es_ES`)
    3. Todas las variantes de Español (`es_*`)
    4. El catálogo completo multilingüe disponible
    5. Un código regional manual (ej. `pt_BR`, `fr_FR`, `de_DE`)
* **Gestión Inteligente de Fuentes (`ttf-wps-fonts`):** Comprueba si las fuentes tipográficas requeridas para fórmulas y símbolos (como Wingdings, MT Extra o Symbol) están presentes. Si faltan, prioriza la instalación del paquete local `.deb` o realiza una clonación directa a nivel de usuario (`~/.local/share/fonts/wps-office`) actualizando la caché con `fc-cache`.
* **Corrección Automática de Exportación a PDF:** Detecta la ubicación de las librerías `libtiff` en el sistema (`libtiff.so.6` o `libtiff.so.7`) y genera el enlace simbólico hacia `libtiff.so.5`, solventando el problema conocido que impide abrir o exportar documentos en formato PDF.
* **Seguro y No Destructivo:** No borra datos del usuario ni elimina paquetes del sistema; permite aplicar las mejoras sobre una instalación existente sin requerir cierres forzados manuales.

---

## ⚙️ Estructura del Repositorio

Asegúrate de mantener la siguiente estructura de archivos y carpetas antes de ejecutar el script:

```text
├── install.sh                  # Script automatizado principal
├── README.md                   # Documentación del proyecto
├── ttf-wps-fonts_1.0_all.deb   # (Opcional) Paquete deb de fuentes complementarias
├── dicts/                      # Carpetas de corrección ortográfica (es_MX, es_ES, etc.)
└── mui/                        # Carpetas de interfaz traducida (es_MX, es_ES, etc.)
```

---

## 💻 Modo de Uso

### 1. Preparar WPS Office
Asegúrate de haber abierto WPS Office al menos una vez tras su instalación para que inicialice su estructura básica de configuración en tu perfil de usuario.

### 2. Ejecutar el instalador

1. Abre una terminal en la carpeta donde clonaste o descargaste este repositorio.
2. Otorga permisos de ejecución al script:
   ```bash
   chmod +x install.sh
   ```
3. Ejecuta el script:
   ```bash
   ./install.sh
   ```
   *(Si es necesario crear enlaces de librerías del sistema para libtiff o instalar fuentes globales, el script solicitará permisos de `sudo` de forma puntual).*

### 3. Seleccionar la variante de idioma

Durante la ejecución, el script mostrará el paso a paso detallado y presentará el selector interactivo:

```text
Opciones disponibles:
  1) Solo Español de México (es_MX)
  2) Solo Español de España (es_ES)
  3) Todas las variantes de Español (es_*)
  4) Instalar absolutamente TODOS los paquetes disponibles
  5) Especificar un código manual (ejemplo: pt_BR, fr_FR, de_DE)
```

Presiona el número correspondiente y pulsa `Enter` (por defecto se seleccionará la opción 1).

---

## 🌐 Cambiar el Idioma en WPS Office

Una vez finalizado el script, si WPS Office no muestra la interfaz en tu variante de español de forma automática:

1. Abre o reinicia **WPS Office**.
2. En la pantalla principal o dentro de cualquier documento (Writer, Spreadsheets, Presentation), haz clic en el icono de **Ajustes / Herramientas** (icono de engranaje en la barra superior derecha).
3. Selecciona la opción **"Switch Language"** o **"Cambiar idioma"**.
4. Escoge la variante instalada (por ejemplo, *Español (México)* o *Español (España)*) y pulsa **Aceptar**.
5. Reinicia la suite para aplicar la interfaz y el corrector ortográfico en español.

---

## 🛠️ Solución de Problemas Frecuentes

### Error al exportar o abrir PDF (`libtiff`)

Si tu distribución cuenta con una versión moderna de `libtiff`, el script intentará vincularla dinámicamente. De ser necesario realizar la corrección de forma manual:

```bash
# Para sistemas Debian, Ubuntu, Deepin y derivados (64 bits):
sudo ln -s /usr/lib/x86_64-linux-gnu/libtiff.so.6 /usr/lib/x86_64-linux-gnu/libtiff.so.5

# Para distribuciones basadas en Arch / Fedora / openSUSE:
sudo ln -s /usr/lib64/libtiff.so.6 /usr/lib64/libtiff.so.5
```