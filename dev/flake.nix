# The development shell, as its own flake so a flake using dirs-as-categories
# never inherits a nixpkgs input from it:  nix develop ./dev
{
    description = "Development shell for dirs-as-categories";

    inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    outputs = { nixpkgs, ... }: {
        devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system:
            let pkgs = nixpkgs.legacyPackages.${system}; in {
                default = pkgs.mkShell {
                    packages = with pkgs; [ just (python3.withPackages (ps: [ ps.jsonschema ])) statix deadnix actionlint nixd ];
                };
            });
    };
}
