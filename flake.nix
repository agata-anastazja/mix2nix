{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      erl = pkgs.beam.interpreters.erlang_27;
      erlangPackages = pkgs.beam.packagesWith erl;
      elixir = erlangPackages.elixir;
    in {
      packages = let
        version = "0.1.0";
        src = ./.;
        mixNixDeps = with pkgs; import ./mix_deps.nix {inherit lib beamPackages; };
        translatedPlatform =
          {
            aarch64-darwin = "macos-arm64";
            aarch64-linux = "linux-arm64";
            armv7l-linux = "linux-armv7";
            x86_64-darwin = "macos-x64";
            x86_64-linux = "linux-x64";
          }
          .${system};    
      in rec {
       default = erlangPackages.mixRelease {
          inherit version src mixNixDeps;
          pname = "ravensiris-web";

          preInstall = ''
            ${elixir}/bin/mix release --no-deps-check
          ''; 
        };

        # ignore this for now
        # nixosModule = {...};
      
      nixosModule = {
        config,
        lib,
        pkgs,
        ...
      }: let
        cfg = config.services.ravensiris-web;
        user = "ravensiris-web";
        dataDir = "/var/lib/ravensiris-web";
      in {
        options.services.ravensiris-web = {
          enable = lib.mkEnableOption "ravensiris-web";
          port = lib.mkOption {
            type = lib.types.port;
            default = 4000;
            description = "Port to listen on, 4000 by default";
          };
          secretKeyBaseFile = lib.mkOption {
            type = lib.types.path;
            description = "A file containing the Phoenix Secret Key Base. This should be secret, and not kept in the nix store";
          };
          databaseUrlFile = lib.mkOption {
            type = lib.types.path;
            description = "A file containing the URL to use to connect to the database";
          };
          host = lib.mkOption {
            type = lib.types.str;
            description = "The host to configure the router generation from";
          };
        };
        config = lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = cfg.secretKeyBaseFile != "";
              message = "A base key file is necessary";
            }
          ];

          users.users.${user} = {
            isSystemUser = true;
            group = user;
            home = dataDir;
            createHome = true;
          };
          users.groups.${user} = {};

          systemd.services = {
            ravensiris-web = {
              description = "Start up the homepage";
              wantedBy = ["multi-user.target"];
              script = ''
                # Elixir does not start up if `RELEASE_COOKIE` is not set,
                # even though we set `RELEASE_DISTRIBUTION=none` so the cookie should be unused.
                # Thus, make a random one, which should then be ignored.
                export RELEASE_COOKIE=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 20)

                # ${default}/bin/migrate
                # ${default}/bin/hello eval "Hello.hello"

              '';
              serviceConfig = {
                User = user;
                WorkingDirectory = "${dataDir}";
                Group = user;
          
              };

              environment = {
                # Disable Erlang's distributed features
                RELEASE_DISTRIBUTION = "none";
                # Additional safeguard, in case `RELEASE_DISTRIBUTION=none` ever
                # stops disabling the start of EPMD.
                ERL_EPMD_ADDRESS = "127.0.0.1";
                # Home is needed to connect to the node with iex
                HOME = "${dataDir}";
              };
            };
          };
        };
      };
};  
    });
}
