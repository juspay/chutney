# chutney: nix cache server

Build the image to be used as an EC2 instance:

```sh
nix build .#nixosConfigurations.chutney.config.system.build.amazonImage
```

