# Simple System Bridge configuration
# Just enable the service with minimal setup

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    system-bridge-nix.url = "github:alnav3/system-bridge-nix";
  };

  outputs = { nixpkgs, system-bridge-nix, ... }: {
    nixosConfigurations.my-system = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        system-bridge-nix.nixosModules.default
        {
          # Enable System Bridge service
          services.system-bridge.enable = true;

          # That's it! System Bridge will now:
          # - Start automatically at boot
          # - Run on http://localhost:9170
          # - Be manageable with: sudo systemctl status system-bridge
        }
      ];
    };
  };
}
