using BuildExecutable
using Base.Test
script = joinpath(dirname(@__FILE__), "test.jl")
@test isfile(script)
targetdir = joinpath(dirname(@__FILE__),"test_dir")
mkdir(targetdir)
exename="test"
try
    build_executable(exename, script, targetdir, "native"; force=false)
    run(`$(joinpath(targetdir,exename*".exe"))`)
finally
    rm(targetdir, recursive=true)
end
