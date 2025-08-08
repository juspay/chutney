{
  perSystem = { inputs', pkgs, config, ... }: {
    devShells.default = pkgs.mkShell {
      inputsFrom = [
        config.terranix.terranixConfigurations.default.result.devShell
      ];
      packages = with pkgs; [
        just
        inputs'.agenix.packages.default
        fd
        fzf
      ];
    };
  };
}
