# c-mojo-bridge
A tool to generate Mojo bindings from C headers.

**Quick start: How to create and use a lib:**

We will use the SDL3, with life.mojo as example:

- Create a fresh folder, switch to it, then:
- Download 3 files: c-mojo-bridge.py, c-mojo-make-sh and life.mojo
- Make sure you have SDL3 installed
- Create 'SDL3' link pointing to folder with SDL3 header files
- Study and run c-mojo-make.sh

**CLI Options for the c-mojo-bridge.py:**
| Option | Required | Description |
| :--- | :---: | :--- |
| `-l, --library` | **Yes** | The path to the `.so` or `.dll` library (e.g., `libSDL3.so`). |
| `-m, --master` | No | Process first-level `#include` directives from a master header file. |
| `-f, --functions` | No | Headers for full function and type bindings. |
| `-t, --types` | No | Headers for types, enums, and structs only (no functions). |
| `-e, --exclude` | No | List of header filenames to skip during processing. |
| `-o, --output` | No | Output filename (defaults to printing to the console). |
| `-b, --blacklist` | No | Prefix patterns to ignore (default: `G_`, `GLIB_`). |


**License**

* **Tool (`c-mojo-bridge.py`)**: Licensed under **AGPL-3.0**. Any derivative work or network-based use must remain Open Source.
* **Generated Output**: Licensed under **MIT**. You are free to use the generated `.mojo` files in any project, including commercial ones.
