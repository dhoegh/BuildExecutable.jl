using Compat
@static if is_windows()
    using WinRPM
    WinRPM.install("gcc", yes=true)
    WinRPM.install("winpthreads-devel", yes=true)
end

@static if is_linux()
    DEPS_PATH = dirname(@__FILE__)
    DOWNLOADS_PATH = joinpath(DEPS_PATH, "downloads")
    INSTALL_PATH = joinpath(DEPS_PATH, "usr", "local")
    BIN_PATH = joinpath(INSTALL_PATH, "bin")
    TAR_FILE = "patchelf-0.9.tar.gz"
    EXTRACTED_DIR = "patchelf-0.9"

    mkpath(DOWNLOADS_PATH)
    mkpath(INSTALL_PATH)

    download("https://nixos.org/releases/patchelf/patchelf-0.9/$TAR_FILE", joinpath(DOWNLOADS_PATH, TAR_FILE))

    cd(DOWNLOADS_PATH) do
        run(`tar -xf $TAR_FILE`)
    end

    cd(joinpath(DOWNLOADS_PATH, EXTRACTED_DIR)) do
        run(`./configure --prefix="$INSTALL_PATH"`)
        run(`make install`)
        @assert ispath(joinpath(INSTALL_PATH, "bin", "patchelf"))
    end
end
