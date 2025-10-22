# Server System Bridge configuration
# Enable service with network access for remote monitoring

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    system-bridge-nix.url = "github:alnav3/system-bridge-nix";
  };

  outputs = { nixpkgs, system-bridge-nix, ... }: {
    nixosConfigurations.my-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        system-bridge-nix.nixosModules.default
        {
          # Enable System Bridge service with network access
          services.system-bridge = {
            enable = true;
            openFirewall = true;  # Allow external access
            port = 9170;          # Default port
          };

          # Now accessible from other machines at:
          # http://YOUR_SERVER_IP:9170
          #
          # Service management:
          # sudo systemctl status system-bridge
          # sudo journalctl -u system-bridge -f
        }
      ];
    };
  };
}
