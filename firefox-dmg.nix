{ stdenv, lib, coreutils, gnutar, darwin, sources }:

stdenv.mkDerivation {
  name = "firefox-${sources.firefox.version}-dmg";
  src = sources.firefox.src;

  nativeBuildInputs = [ 
    coreutils
    gnutar
    darwin.apple_sdk.frameworks.CoreServices
    darwin.sigtool
  ];

  configurePhase = ''
    export PATH="$PATH:/usr/bin"
  '';

  buildPhase = ''
    : Setup 
    mkdir -p $out
    DMGFILE=$out/firefox.dmg
    MOUNTPOINT=$(mktemp -d)
    
    : Creating DMG file...
    hdiutil create -size 128g -fs HFS+ -volname "Firefox" "$DMGFILE" || { echo "Failed to create DMG"; exit 1; }

    : Mounting DMG...
    hdiutil attach -mountpoint "$MOUNTPOINT" "$DMGFILE" || { echo "Failed to mount DMG"; exit 1; }

    : Extracting Firefox source to DMG...
    tar -xf "$src" --strip-components=1 -C "$MOUNTPOINT" || { echo "Failed to extract source"; exit 1; }

    : Unmounting DMG...
    hdiutil detach "$MOUNTPOINT" || { echo "Failed to unmount DMG"; exit 1; }

    : Compressing DMG...
    hdiutil convert "$DMGFILE" -format UDZO -o "$out/firefox-compressed.dmg" || { echo "Failed to compress DMG"; exit 1; }
    mv "$out/firefox-compressed.dmg" "$DMGFILE" || { echo "Failed to rename compressed DMG"; exit 1; }

    : DMG creation completed successfully
  '';

  installPhase = "true";
  dontUnpack = true;
  dontFixup = true;
}
