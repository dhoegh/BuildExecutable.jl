using BuildExecutable
using Base.Test

build_executable("test", joinpath(dirname(@__FILE__), "test.jl"), targetdir=joinpath(dirname(@__FILE__),"test_dir"), cpu_target="native"; force=false)
