# paket-mode
Provides a major mode for using Paket on Emacs. Paket is a dependency manager for .NET and Mono projects akin to NuGet. More information on Paket can be found on the Paket website at [http://fsprojects.github.io/Paket/](http://fsprojects.github.io/Paket).

**Note:** This package is a standalone project and not related to the Paket project in any way.

## Features
- Syntax highlighting of paket.dependencies, paket.references and paket.lock files.
- Bootstrap paket by downloading and running paket.bootstrapper.exe.
- Run paket commands from within Emacs.
- Search NuGet for packages.

## Screenshots
(TODO)

## Installation
(TODO)

## Usage and default keybindings
| Command                 | Key     | Action                                                                   |
| ----------------------- | ------- | ------------------------------------------------------------------------ |
| paket-run               | C-c C-r | Run the paket.exe executable with a given command line.                  |
| paket-add               | C-c C-a | Add a package to paket.dependencies.                                     |
| paket-restore           | C-c C-o | Restore package by running paket restore.                                |
| paket-install           | C-c C-f | Run paket install to install relevant package into relevant projects.    |
| paket-nuget-search      | C-c C-s | Search NuGet for packages using a given search string.                   |
| paket-find-refs         | C-c C-w | Find which projects use a package by searching for the package at point. |
| paket-init              |         | Run paket init for a project to create the paket.dependencies files      |
| paket-bootstrap         |         | Download the paket bootstrapper and run it to get the latest paket.exe   |
| paket-edit-dependencies |         | Open paket.dependencies for editing.                                     |
| paket-edit-lock         |         | Open paket.lock for editing.                                             |
