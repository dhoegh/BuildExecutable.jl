using BuildExecutable
using Base.Test

build_executable("test", joinpath(dirname(@__FILE__), "test.jl"), joinpath(dirname(@__FILE__),"test_dir"), "native"; force=false)
