{
  description = "System Bridge - Nix flake for building and running";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    system-bridge-src = {
      url = "github:timmo001/system-bridge";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, system-bridge-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        version = "5.0.0-dev";

        robotgo-src = pkgs.fetchFromGitHub {
          owner = "go-vgo";
          repo = "robotgo";
          rev = "v0.110.8";
          hash = "sha256-XBNJ6l9d08ahprq9HkHg/h68EBWyfLkRpU1K5cufvZs=";
        };

        web-client = pkgs.runCommand "system-bridge-web-client-dummy" {} ''
          mkdir -p $out
          cat > $out/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Bridge</title>
</head>
<body>
    <h1>System Bridge</h1>
    <p>System Bridge is running</p>
</body>
</html>
EOF
        '';

        system-bridge = pkgs.buildGoModule {
          pname = "system-bridge";
          inherit version;

          src = system-bridge-src;

          vendorHash = "sha256-UEZCeYX39Bl6qoT3C0QTums5SotznR5Lfl82yM/Dk00=";

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
            xorg.libX11
            xorg.libXtst
            xorg.libXinerama
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXi
            xorg.libXext
            xorg.libxcb
            libpng
            libjpeg
            zlib
            libGL
            libGLU
          ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            systemd
          ];

          doCheck = false;

          overrideModAttrs = _: {
            postBuild = ''
              if [ -d vendor/github.com/go-vgo/robotgo ]; then
                chmod -R +w vendor/github.com/go-vgo/robotgo
                for dir in base bitmap clipboard key mouse screen window; do
                  cp -r "${robotgo-src}/$dir" vendor/github.com/go-vgo/robotgo/ || true
                done
              fi
            '';
          };

          preBuild = ''
            mkdir -p web-client/out
            cp -r ${web-client}/* web-client/out/
          '';

          ldflags = [
            "-X github.com/timmo001/system-bridge/version.Version=${version}"
          ];

          meta = with pkgs.lib; {
            description = "A bridge for your systems - access system information and control via API/WebSocket";
            homepage = "https://github.com/timmo001/system-bridge";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.linux;
            mainProgram = "system-bridge";
          };
        };
      in
      {
        packages = {
          default = system-bridge;
          system-bridge = system-bridge;
          web-client = web-client;
        };

        apps.default = {
          type = "app";
          program = "${system-bridge}/bin/system-bridge";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            gopls
            gotools
            go-tools
            nodejs_22
            bun
            pkg-config
            xorg.libX11
            xorg.libXtst
            xorg.libXinerama
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXi
            xorg.libXext
            xorg.libxcb
            libpng
            libjpeg
            systemd
          ];

          shellHook = ''
            echo "System Bridge development environment"
            echo "Run 'make build' to build the application"
            echo "Run 'make run' to build and run"
          '';
        };

        nixosModules.default = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.services.system-bridge;
          in {
            options.services.system-bridge = {
              enable = mkEnableOption "System Bridge service";

              package = mkOption {
                type = types.package;
                default = self.packages.${pkgs.system}.default;
                description = "System Bridge package to use";
              };

              port = mkOption {
                type = types.port;
                default = 9170;
                description = "Port to run System Bridge on";
              };

              openFirewall = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to open the firewall for System Bridge";
              };

              user = mkOption {
                type = types.str;
                default = "system-bridge";
                description = "User to run System Bridge as";
              };

              group = mkOption {
                type = types.str;
                default = "system-bridge";
                description = "Group to run System Bridge as";
              };

              settings = mkOption {
                type = types.attrs;
                default = {};
                description = "System Bridge configuration";
                example = {
                  hostname = "my-server";
                  apiKey = "your-api-key";
                };
              };
            };

            config = mkIf cfg.enable {
              systemd.services.system-bridge = {
                description = "System Bridge - System information and control service";
                documentation = [ "https://github.com/timmo001/system-bridge" ];
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" ];
                wants = [ "network-online.target" ];

                serviceConfig = {
                  Type = "simple";
                  ExecStart = "${cfg.package}/bin/system-bridge backend";
                  Restart = "always";
                  RestartSec = 5;
                  User = cfg.user;
                  Group = cfg.group;

                  NoNewPrivileges = true;
                  PrivateTmp = true;
                  ProtectHome = true;
                  ProtectSystem = "strict";
                  ReadWritePaths = [ "/var/lib/system-bridge" ];

                  RuntimeDirectory = "system-bridge";
                  RuntimeDirectoryMode = "0755";
                  StateDirectory = "system-bridge";
                  StateDirectoryMode = "0755";

                  Environment = [
                    "SYSTEM_BRIDGE_PORT=${toString cfg.port}"
                  ] ++ lib.optionals (cfg.settings != {}) [
                    "SYSTEM_BRIDGE_CONFIG=${pkgs.writeText "system-bridge-config.json" (builtins.toJSON cfg.settings)}"
                  ];
                };

                unitConfig = {
                  StartLimitIntervalSec = 60;
                  StartLimitBurst = 3;
                };
              };

              users.users = mkIf (cfg.user == "system-bridge") {
                system-bridge = {
                  isSystemUser = true;
                  group = cfg.group;
                  description = "System Bridge service user";
                  home = "/var/lib/system-bridge";
                  createHome = true;
                };
              };

              users.groups = mkIf (cfg.group == "system-bridge") {
                system-bridge = {};
              };

              networking.firewall = mkIf cfg.openFirewall {
                allowedTCPPorts = [ cfg.port ];
                allowedUDPPorts = [ 1900 ];
              };

              environment.systemPackages = [ cfg.package ];
            };
          };
      }
    );
}
