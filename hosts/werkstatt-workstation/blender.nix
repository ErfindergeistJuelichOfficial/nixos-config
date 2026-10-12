{ lib, pkgs, ... }:
let
  src = pkgs.fetchFromGitHub {
    owner = "ahujasid";
    repo = "mcp-for-blender";
    rev = "7a0373ec9199183cb460068c4f96aed9c579fb4f";
    hash = "sha256-bL8x9AMHbQKX0e3pLDrlzndY5xUD1ApKBPaRCTHn45Q=";
  };

  mcp-for-blender = pkgs.python3Packages.buildPythonApplication {
    pname = "mcp-for-blender";
    version = "2.1.9";
    pyproject = true;
    inherit src;

    build-system = with pkgs.python3Packages; [ setuptools ];
    dependencies = with pkgs.python3Packages; [ mcp httpx ];

    doCheck = false;
    pythonImportsCheck = [ "blender_mcp" ];

    meta = {
      description = "Blender-Steuerung via Model Context Protocol";
      homepage = "https://github.com/ahujasid/mcp-for-blender";
      license = lib.licenses.mit;
      mainProgram = "mcp-for-blender";
    };
  };

  blenderDir = ".config/blender/${lib.versions.majorMinor pkgs.blender.version}";

  addonFile = "${src}/addon.py";

  autoEnable = pkgs.writeText "blender_mcp_autoenable.py" ''
    import addon_utils
    import bpy

    MODULE = "blender_mcp"


    def _enable():
        if MODULE in bpy.context.preferences.addons:
            return None
        if MODULE not in [m.__name__ for m in addon_utils.modules()]:
            return None
        addon_utils.enable(MODULE, default_set=True, persistent=True)
        return None


    bpy.app.timers.register(_enable, first_interval=0.1)
  '';

  opencodeConfig = pkgs.writeText "opencode.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    mcp.blender = {
      type = "local";
      command = [ "${mcp-for-blender}/bin/mcp-for-blender" ];
      enabled = true;
    };
  });
in
{
  environment.systemPackages = [
    pkgs.blender
    pkgs.opencode
    mcp-for-blender
  ];

  environment.variables.OPENCODE_CONFIG = "${opencodeConfig}";

  systemd.user.tmpfiles.rules = [
    "d %h/${blenderDir}/scripts/addons 0755 - - - -"
    "L+ %h/${blenderDir}/scripts/addons/blender_mcp.py - - - - ${addonFile}"
    "d %h/${blenderDir}/scripts/startup 0755 - - - -"
    "L+ %h/${blenderDir}/scripts/startup/blender_mcp_autoenable.py - - - - ${autoEnable}"
  ];
}
