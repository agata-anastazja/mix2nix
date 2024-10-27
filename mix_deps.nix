{ lib, beamPackages, overrides ? (x: y: {}) }:

let
  buildRebar3 = lib.makeOverridable beamPackages.buildRebar3;
  buildMix = lib.makeOverridable beamPackages.buildMix;
  buildErlangMk = lib.makeOverridable beamPackages.buildErlangMk;

  self = packages // (overrides self packages);

  packages = with beamPackages; with self; {
    dep_from_hexpm = buildMix rec {
      name = "dep_from_hexpm";
      version = "0.3.0";

      src = fetchHex {
        pkg = "dep_from_hexpm";
        version = "${version}";
        sha256 = "55b0c9db6c5666a4358e1d8e799f43f3fa091ef036dc0d09bf5ee9f091f07b6d";
      };

      beamDeps = [];
    };
  };
in self

