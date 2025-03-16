{ pkgs, sources }:

let
  buildNpmPackage = pkgs.buildNpmPackage;
  buildPackages = pkgs.buildPackages;
  fetchFromGitHub = pkgs.fetchFromGitHub;
  lib = pkgs.lib;
  overrideCC = pkgs.overrideCC;
  stdenv = pkgs.stdenv;

  # build time dependencies
  apple-sdk_14 = pkgs.apple-sdk_14;
  autoconf = pkgs.autoconf;
  cargo = pkgs.cargo;
  ccache = pkgs.ccache;
  clang-tools = pkgs.clang-tools;
  clang = pkgs.clang;
  dump_syms = pkgs.dump_syms;
  git = pkgs.git;
  gnum4 = pkgs.gnum4;
  nodejs = pkgs.nodejs;
  patchelf = pkgs.patchelf;
  pkg-config = pkgs.pkg-config;
  pkgsBuildBuild = pkgs.pkgsBuildBuild;
  pkgsCross = pkgs.pkgsCross;
  python3 = pkgs.python3;
  runCommand = pkgs.runCommand;
  rsync = pkgs.rsync;
  rustc = pkgs.rustc;
  rustfmt = pkgs.rustfmt;
  rustPlatform = pkgs.rustPlatform;
  rustup = pkgs.rustup;
  rust-cbindgen = pkgs.rust-cbindgen;
  sccache = pkgs.sccache;
  unzip = pkgs.unzip;
  vips = pkgs.vips;
  wrapGAppsHook3 = pkgs.wrapGAppsHook3;
  writeShellScript = pkgs.writeShellScript;

  # runtime dependencies
  alsa-lib = pkgs.alsa-lib;
  atk = pkgs.atk;
  cairo = pkgs.cairo;
  cups = pkgs.cups;
  dbus = pkgs.dbus;
  dbus-glib = pkgs.dbus-glib;
  ffmpeg = pkgs.ffmpeg;
  fontconfig = pkgs.fontconfig;
  freetype = pkgs.freetype;
  gdk-pixbuf = pkgs.gdk-pixbuf;
  gtk3 = pkgs.gtk3;
  glib = pkgs.glib;
  icu73 = pkgs.icu73;
  jemalloc = pkgs.jemalloc;
  libGL = pkgs.libGL;
  libGLU = pkgs.libGLU;
  libdrm = pkgs.libdrm;
  libevent = pkgs.libevent;
  libffi = pkgs.libffi;
  libglvnd = pkgs.libglvnd;
  libjack2 = pkgs.libjack2;
  libjpeg = pkgs.libjpeg;
  libkrb5 = pkgs.libkrb5;
  libnotify = pkgs.libnotify;
  libpng = pkgs.libpng;
  libpulseaudio = pkgs.libpulseaudio;
  libstartup_notification = pkgs.libstartup_notification;
  libva = pkgs.libva;
  libvpx = pkgs.libvpx;
  libwebp = pkgs.libwebp;
  libxkbcommon = pkgs.libxkbcommon;
  libxml2 = pkgs.libxml2;
  makeWrapper = pkgs.makeWrapper;
  mesa = pkgs.mesa;
  nasm = pkgs.nasm;
  nspr = pkgs.nspr;
  nss_latest = pkgs.nss_latest;
  pango = pkgs.pango;
  pciutils = pkgs.pciutils;
  pipewire = pkgs.pipewire;
  sndio = pkgs.sndio;
  udev = pkgs.udev;
  xcb-util-cursor = pkgs.xcb-util-cursor;
  xorg = pkgs.xorg;
  zlib = pkgs.zlib;

  # Generic changes the compatibility mode of the final binaries.
  #
  # Enabling generic will make the browser compatible with more devices at the
  # cost of disabling hardware-specific optimizations. It is highly recommended
  # to leave `generic` disabled.
  generic = false;
  debugBuild = false;

  # On 32bit platforms, we disable adding "-g" for easier linking.
  enableDebugSymbols = !stdenv.hostPlatform.is32bit;
  alsaSupport = stdenv.hostPlatform.isLinux;
  ffmpegSupport = true;
  gssSupport = true;
  jackSupport = stdenv.hostPlatform.isLinux;
  jemallocSupport = !stdenv.hostPlatform.isMusl;
  pipewireSupport = waylandSupport && webrtcSupport;
  pulseaudioSupport = stdenv.hostPlatform.isLinux;
  sndioSupport = stdenv.hostPlatform.isLinux;
  waylandSupport = false;
  privacySupport = false;

  # WARNING: NEVER set any of the options below to `true` by default.
  # Set to `!privacySupport` or `false`.
  crashreporterSupport = !privacySupport && !stdenv.hostPlatform.isRiscV
    && !stdenv.hostPlatform.isMusl;
  geolocationSupport = !privacySupport;
  webrtcSupport = !privacySupport;

in let
  dollar = "$";

  surfer = buildNpmPackage {
    pname = "surfer";
    version = "1.10.5";

    src = fetchFromGitHub {
      owner = "zen-browser";
      repo = "surfer";
      rev = "fd234005ec6d18c563b10ef2d11305fa538873cd";
      hash = "sha256-AuwDeaBnZgtvepZg8becY/Q5nadSGA+tQSNn+sTl+kI=";
    };

    patches = [ ./surfer-dont-check-update.patch ];

    npmDepsHash = "sha256-ET+Lh5uBY6gtCjJcfPuSxai+uO0bCT7TJ2ZSBgCRgcQ=";
    makeCacheWritable = true;

    SHARP_IGNORE_GLOBAL_LIBVIPS = false;
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ vips ];
  };

  llvmPackages0 = rustc.llvmPackages;
  llvmPackagesBuildBuild0 = pkgsBuildBuild.rustc.llvmPackages;

  llvmPackages = llvmPackages0.override {
    bootBintoolsNoLibc = null;
    bootBintools = null;
  };
  llvmPackagesBuildBuild = llvmPackagesBuildBuild0.override {
    bootBintoolsNoLibc = null;
    bootBintools = null;
  };

  buildStdenv = overrideCC llvmPackages.stdenv
    (llvmPackages.stdenv.cc.override {
      bintools = buildPackages.rustc.llvmPackages.bintools;
    });

  inherit (pkgsCross) wasi32;

  wasiSysRoot = runCommand "wasi-sysroot" { } ''
    mkdir -p "$out"/lib/wasm32-wasi
    for lib in ${wasi32.llvmPackages.libcxx}/lib/*; do
      ln -s "$lib" "$out"/lib/wasm32-wasi
    done
  '';

  firefox-l10n = fetchFromGitHub {
    owner = "mozilla-l10n";
    repo = "firefox-l10n";
    rev = "9d639cd79d6b73081fadb3474dd7d73b89732e7b";
    hash = "sha256-+2JCaPp+c2BRM60xFCeY0pixIyo2a3rpTPaSt1kTfDw=";
  };

  firefoxDmg = pkgs.callPackage ./firefox-dmg.nix { inherit sources; };

  mountBuildZenBrowserEngineFolder =
    pkgs.writeShellScriptBin "mountBuildZenBrowserEngineFolder" ''
      set -e -o pipefail

      mountpoint=${dollar}1

      /usr/bin/hdiutil attach -quiet -noverify -mountpoint $mountpoint -readwrite -nobrowse -shadow .engine-shadow "${firefoxDmg}/firefox.dmg" 
    '';

  umountBuildZenBrowserEngineFolder =
    pkgs.writeShellScriptBin "umountBuildZenBrowserEngineFolder" ''
      set -ex -o pipefail

      mountpoint=${dollar}1

      /usr/bin/hdiutil detach -force $mountpoint
    '';

  isDarwin = stdenv.hostPlatform.isDarwin;
in buildStdenv.mkDerivation (finalAttrs: {
  pname = "zen-browser-unwrapped";
  version = "1.9.1b";

  src = fetchFromGitHub {
    owner = "zen-browser";
    repo = "desktop";
    rev = finalAttrs.version;
    hash = "sha256-fg6HD85iZOU2o1F27kWONIKtrArG1HqYAGk4qldYBp4=";
    fetchSubmodules = true;
  };

  SURFER_COMPAT = false;

  nativeBuildInputs = [
    autoconf
    cargo
    ccache
    git
    gnum4
    llvmPackagesBuildBuild.bintools
    llvmPackagesBuildBuild.clang
    llvmPackagesBuildBuild.clang-tools
    llvmPackagesBuildBuild.clangUseLLVM
    llvmPackagesBuildBuild.libclang  
    llvmPackagesBuildBuild.llvm
    makeWrapper
    nasm
    nodejs
    pkg-config
    python3
    rsync
    rust-cbindgen
    rustfmt
    rustPlatform.bindgenHook
    rustc
    rustup
    sccache
    surfer
    unzip
    wrapGAppsHook3
    xorg.xvfb
  ] ++ lib.optionals crashreporterSupport [ dump_syms patchelf ];
  
  buildInputs = [
    atk
    cairo
    cups
    dbus
    dbus-glib
    ffmpeg
    fontconfig
    freetype
    gdk-pixbuf
    gtk3
    glib
    icu73
    libGL
    libGLU
    libevent
    libffi
    libglvnd
    libjpeg
    libnotify
    libpng
    libstartup_notification
    libvpx
    libwebp
    libxml2
    mesa
    nspr
    nss_latest
    pango
    zlib
  ] ++ lib.optional (isDarwin) [ apple-sdk_14 ] ++ lib.optionals (!isDarwin) [
    libva
    pciutils
    pipewire
    udev
    xcb-util-cursor
    xorg.libX11
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXft
    xorg.libXi
    xorg.libXrender
    xorg.libXt
    xorg.libXtst
    xorg.pixman
    xorg.xorgproto
    xorg.libxcb
    xorg.libXrandr
    xorg.libXcomposite
    xorg.libXfixes
    xorg.libXScrnSaver
  ] ++ lib.optional (alsaSupport && !isDarwin) alsa-lib
    ++ lib.optional (jackSupport && !isDarwin) libjack2
    ++ lib.optional (pulseaudioSupport && !isDarwin) libpulseaudio
    ++ lib.optional (sndioSupport && !isDarwin) sndio
    ++ lib.optional gssSupport libkrb5 ++ lib.optional jemallocSupport jemalloc
    ++ lib.optionals (waylandSupport && !isDarwin) [ libdrm libxkbcommon ];

  configureFlags = [
    "--disable-bootstrap"
    "--with-distribution-id=org.nixos"
    "--with-ccache=sccache"
    "--with-libclang-path=${llvmPackagesBuildBuild.libclang.lib}/lib"
    "--with-wasi-sysroot=${wasiSysRoot}"
    "--host=${buildStdenv.buildPlatform.config}"
    "--target=${buildStdenv.hostPlatform.config}"
    #(lib.enableFeature alsaSupport "alsa")
    (lib.enableFeature ffmpegSupport "ffmpeg")
    (lib.enableFeature geolocationSupport "necko-wifi")
    (lib.enableFeature gssSupport "negotiateauth")
    #(lib.enableFeature jackSupport "jack")
    (lib.enableFeature jemallocSupport "jemalloc")
    #(lib.enableFeature pulseaudioSupport "pulseaudio")
    #(lib.enableFeature sndioSupport "sndio")
    (lib.enableFeature webrtcSupport "webrtc")
    # --enable-release adds -ffunction-sections & LTO that require a big amount
    # of RAM, and the 32-bit memory space cannot handle that linking
    (lib.enableFeature (!debugBuild && !stdenv.hostPlatform.is32bit) "release")
    (lib.enableFeature enableDebugSymbols "debug-symbols")
  ] ++ lib.optional stdenv.hostPlatform.isAarch "--disable-wasm-avx";

  configureScript = writeShellScript "configureMozconfig"
    ((lib.optionalString stdenv.hostPlatform.isAarch ''
      set -ex -o pipefail
      echo "ac_add_options --with-libclang-path=/usr/lib64" >> ./configs/linux/mozconfig

      # linux mozconfig
      sed -i 's/x86-\(64\|64-v3\)/native/g' ./configs/linux/mozconfig
      sed -i 's/x86_64-pc-linux/aarch64-linux-gnu/g' ./configs/linux/mozconfig

      # eme/widevine must be disabled on arm64 (thx google)
      sed -i '/--enable-eme/s/^/# /' ./configs/common/mozconfig
      sed -i 's/-msse3//g' ./configs/linux/mozconfig
      sed -i 's/-mssse3//g' ./configs/linux/mozconfig
      sed -i 's/-msse4.1//g' ./configs/linux/mozconfig
      sed -i 's/-msse4.2//g' ./configs/linux/mozconfig
      sed -i 's/-mavx2//g' ./configs/linux/mozconfig
      sed -i 's/-mavx//g' ./configs/linux/mozconfig
      sed -i 's/-mfma//g' ./configs/linux/mozconfig
      sed -i 's/-maes//g' ./configs/linux/mozconfig
      sed -i 's/-mpopcnt//g' ./configs/linux/mozconfig
      sed -i 's/-mpclmul//g' ./configs/linux/mozconfig
      sed -i 's/+avx2//g' ./configs/linux/mozconfig
      sed -i 's/+sse4.1//g' ./configs/linux/mozconfig

    '') + ''
      set -ex -o pipefail
      for flag in $@; do
        echo "ac_add_options $flag" >> mozconfig
      done
    '');

  dontFixLibtool = true;

  # To the person reading this wondering what is going on here, this is what
  # happens when a build process relies on Git. Normally you would use `fetchgit`
  # with `leaveDotGit = true`, however that leads to reproducibility issues, so
  # instead we create our own Git repo with a single commit.
  #
  # `surfer` (the build tool made for zen-browser) uses git to read the latest
  # HEAD commit, `git apply`, and likely a few other operations.
  preConfigure = ''
    export HOME="$TMPDIR"
    git config --global user.email "nixbld@localhost"
    git config --global user.name "nixbld"
    git init
    git add --all
    git commit -m 'nixpkgs'

    export LLVM_PROFDATA=llvm-profdata
    export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system
    export WASM_CC=${wasi32.stdenv.cc}/bin/${wasi32.stdenv.cc.targetPrefix}cc
    export WASM_CXX=${wasi32.stdenv.cc}/bin/${wasi32.stdenv.cc.targetPrefix}c++
    export LLVM_CXXFLAGS="-I${llvmPackagesBuildBuild.libclang.dev}/include $LLVM_CXXFLAGS"

    export AS="${llvmPackagesBuildBuild.clang}/bin/clang -isysroot ${apple-sdk_14}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -mmacosx-version-min=11.0"

    # export ZEN_RELEASE=1
    export M4=${gnum4}/bin/m4

    export PATH=$PATH:/usr/bin

    surfer ci --brand release --display-version ${finalAttrs.version}

    ${mountBuildZenBrowserEngineFolder}/bin/mountBuildZenBrowserEngineFolder $HOME/source/engine
    mkdir -p tests
    surfer download
    surfer import

    excludeDirs="./engine/.TemporaryItems"
    patchShebangs engine/mach engine/build engine/tools
  '';

  preBuild = ''
    cp -r ${firefox-l10n} l10n/firefox-l10n

    for lang in $(cat ./l10n/supported-languages); do
      rsync -av --progress l10n/firefox-l10n/"$lang"/ l10n/"$lang" --exclude .git
    done

    python3 scripts/copy_language_pack.py en-US
    for lang in $(cat ./l10n/supported-languages); do
      python3 scripts/copy_language_pack.py "$lang"
    done

    Xvfb :2 -screen 0 1024x768x24 &
    export DISPLAY=:2
  '';

  buildPhase = ''
    runHook preBuild

    surfer --verbose build --verbose

    runHook postBuild
  '';

  postInstall = ''
    ${umountBuildZenBrowserEngineFolder}/bin/umountBuildZenBrowserEngineFolder $HOME/source/engine
  '';

  installPhase = ''
    runHook preInstall
  
    # Use the package target instead of the default install
    # surfer package --verbose
    ./engine/mach package -v

    rsync -av --progress ./engine/obj-aarch64-apple-darwin/dist/zen/Zen.app $out
  
    runHook postInstall
  '';

  meta = {
    mainProgram = "zen";
    description =
      "Firefox based browser with a focus on privacy and customization";
    homepage = "https://www.zen-browser.app/";
    license = lib.licenses.mpl20;
    maintainers = with lib.maintainers; [ matthewpi titaniumtown ];
    platforms = [ "aarch64-linux" "x86_64-linux" "aarch64-darwin" ];
  };

  enableParallelBuilding = true;
  requiredSystemFeatures = [ "big-parallel" ];

  passthru = {
    updateScript = ./update.sh;

    # These values are used by `wrapFirefox`.
    # ref; `pkgs/applications/networking/browsers/firefox/wrapper.nix'
    binaryName = finalAttrs.meta.mainProgram;
    inherit alsaSupport;
    inherit jackSupport;
    inherit pipewireSupport;
    inherit sndioSupport;
    inherit nspr;
    inherit ffmpegSupport;
    inherit gssSupport;
    inherit gtk3;
    inherit wasiSysRoot;
  };
})
