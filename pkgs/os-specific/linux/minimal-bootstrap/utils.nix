{ lib
, buildPlatform
, callPackage
, kaem
, mescc-tools-extra
}:

let
  checkMeta = callPackage ../../../stdenv/generic/check-meta.nix { };
in
rec {
  fetchurl = import ../../../build-support/fetchurl/boot.nix {
    inherit (buildPlatform) system;
  };

  derivationWithMeta = attrs:
    let
      passthru = attrs.passthru or {};
      validity = checkMeta.assertValidity { inherit meta attrs; };
      meta = checkMeta.commonMeta { inherit validity attrs; };
      baseDrv = derivation ({
        inherit (buildPlatform) system;
        inherit (meta) name;
      } // (builtins.removeAttrs attrs [ "meta" "passthru" ]));
      passthru' = passthru // lib.optionalAttrs (passthru ? tests) {
        tests = lib.mapAttrs (_: f: f baseDrv) passthru.tests;
      };
    in
    lib.extendDerivation
      validity.handled
      ({ inherit meta; passthru = passthru'; } // passthru')
      baseDrv;

  writeTextFile =
    { name # the name of the derivation
    , text
    , executable ? false # run chmod +x ?
    , destination ? ""   # relative path appended to $out eg "/bin/foo"
    , allowSubstitutes ? false
    , preferLocalBuild ? true
    }:
    derivationWithMeta {
      inherit name text allowSubstitutes preferLocalBuild;
      passAsFile = [ "text" ];

      builder = "${kaem}/bin/kaem";
      args = [
        "--verbose"
        "--strict"
        "--file"
        (builtins.toFile "write-text-file.kaem" (''
          target=''${out}''${destination}
        '' + lib.optionalString (builtins.dirOf destination == ".") ''
          mkdir -p ''${out}''${destinationDir}
        '' + ''
          cp ''${textPath} ''${target}
        '' + lib.optionalString executable ''
          chmod 555 ''${target}
        ''))
      ];

      PATH = lib.makeBinPath [ mescc-tools-extra ];
      destinationDir = builtins.dirOf destination;
      inherit destination;
    };

  writeText = name: text: writeTextFile {inherit name text;};

}
