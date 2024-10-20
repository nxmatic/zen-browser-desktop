{ pkgs, lib, stdenv, fetchFromGitHub,
  cacert,
  coreutils,
  git,
  gnutar,
  python311, nodejs, pnpm,
  pkg-config, 
  rsync,
  sysctl,
  writeShellScript,
  sources, ... }:

let
  dollar = "$";
  firefoxDmg = pkgs.callPackage ./firefox-dmg.nix { inherit sources; };
in stdenv.mkDerivation rec {
  pname = "zen-browser";
  version = sources.zen-browser-sources.version;

  src = sources.zen-browser-sources.src;

  firefox-l10n = sources.firefox-l10n.src;

  firefoxVersion = sources.firefox-sources.version;

  nativeBuildInputs = [
    cacert
    git
    python311
    nodejs
    pnpm
    pkg-config
    rsync
    sysctl
  ];

  patches = [
    ./patches/scripts.patch
  ];

  mountEngineScript = writeShellScript "mountEngine" ''
    mkdir -p engine
    hdiutil attach "${firefoxDmg}/firefox.dmg" -quiet -noverify -mountpoint engine -readwrite -nobrowse -shadow .engine-shadow
  '';

  preConfigure = ''
    export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    export HOME=$TMPDIR

    mkdir -p .mozbuild/local/bin
    ln -s /usr/bin/hdiutil .mozbuild/local/bin
    ln -s /usr/bin/iconutil .mozbuild/local/bin
    ln -s /usr/bin/pip .mozbuild/local/bin
    ln -s /usr/bin/sips .mozbuild/local/bin
    ln -s /usr/bin/xcrun .mozbuild/local/bin
    ln -s ${pkgs.gnutar}/bin/tar .mozbuild/local/bin/gtar

    set -ax
    PATH=$(echo "$PATH" | tr ':' '\n' | grep -v -e 'darwin-wrapper' -e 'clang-wrapper' -e 'cctools-binutils' | tr '\n' ':' | sed 's/:$//')
    PATH=$PATH:$PWD/.mozbuild/local/bin
    set +ax

    : Configure git as version control \( required by surfer \)
    git config --global user.email "nixbld@localhost"
    git config --global user.name "nixbld"

    git init
    git add --all
    git commit -m 'nixpkgs'
  '';

  postConfigure = ''
    patchShebangs engine/mach engine/build engine/tools
  '';

  configurePhase = ''
    runHook preConfigure

    ${mountEngineScript}

    pnpm install
    pnpm bootstrap
    pnpm surfer ci --brand alpha --display-version ${version}

    runHook postConfigure
  '';

  preBuild = ''
    for lang in $(cat ./l10n/supported-languages); do
      rsync -a "${firefox-l10n}/$lang"/ "l10n/$lang" --exclude .git
    done

    sh scripts/copy-language-pack.sh en-US
  '';

  buildPhase = ''
    runHook preBuild

    pushd engine
    ./mach build -v
    popd

    runHook postBuild
  '';

  installPhase = ''
    mkdir -p "$out/bin"
    cp -r dist/* "$out/"
    ln -s "$out/zen" "$out/bin/zen"
  '';

  meta = with lib; {
    description = "Firefox-based browser with a focus on privacy and customization";
    homepage = "https://www.zen-browser.app/";
    license = licenses.mpl20;
    platforms = platforms.darwin;
    maintainers = with maintainers; [ ]; # Add maintainers if applicable
  };

  passthru = {
    inherit firefoxDmg;
    inherit mountEngineScript;

    firefoxDmgPath = firefoxDmg.outPath;
  };
}
