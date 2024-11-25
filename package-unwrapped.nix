{ buildNpmPackage, buildPackages, fetchFromGitHub, fetchurl, lib, overrideCC, pkgs, apple-sdk_15, sources, stdenv,
  # build time
  autoconf, cargo, git, gnum4, nodejs, pkg-config, pkgsBuildBuild, pkgsCross, python3, runCommand, rsync, rustc, rust-cbindgen, rustPlatform, unzip, makeWrapper,
  # runtime
  atk, cairo, cups, dbus, dbus-glib, ffmpeg, fontconfig, freetype, gdk-pixbuf, gtk3, glib, gnutar, icu73, jemalloc, libGL, libGLU, libevent, libffi, libglvnd, libjpeg, libkrb5, libnotify, libpng, libstartup_notification, libva, libvpx, libwebp, libxml2, mesa, nasm, nspr, nss_latest, pango, vips, zlib,
  # Optional dependencies
  alsa-lib, libjack2, libpulseaudio, sndio, libdrm, libxkbcommon, dump_syms, patchelf, pciutils, pipewire, udev, wrapGAppsHook3, writeShellScript, xcb-util-cursor, xorg,
  # Generic changes the compatibility mode of the final binaries.
  generic ? false,
  debugBuild ? false,
  enableDebugSymbols ? !stdenv.hostPlatform.is32bit,
  alsaSupport ? stdenv.hostPlatform.isLinux,
  ffmpegSupport ? true,
  gssSupport ? true,
  jackSupport ? stdenv.hostPlatform.isLinux,
  jemallocSupport ? !stdenv.hostPlatform.isMusl,
  pipewireSupport ? waylandSupport && webrtcSupport,
  pulseaudioSupport ? stdenv.hostPlatform.isLinux,
  sndioSupport ? stdenv.hostPlatform.isLinux,
  waylandSupport ? stdenv.hostPlatform.isLinux,
  privacySupport ? false,
  crashreporterSupport ? !privacySupport && !stdenv.hostPlatform.isRiscV && !stdenv.hostPlatform.isMusl,
  geolocationSupport ? !privacySupport,
  webrtcSupport ? !privacySupport,
}:

let
  
  isDarwin = stdenv.hostPlatform.isDarwin;

  gnutarWithSymlink = pkgs.stdenv.mkDerivation {
    pname = "gnutar-with-symlink";
    version = "1.0"; # Version is arbitrary since we are just creating a symlink

    # Skip the unpack phase
    phases = [ "installPhase" ];

    installPhase = ''
      mkdir -p $out/bin
      ln -s ${pkgs.gnutar}/bin/tar $out/bin/gtar
    '';
  };

  surfer = buildNpmPackage {
    pname = "surfer";
    version = "1.5.0";
    src = fetchFromGitHub {
      owner = "zen-browser";
      repo = "surfer";
      rev = "50af7094ede6e9f0910f010c531f8447876a6464";
      hash = "sha256-wmAWg6hoICNHfoXJifYFHmyFQS6H22u3GSuRW4alexw=";
    };
    patches = [ ./surfer-dont-check-update.patch ];
    npmDepsHash = "sha256-p0RVqn0Yfe0jxBcBa/hYj5g9XSVMFhnnZT+au+bMs18=";
    makeCacheWritable = true;
    SHARP_IGNORE_GLOBAL_LIBVIPS = false;
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ vips ];
  };

  llvmPackages0 = rustc.llvmPackages;
  llvmPackagesBuildBuild0 = pkgsBuildBuild.rustc.llvmPackages;
  llvmPackages = llvmPackages0.override { bootBintoolsNoLibc = null; bootBintools = null; };
  llvmPackagesBuildBuild = llvmPackagesBuildBuild0.override { bootBintoolsNoLibc = null; bootBintools = null; };

  buildStdenv = overrideCC llvmPackages.stdenv (
    llvmPackages.stdenv.cc.override {
      bintools = buildPackages.rustc.llvmPackages.bintools;
    }
  );

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

  mountBuildZenBrowserEngineFolder = pkgs.writeShellScriptBin "mountBuildZenBrowserEngineFolder" ''
    set -e -o pipefail

    /usr/bin/hdiutil attach -quiet -noverify -mountpoint engine -readwrite -nobrowse -shadow .engine-shadow "${firefoxDmg}/firefox.dmg" 
  '';

in buildStdenv.mkDerivation (finalAttrs: {
  pname = "zen-browser-unwrapped";
  version = sources.zen-browser.version;
  src = sources.zen-browser.src;

#  firefoxVersion = sources.firefox-sources.version;
#  firefoxSrc = sources.firefox-sources.src;

  SURFER_COMPAT = generic;

  nativeBuildInputs = [ autoconf cargo git gnum4 llvmPackagesBuildBuild.bintools makeWrapper nasm nodejs pkg-config python3 rsync rust-cbindgen rustPlatform.bindgenHook rustc surfer unzip ]
    ++ lib.optionals (isDarwin) [ apple-sdk_15 gnutarWithSymlink ]
    ++ lib.optionals (!isDarwin) [ wrapGAppsHook3 ]
    ++ lib.optionals (crashreporterSupport && !isDarwin) [ dump_syms patchelf ];

  buildInputs = [ atk cairo cups dbus dbus-glib ffmpeg fontconfig freetype gdk-pixbuf gtk3 glib icu73 libGL libGLU libevent libffi libglvnd libjpeg libnotify libpng libstartup_notification libvpx libwebp libxml2 mesa nspr nss_latest pango zlib ]
    ++ lib.optionals (!isDarwin) [
      libva pciutils pipewire udev xcb-util-cursor xorg.libX11 xorg.libXcursor xorg.libXdamage xorg.libXext xorg.libXft xorg.libXi xorg.libXrender xorg.libXt xorg.libXtst xorg.pixman xorg.xorgproto xorg.libxcb xorg.libXrandr xorg.libXcomposite xorg.libXfixes xorg.libXScrnSaver
    ]
    ++ lib.optional (alsaSupport && !isDarwin) alsa-lib
    ++ lib.optional (jackSupport && !isDarwin) libjack2
    ++ lib.optional (pulseaudioSupport && !isDarwin) libpulseaudio
    ++ lib.optional (sndioSupport && !isDarwin) sndio
    ++ lib.optional gssSupport libkrb5
    ++ lib.optional jemallocSupport jemalloc
    ++ lib.optionals (waylandSupport && !isDarwin) [ libdrm libxkbcommon ];

  configureFlags = [ "--disable-bootstrap" "--disable-updater" ]
    ++ lib.optionals (!isDarwin) [
      "--enable-default-toolkit=cairo-gtk3${lib.optionalString waylandSupport "-wayland"}"
      "--enable-system-pixman"
      "--with-distribution-id=org.nixos"
    ]
    ++ [
      "--with-libclang-path=${llvmPackagesBuildBuild.libclang.lib}/lib"
#     "--with-system-ffi"
#     "--with-system-icu"
#     "--with-system-jpeg"
#     "--with-system-libevent"
#     "--with-system-libvpx"
#     "--with-system-nspr"
#     "--with-system-nss"
#     "--with-system-png" # needs APNG support
#     "--with-system-webp"
#     "--with-system-zlib"
      "--with-wasi-sysroot=${wasiSysRoot}"
      "--host=${buildStdenv.buildPlatform.config}"
      "--target=${buildStdenv.hostPlatform.config}"
    ]
    ++ lib.optionals (!isDarwin) [
      (lib.enableFeature alsaSupport "alsa")
      (lib.enableFeature ffmpegSupport "ffmpeg")
      (lib.enableFeature geolocationSupport "necko-wifi")
      (lib.enableFeature gssSupport "negotiateauth")
      (lib.enableFeature jackSupport "jack")
      (lib.enableFeature jemallocSupport "jemalloc")
      (lib.enableFeature pulseaudioSupport "pulseaudio")
      (lib.enableFeature sndioSupport "sndio")
      (lib.enableFeature webrtcSupport "webrtc")
    ]
    ++ [
      (lib.enableFeature (!debugBuild && !stdenv.hostPlatform.is32bit) "release")
      (lib.enableFeature enableDebugSymbols "debug-symbols")
    ];

  dontFixLibtool = true;

  configureScript = writeShellScript "configureMozconfig" ''
    for flag in $@; do
      echo "ac_add_options $flag" >> mozconfig
    done
  '';

  preConfigure = ''
    set -e -o pipefail

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
    export ZEN_RELEASE=1
    export PATH=$PATH:/bin:/usr/bin

    : install firefox sources in engine
    ${mountBuildZenBrowserEngineFolder}/bin/mountBuildZenBrowserEngineFolder

    surfer ci --brand alpha --display-version ${finalAttrs.version}

    surfer download
    surfer import

    excludeDirs="./engine/.TemporaryItems"
   
    patchShebangs ./engine/mach ./engine/build ./engine/tools
  '';

  preBuild = ''
    set -e -o pipefail

    # cp -r ${firefox-l10n} l10n/firefox-l10n
    pwd
    for lang in $(cat ./l10n/supported-languages); do
      rsync -a "${firefox-l10n}/$lang"/ "l10n/$lang" --exclude .git
    done
    sh scripts/copy-language-pack.sh en-US
    for lang in $(cat ./l10n/supported-languages); do
      sh scripts/copy-language-pack.sh "$lang"
    done
  '' + lib.optionalString (!isDarwin) ''
    Xvfb :2 -screen 0 1024x768x24 &
    export DISPLAY=:2
  '';

  buildPhase = ''
    runHook preBuild
    surfer build -v
    runHook postBuild
  '';

  preInstall = ''
    cd engine/obj-*
  '';

  meta = {
    mainProgram = "zen";
    description = "Firefox based browser with a focus on privacy and customization";
    homepage = "https://www.zen-browser.app/";
    license = lib.licenses.mpl20;
    maintainers = with lib.maintainers; [ matthewpi titaniumtown ];
    platforms = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
  };

  enableParallelBuilding = true;
  requiredSystemFeatures = [ "big-parallel" ];

  passthru = {
    inherit alsaSupport;
    inherit jackSupport;
    inherit pipewireSupport;
    inherit sndioSupport;
#   inherit nspr;
    inherit ffmpegSupport;
    inherit gssSupport;
    inherit gtk3;
    inherit wasiSysRoot;

    binaryName = finalAttrs.meta.mainProgram;
  };
})
