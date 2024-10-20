{ stdenv, lib, ... }:

let
  customPatchShebangs = { paths, excludeDirs ? [] }: 
    let
      excludeArgs = lib.concatStringsSep " " (map (dir: "-path ${dir} -prune -o") excludeDirs);
    in
    ''
      for path in ${lib.concatStringsSep " " paths}; do
        find $path \( ${excludeArgs} -false \) -o -type f -perm -0100 -print0 | while IFS= read -r -d '' f; do
          patchShebangs "$f"
        done
      done
    '';
in {
  inherit customPatchShebangs;
}
