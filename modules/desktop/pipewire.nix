{ pkgs, ... }:
{
  # as per https://wiki.nixos.org/wiki/PipeWire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;

    extraLadspaPackages = with pkgs; [
      rnnoise-plugin.ladspa
      ladspaPlugins # Provides the sc4m compressor for the AGC stage
    ];

    extraConfig.pipewire = {
      "98-crackling-fix" = {
        "context.properties" = {
          "default.clock.quantum" = 800;
          "default.clock.min-quantum" = 512;
          "default.clock.max-quantum" = 1024;
          "default.clock.rate" = 48000;
          "default.clock.allowed-rates" = [ 48000 ];
        };
      };
      "99-input-denoising" = {
        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            flags = [ "nofail" ];
            args = {
              "node.description" = "Noise Canceling Source";
              "media.name" = "Noise Canceling Source";
              "filter.graph" = {
                nodes = [
                  {
                    # 1. High-pass filter: Cuts low-end fan rumble (<140Hz) before RNNoise processes it
                    type = "builtin";
                    label = "bq_highpass";
                    name = "hpf";
                    control = {
                      "Freq" = 140.0;
                    };
                  }
                  {
                    # 2. Splitter: Duplicates the signal for the dry/wet mixer
                    type = "builtin";
                    label = "copy";
                    name = "split";
                  }
                  {
                    # 3. RNNoise: The core AI denoiser
                    type = "ladspa";
                    name = "rnnoise";
                    plugin = "librnnoise_ladspa";
                    label = "noise_suppressor_mono";
                    control = {
                      "VAD Threshold (%)" = 95.0;
                      "VAD Grace Period (ms)" = 1200;
                      "Retroactive VAD Grace (ms)" = 100;
                    };
                  }
                  {
                    # 4. Mixer: Combines dry (Gain 1) and wet/filtered (Gain 2).
                    # Default is set to 100% filtered.
                    type = "builtin";
                    label = "mixer";
                    name = "mix";
                    control = {
                      "Gain 1" = 0.0;
                      "Gain 2" = 1.0;
                    };
                  }
                  {
                    # 5. AGC (SC4 Compressor): Evens out volume so near/far speech sounds consistent
                    type = "ladspa";
                    name = "agc";
                    plugin = "sc4m_1916";
                    label = "sc4m";
                    control = {
                      "RMS/peak" = 0.0;
                      "Attack time (ms)" = 15.0;
                      "Release time (ms)" = 500.0;
                      "Threshold level (dB)" = -26.0;
                      "Ratio (1:n)" = 8.0;
                      "Knee radius (dB)" = 10.0;
                      "Makeup gain (dB)" = 8.0;
                    };
                  }
                ];
                links = [
                  {
                    output = "hpf:Out";
                    input = "split:In";
                  }
                  {
                    output = "split:Out";
                    input = "rnnoise:Input";
                  }
                  {
                    output = "split:Out";
                    input = "mix:In 1";
                  }
                  {
                    output = "rnnoise:Output";
                    input = "mix:In 2";
                  }
                  {
                    output = "mix:Out";
                    input = "agc:Input";
                  }
                ];
                inputs = [ "hpf:In" ];
                outputs = [ "agc:Output" ];
              };
              "capture.props" = {
                "node.name" = "capture.rnnoise_source";
                "node.passive" = true;
                "audio.rate" = 48000;
              };
              "playback.props" = {
                "node.name" = "rnnoise_source";
                "media.class" = "Audio/Source";
                "audio.rate" = 48000;
              };
            };
          }
        ];
      };
    };
  };
}
