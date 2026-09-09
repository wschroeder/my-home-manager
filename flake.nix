{
  description = "Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    beads = {
      url = "github:gastownhall/beads/v1.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, beads, ... }:
    let
      system = "aarch64-darwin";  # For Apple Silicon
      # Use "x86_64-darwin" if you're on Intel Mac
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      homeConfigurations."schroederw" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ 
          ./home.nix
          {
            home = {
              username = "schroederw";
              homeDirectory = "/Users/schroederw";
              stateVersion = "24.05";
            };
          }
        ];
        extraSpecialArgs = {
          inherit pkgs;
          beads = beads.packages.${system}.default;
        };
      };
    };
}
