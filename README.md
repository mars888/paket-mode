# paket-mode
Provides a major mode for using Paket on Emacs. Paket is a dependency manager for .NET and Mono projects akin to NuGet. More information on Paket can be found on the Paket website at [http://fsprojects.github.io/Paket/](http://fsprojects.github.io/Paket).

**Note:** This package is a standalone project and not related to the Paket project in any way.

## Features
- Syntax highlighting of paket.dependencies, paket.references and paket.lock files.
- Bootstrap paket by downloading and running paket.bootstrapper.exe.
- Run paket commands from within Emacs.
- Search NuGet for packages.

## Screenshots
![Highlighting paket.dependencies](https://raw.github.com/mars888/paket-mode/master/screenshot1.png)
![Highlighting paket.lock](https://raw.github.com/mars888/paket-mode/master/screenshot2.png)

## Installation
(TODO)

## Configuration variables
The variables listed below are available for configuring paket-mode:

| Name                    | Description                                                                                    |
| ----------------------- | ---------------------------------------------------------------------------------------------- |
| paket-bootstrapper-url  | URL where the paket.bootstrapper.exe executable should be downloaded from.                     |
| paket-exe-directory     | Project relative directory where the Paket executables should be stored. Defaults to ".paket". |
| paket-bootstrapper-exe  | Executable name of the Paket bootstraper executable, defaults to "paket.bootstrapper.exe".     |
| paket-exe               | Executable name of the main Paket executable, defaults to "paket.exe".                         |

## Usage
**Note:** The Paket executable has to be run with respect to a certain project directory. Paket-mode currently
uses a simple heuristic to determine what this directory should be. To start with, paket-mode tries
to find a Visual Studio solution file in one of the parent directories of the file in the current buffer.
If a solution file (ending with .sln) is found, paket-mode uses the directory of the file as the project root.
If paket-mode can find no such file, the user is asked to enter the project directory manually. This directory
is currently not cached between executing commands.

### Commands and default keybindings
| Command                 | Key                | Action                                                                   |
| ----------------------- | ------------------ | ------------------------------------------------------------------------ |
| paket-run               | <kbd>C-c C-r</kbd> | Run the paket.exe executable with a given command line.                  |
| paket-add               | <kbd>C-c C-a</kbd> | Add a package to paket.dependencies.                                     |
| paket-restore           | <kbd>C-c C-o</kbd> | Restore package by running paket restore.                                |
| paket-install           | <kbd>C-c C-f</kbd> | Run paket install to install relevant package into relevant projects.    |
| paket-nuget-search      | <kbd>C-c C-s</kbd> | Search NuGet for packages using a given search string.                   |
| paket-find-refs         | <kbd>C-c C-w</kbd> | Find which projects use a package by searching for the package at point. |
| paket-init              |                    | Run paket init for a project to create the paket.dependencies files.     |
| paket-bootstrap         |                    | Download the paket bootstrapper and run it to get the latest paket.exe.  |
| paket-edit-dependencies |                    | Open paket.dependencies for editing.                                     |
| paket-edit-lock         |                    | Open paket.lock for editing.                                             |

### Adding Paket to a project
To initialize a new project for usage with Paket, run the `paket-bootstrap` command. When this command
is executed outside of an existing project directory, paket-mode asks for the root directory of the
project. After the root directory has been entered, paket-mode will try to download the paket.bootstrapper.exe
executable, the location of which is defined by `paket-bootstrapper-url`. After downloading the bootstrapper
paket-mode will run it to get the latest Paket executable.

To setup a basic Paket file after bootstrapping, run `paket-init`.

To add a package to the project, open the created paket.dependencies file and run `paket-add`.
