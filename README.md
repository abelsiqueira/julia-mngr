# Julia Installer

This tool enables the installation of
[julia](http://julialang.org/) for generic linux.
This installs both versions, enabling the selection of one or another.

## Usage

Simply

    julia-mngr <command>

The available commands are
  - **install**: Installs julia release and nightly versions
  - **select**: Selects which version is the default
  - **uninstall**: Uninstall all julia versions (not this manager)
  - **info**: Displays information about your installation

The first time you run `julia-mngr` it will create a configuration file.

## Installation

This will copy the script to `/usr/local/bin`:

    # make

And uninstalling:

    # make uninstall

## License

License under the GPLv3 (see [LICENSE.md](LICENSE.md)).

