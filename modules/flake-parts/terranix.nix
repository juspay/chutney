{ inputs, ... }:
{
  imports = [
    inputs.terranix.flakeModule
  ];
  perSystem = { pkgs, lib, ... }: {
    nixpkgs = {
      config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "terraform"
      ];
    };
    terranix = {
      # Imported using `pkgs.mkShell.inputsFrom` in `devShells.default`
      exportDevShells = false;
      terranixConfigurations.default = {
        terraformWrapper.package = pkgs.terraform.withPlugins (p: [ p.aws ]);
        modules = [ ../../modules/terranix ];
        workdir = "tf-default-workdir";
      };
    };
  };
}
