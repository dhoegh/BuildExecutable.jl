using BuildExecutable

if !isinteractive()
    if length(ARGS) < 2 || ("--help" in ARGS || "-h" in ARGS)
        println("Usage: build_executable.jl <exename> <script_file> [targetdir] <cpu_target> [--help]")
        println("   <exename>        is the filename of the resulting executable and the resulting sysimg")
        println("   <script_file>    is the path to a jl file containing a main() function.")
        println("   [targetdir]     (optional) is the path to a directory to put the executable and other")
        println("   <cpu_target>     is an LLVM cpu target to build the system image against")
        println("                    needed files into (default: julia directory structure)")
        println("   --debug          Using julia-debug instead of julia to build the executable")
        println("   --force          Set if you wish to overwrite existing files")
        println("   --help           Print out this help text and exit")
        println()
        println(" Example:")
        println("   julia build_executable.jl standalone_test hello_world.jl targetdir core2")
        return 0
    end

    debug_flag = "--debug" in ARGS
    filter!(x -> x != "--debug", ARGS)
    force_flag = "--force" in ARGS
    filter!(x -> x != "--force", ARGS)
    BuildExecutable.build_executable(ARGS..., force=force_flag, debug=debug_flag)
end
