{ pkgs, ... }:

{
  packages = with pkgs; [ git rebar3 just pkg-config rustc cargo rustfmt ];

  languages.erlang = {
    enable = true;
    package = pkgs.beam29Packages.erlang;
  };
  languages.elixir = {
    enable = true;
    package = pkgs.beam29Packages.elixir_1_20;
  };
  languages.gleam = {
    enable = true;
    package = pkgs.gleam;
  };
  enterShell = ''
    echo "Hegel SDK development environment"
    erl -noshell -eval 'io:format("OTP ~s~n", [erlang:system_info(otp_release)]), halt().'
    elixir --version
    gleam --version
    rustc --version
  '';

  enterTest = ''
    just test
  '';
}
