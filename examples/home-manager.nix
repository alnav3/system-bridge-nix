# Home Manager configuration
# Install System Bridge for individual users (alternative to system-wide service)

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    system-bridge-nix.url = "github:alnav3/system-bridge-nix";
  };

  outputs = { nixpkgs, home-manager, system-bridge-nix, ... }: {
    homeConfigurations.my-user = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      modules = [
        {
          # Install System Bridge to user profile
          home.packages = [
            system-bridge-nix.packages.x86_64-linux.default
          ];

          # Optional: User service for automatic startup
          systemd.user.services.system-bridge = {
            Unit = {
              Description = "System Bridge - User Service";
              After = [ "graphical-session.target" ];
            };

            Service = {
              Type = "simple";
              ExecStart = "${system-bridge-nix.packages.x86_64-linux.default}/bin/system-bridge backend";
              Restart = "always";
              RestartSec = 5;
            };

            Install = {
              WantedBy = [ "default.target" ];
            };
          };

          # Note: For server deployments, prefer the NixOS module:
          # services.system-bridge.enable = true;
        }
      ];
    };
  };
}
