{
  programs.fastfetch = {
    enable = true;
    settings = {
      "$schema" = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json";
      logo.padding = {
        top = 5;
        right = 6;
      };
      modules = [
        "break"
        {
          type = "custom";
          format = "\u001b[90m┌──────────────────────Hardware──────────────────────┐";
        }
        {
          type = "host";
          key = " PC";
          keyColor = "green";
        }
        {
          type = "cpu";
          key = "│ ├";
          showPeCoreCount = true;
          keyColor = "green";
        }
        {
          type = "gpu";
          key = "│ ├";
          detectionMethod = "pci";
          keyColor = "green";
        }
        {
          type = "display";
          key = "│ ├󱄄";
          keyColor = "green";
        }
        {
          type = "disk";
          key = "│ ├󰋊";
          keyColor = "green";
        }
        {
          type = "memory";
          key = "│ ├";
          keyColor = "green";
        }
        {
          type = "swap";
          key = "└ └󰓡 ";
          keyColor = "green";
        }
        {
          type = "custom";
          format = "\u001b[90m└────────────────────────────────────────────────────┘";
        }
        "break"
        {
          type = "custom";
          format = "\u001b[90m┌──────────────────────Software──────────────────────┐";
        }
        {
          type = "os";
          key = "󰣇 OS";
          keyColor = "yellow";
        }
        {
          type = "kernel";
          key = "│ ├";
          keyColor = "yellow";
        }
        {
          type = "packages";
          key = "│ ├󰏖";
          keyColor = "yellow";
        }
        {
          type = "shell";
          key = "└ └";
          keyColor = "yellow";
        }
        "break"
        {
          type = "kernel";
          key = "│ ├";
          keyColor = "blue";
        }
        {
          type = "wm";
          key = "│ ├";
          keyColor = "blue";
        }
        {
          type = "de";
          key = " DE";
          keyColor = "blue";
        }
        {
          type = "terminal";
          key = "│ ├";
          keyColor = "blue";
        }
        {
          type = "packages";
          key = "│ ├󰏖";
          keyColor = "blue";
        }
        {
          type = "wmtheme";
          key = "│ ├󰉼";
          keyColor = "blue";
        }
        {
          type = "terminalfont";
          key = "└ └";
          keyColor = "blue";
        }
        {
          type = "custom";
          format = "\u001b[90m└────────────────────────────────────────────────────┘";
        }
        "break"
        {
          type = "custom";
          format = "\u001b[90m┌────────────────Age / Uptime / Update───────────────┐";
        }
        {
          type = "command";
          key = "󱦟 OS Age";
          keyColor = "magenta";
          text = "birth_install=$(stat -c %W /); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
        }
        {
          type = "uptime";
          key = "󱫐 Uptime";
          keyColor = "magenta";
        }
        {
          type = "custom";
          format = "\u001b[90m└────────────────────────────────────────────────────┘";
        }
        "break"
      ];
    };
  };
}
