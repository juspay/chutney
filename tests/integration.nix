{ lib, ... }:
{
  name = "chutney-integration-test";
  nodes.machine = {
    imports = [
      ../modules/nixos
    ];

    # TODO: Test firewall
    # TODO: Test storage backend

    # Override production-only settings
    services.atticd.settings = {
      api-endpoint = lib.mkForce "";
      allowed-hosts = lib.mkForce [ ];
    };

  };

  testScript = ''
    machine.start()

    machine.wait_for_unit("atticd.service")
    machine.wait_for_open_port(8080)

    attic_html = machine.succeed("curl http://127.0.0.1")
    assert ("Attic Binary Cache" in attic_html)
  '';
}
