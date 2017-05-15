module BuildExecutable
export build_executable
using Compat
@static if is_windows() using WinRPM end
# Builds an executable that doesn't require any julia source code.
# The user needs to provide a julia script that contains a function main(),
# taking no argument, which will be run when executing the
# produced executable.

# Note on packages:
# Even if the script contains using statements, exported functions
# will not be available in main(). Full qualification of names is
# required. It's suggested to replace using statements with import
# statements to produce a consistent result between running main() in
# the REPL and running the executable.

type Executable
    name
    filename
    buildfile
    targetfile
    libjulia
end

function Executable(exename, targetdir, debug)
    if debug
        exename = exename * "-debug"
    end
    filename = exename
    @static if is_windows()
        filename = filename * ".exe"
    end
    buildfile = abspath(joinpath(JULIA_HOME, filename))
    targetfile = targetdir == nothing ? buildfile : joinpath(targetdir, filename)
    libjulia = debug ? "-ljulia-debug" : "-ljulia"

    Executable(exename, filename, buildfile, targetfile, libjulia)
end

type SysFile
    buildpath
    buildfile
	inference
    inference0
end

function SysFile(exename, debug=false)
    buildpath = abspath(dirname(Libdl.dlpath(debug ? "libjulia-debug" : "libjulia")))
    buildfile = joinpath(buildpath, "lib"*exename)
    inference = joinpath(buildpath, "inference")
    inference0 = joinpath(buildpath, "inference0")
    SysFile(buildpath, buildfile, inference, inference0)
end

function build_executable(exename, script_file, targetdir=nothing, cpu_target="native";
                          force=false, debug=false)
    julia = abspath(joinpath(JULIA_HOME, debug ? "julia-debug" : "julia"))
    if !isfile(julia * (is_windows() ? ".exe" : ""))
        println("ERROR: file '$(julia)' not found.")
        return 1
    end
    build_sysimg = abspath(dirname(@__FILE__), "build_sysimg.jl")
	if !isfile(build_sysimg)
		build_sysimg = abspath(JULIA_HOME, "..", "..", "contrib", "build_sysimg.jl")
		if !isfile(build_sysimg)
			println("ERROR: build_sysimg.jl not found.")
			return 1
		end
	end

    if targetdir != nothing
        patchelf = find_patchelf()
        if patchelf == nothing && !(is_windows())
            println("ERROR: Using the 'targetdir' option requires the 'patchelf' utility. Please install it.")
            return 1
        end
    end

    if !isfile(script_file)
        println("ERROR: $(script_file) not found.")
        return 1
    end

    tmpdir = mktempdir()
    cfile = joinpath(tmpdir, "start_func.c")
    userimgjl = joinpath(tmpdir, "userimg.jl")
    script_file = abspath(script_file)

    if targetdir != nothing
        targetdir = abspath(targetdir)
        if !isdir(targetdir)
            println("ERROR: targetdir is not a directory.")
            return 1
        end
    end

    exe_file = Executable(exename, targetdir, debug)
    sys = SysFile(exename, debug)

    if !force
        for f in [cfile, userimgjl, "$(sys.buildfile).$(Libdl.dlext)", "$(sys.buildfile).ji", exe_file.buildfile]
            if isfile(f)
                println("ERROR: File '$(f)' already exists. Delete it or use --force.")
                return 1
            end
        end

        if targetdir != nothing && !isempty(readdir(targetdir))
            println("ERROR: targetdir is not an empty diectory. Delete all contained files or use --force.")
            return 1
        end
    end

    emit_cmain(cfile, exename, targetdir != nothing)
    emit_userimgjl(userimgjl, script_file)

    gcc = find_system_gcc()
    win_arg = ``
    # This argument is needed for the gcc, see issue #9973
    @static if is_windows()
	    win_arg = Sys.WORD_SIZE==32 ? `-D_WIN32_WINNT=0x0502 -march=pentium4` : `-D_WIN32_WINNT=0x0502`
    end
    incs = get_includes()
    ENV2 = deepcopy(ENV)
    @static if is_windows()
        if contains(gcc, "WinRPM")
            # This should not bee necessary, it is done due to WinRPM's gcc's
            # include paths is not correct see WinRPM.jl issue #38
            ENV2["PATH"] *= ";" * dirname(gcc)
            push!(incs, "-I"*abspath(joinpath(dirname(gcc),"..","include")))
        end
    end

    empty_cmd_str = ``
    println("running: $(julia) $(build_sysimg) $(sys.buildfile) $(cpu_target) $(userimgjl) --force" * (debug ? " --debug" : ""))
    cmd = setenv(`$(julia) $(build_sysimg) $(sys.buildfile) $(cpu_target) $(userimgjl) --force $(debug ? "--debug" : empty_cmd_str)`, ENV2)
    run(cmd)
    println()


    println("running: $gcc -g $win_arg $(join(incs, " ")) $(cfile) -o $(exe_file.buildfile) -Wl,-rpath,$(sys.buildpath) -L$(sys.buildpath) $(exe_file.libjulia) -l$(exename)")
    cmd = setenv(`$gcc -g $win_arg $(incs) $(cfile) -o $(exe_file.buildfile) -Wl,-rpath,$(sys.buildpath) -Wl,-rpath,$(sys.buildpath*"/julia") -L$(sys.buildpath) $(exe_file.libjulia) -l$(exename)`, ENV2)
    run(cmd)
    println()

    println("running: rm -rf $(tmpdir) $(sys.buildfile).o $(sys.inference).o $(sys.inference).ji $(sys.inference0).o $(sys.inference0).ji")
    map(f-> rm(f, recursive=true), [tmpdir, sys.buildfile*".o", sys.inference*".o", sys.inference*".ji", sys.inference0*".o", sys.inference0*".ji"])
    println()

    if targetdir != nothing
        # Move created files to target directory
        for file in [exe_file.buildfile, sys.buildfile * ".$(Libdl.dlext)", sys.buildfile * ".ji"]
            mv(file, joinpath(targetdir, basename(file)), remove_destination=force)
        end

        # Copy needed shared libraries to the target directory
        tmp = ".*\.$(Libdl.dlext).*"
        paths = [sys.buildpath]
        VERSION>v"0.5.0-dev+5537" && is_unix() && push!(paths, sys.buildpath*"/julia")
        for path in paths
            shlibs = filter(Regex(tmp),readdir(path))
            for shlib in shlibs
                cp(joinpath(path, shlib), joinpath(targetdir, shlib), remove_destination=force)
            end
        end

        @static if is_unix()
            # Fix rpath in executable and shared libraries
            # old implementation for fixing rpath in shared libraries
            #=
            shlibs = filter(Regex(tmp),readdir(targetdir))
            push!(shlibs, exe_file.filename)
            for shlib in shlibs
                rpath = readall(`$(patchelf) --print-rpath $(joinpath(targetdir, shlib))`)[1:end-1]
                # For debug purpose
                #println("shlib=$shlib\nrpath=$rpath")
                if Base.samefile(rpath, sys.buildpath)
                    run(`$(patchelf) --set-rpath $(targetdir) $(joinpath(targetdir, shlib))`)
                end
            end
            =#
            # New implementation
            shlib = exe_file.filename
            @static if is_linux()
                run(`$(patchelf) --set-rpath \$ORIGIN/ $(joinpath(targetdir, shlib))`)
            end
            @static if is_apple()
                # For debug purpose
                #println(readall(`otool -L $(joinpath(targetdir, shlib))`)[1:end-1])
                #println("sys.buildfile=",sys.buildfile)
                run(`$(patchelf) -rpath $(sys.buildpath) @executable_path/ $(joinpath(targetdir, shlib))`)
                run(`$(patchelf) -change $(sys.buildfile).$(Libdl.dlext) @executable_path/$(basename(sys.buildfile)).$(Libdl.dlext) $(joinpath(targetdir, shlib))`)
                #println(readall(`otool -L $(joinpath(targetdir, shlib))`)[1:end-1])
            end
        end
    end

    println("$(exe_file.targetfile) successfully created.")
    return 0
end

function find_patchelf()
    installed_version = joinpath(dirname(dirname(@__FILE__)), "deps", "usr", "local", "bin", "patchelf")
    @static if is_linux()
        for patchelf in [joinpath(JULIA_HOME, "patchelf"), "patchelf", installed_version]
            try
                if success(`$(patchelf) --version`)
                    return patchelf
                end
            end
        end
    end
    @static if is_apple() "install_name_tool" end
end

function get_includes()
    ret = []

    # binary install
    incpath = abspath(joinpath(JULIA_HOME, "..", "include", "julia"))
    push!(ret, "-I$(incpath)")

    # Git checkout
    julia_root = abspath(joinpath(JULIA_HOME, "..", ".."))
    push!(ret, "-I$(julia_root)src")
    push!(ret, "-I$(julia_root)src/support")
    push!(ret, "-I$(julia_root)usr/include")

    ret
end

function emit_cmain(cfile, exename, relocation)
    if relocation
        sysji = joinpath("lib"*exename)
    else
        sysji = joinpath(dirname(Libdl.dlpath("libjulia")), "lib"*exename)
    end
    sysji = escape_string(sysji)
    if VERSION > v"0.5.0-dev+4397"
        arr = "jl_alloc_vec_any"
        str = "jl_string_type"
    else
        arr = "jl_alloc_cell_1d"
        str = "jl_utf8_string_type"
    end
    ext = (VERSION < v"0.5" &&  is_windows()) ? "ji" : Libdl.dlext
    f = open(cfile, "w")
    write( f, """
        #include <julia.h>
        #include <stdlib.h>
        #include <stdio.h>
        #include <assert.h>
        #include <string.h>
        #if defined(_WIN32) || defined(_WIN64)
        #include <malloc.h>
        #endif

        void failed_warning(void) {
            if (jl_base_module == NULL) { // image not loaded!
                char *julia_home = getenv("JULIA_HOME");
                if (julia_home) {
                    fprintf(stderr,
                            "\\nJulia init failed, "
                            "a possible reason is you set an envrionment variable named 'JULIA_HOME', "
                            "please unset it and retry.\\n");
                }
            }
        }

        int main(int argc, char *argv[])
        {
            char sysji[] = "$(sysji).$ext";
            char *sysji_env = getenv("JULIA_SYSIMAGE");
            char mainfunc[] = "main()";

            assert(atexit(&failed_warning) == 0);

            jl_init_with_image(NULL, sysji_env == NULL ? sysji : sysji_env);

            // set Base.ARGS, not Core.ARGS
            if (jl_base_module != NULL) {
                jl_array_t *args = (jl_array_t*)jl_get_global(jl_base_module, jl_symbol("ARGS"));
                if (args == NULL) {
                    args = $arr(0);
                    jl_set_const(jl_base_module, jl_symbol("ARGS"), (jl_value_t*)args);
                }
                assert(jl_array_len(args) == 0);
                jl_array_grow_end(args, argc - 1);
                int i;
                for (i=1; i < argc; i++) {
                    jl_value_t *s = (jl_value_t*)jl_cstr_to_string(argv[i]);
                    jl_set_typeof(s,$str);
                    jl_arrayset(args, s, i - 1);
                }
            }

            // call main
            jl_eval_string(mainfunc);

            int ret = 0;
            if (jl_exception_occurred())
            {
                // jl_show(jl_stderr_obj(), jl_exception_occurred());
                jl_call2(jl_get_function(jl_base_module, "show"), jl_stderr_obj(), jl_exception_occurred());
                jl_printf(jl_stderr_stream(), "\\n");
                ret = 1;
            }

            jl_atexit_hook(ret);
            return ret;
        }
        """
    )
    close(f)
end

function emit_userimgjl(userimgjl, script_file)
    open(userimgjl, "w") do f
        write( f, "include(\"$(escape_string(script_file))\")")
    end
end

function find_system_gcc()
    # On Windows, check to see if WinRPM is installed, and if so, see if gcc is installed
    @static if is_windows()
        try
            winrpmgcc = joinpath(WinRPM.installdir,"usr","$(Sys.ARCH)-w64-mingw32",
                "sys-root","mingw","bin","gcc.exe")
            if success(`$winrpmgcc --version`)
                return winrpmgcc
            end
        end
    end

    # See if `gcc` exists
    @static if is_unix()
        try
            if success(`gcc -v`)
                return "gcc"
            end
        end
    end

    error( "GCC not found on system: " * (is_windows() ? "GCC can be installed via `Pkg.add(\"WinRPM\"); WinRPM.install(\"gcc\")`" : "" ))
end

end # module
