# c-mojo-bridge
A tool to generate Mojo bindings from C headers.

**Quick start** How to create and use a lib:

We will use the SDL3, with life.mojo as example:

- Create a fresh folder, switch to it, then:
- Download files c-mojo-bridge.py and c-mojo-make-sh
- Make sure you have SDL3 installed
- Create 'SDL3' link pointing to folder with SDL3 header files
- Study and run c-mojo-make.sh

**CLI Options for the c-mojo-bridge.py**

- "-l, --library",Required. The path to the .so or .dll library.
- "-m, --master",Process first-level includes from a master header.
- "-f, --functions",Headers for full function and type bindings.
- "-t, --types",Headers for types/enums/structs only.
- "-e, --exclude",List of filenames to skip during processing.
- "-o, --output",Output filename (defaults to stdout).
- "-b, --blacklist","Prefix patterns to ignore (default: G_, GLIB_)."

**License**
* Tool (c-mojo-bridge.py): AGPL-3.0
* Generated Output: MIT
