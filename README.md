# BuildExecutable
[![Build Status](https://travis-ci.org/dhoegh/BuildExecutable.jl.svg?branch=master)](https://travis-ci.org/dhoegh/BuildExecutable.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/fr017d9u7y8w29k3?svg=true)](https://ci.appveyor.com/project/dhoegh/buildexecutable-jl)

Builds an executable that doesn't require any julia source code.
The user needs to provide a julia script that contains a function main(),
taking no argument, which will be run when executing the
produced executable.
```
build_executable(exename, script, targetdir, "native")
```
## Note on packages:
Even if the script contains using statements, exported functions
will not be available in main(). Full qualification of names is
required. It's suggested to replace using statements with import
statements to produce a consistent result between running main() in
the REPL and running the executable.
