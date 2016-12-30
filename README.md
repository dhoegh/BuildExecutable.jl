# BuildExecutable
[![Build Status](https://travis-ci.org/dhoegh/BuildExecutable.jl.svg?branch=master)](https://travis-ci.org/dhoegh/BuildExecutable.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/fr017d9u7y8w29k3?svg=true)](https://ci.appveyor.com/project/dhoegh/buildexecutable-jl)

Builds an executable that doesn't require any julia source code.
The user needs to provide a julia script that contains a function main(),
taking no argument, which will be run when executing the
produced executable. An executable can be produced by using the `build_executable` function
```julia
using BuildExecutable
build_executable(exename, script, targetdir, "native")
```

## Note on packages:
Even if the script contains using statements, exported functions
will not be available in main(). Full qualification of names is
required. It's suggested to replace using statements with import
statements to produce a consistent result between running main() in
the REPL and running the executable. 

If packages with binary dependencies is used the produced executable will not function properly.

## Note on portability
The executable produced by `build_executable` is known to be portable across Windows computers, and OS X, but not on Linux. To increase the portablity use an older `cpu_target` target as `"core2"` instead of `"native"`. 
