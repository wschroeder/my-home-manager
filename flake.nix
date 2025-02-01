{
  description = "Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "aarch64-darwin";  # For Apple Silicon
      # Use "x86_64-darwin" if you're on Intel Mac
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {  # Using more standard final/prev names for clarity
            elixir_1_17 = prev.elixir_1_17.override {
              erlang = prev.erlang_27;
            };

            kubectl-pinned = prev.kubectl.overrideAttrs (old: {
              version = "1.25.2";
              src = prev.fetchFromGitHub {
                owner = "kubernetes";
                repo = "kubernetes";
                rev = "v1.25.2";
                sha256 = "sha256-L69lm0gfixVKILjyDfC6XXWUiEcPZJyl6hvG2QxJOQQ=";
              };
            });
          })
        ];
      };
    in {
      homeConfigurations."wschroeder" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ 
          ./home.nix
          {
            home = {
              username = "wschroeder";
              homeDirectory = "/Users/wschroeder";
              stateVersion = "24.05";
            };
          }
        ];
        extraSpecialArgs = { inherit pkgs; };
      };
    };
}
