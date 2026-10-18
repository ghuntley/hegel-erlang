defmodule Mix.Tasks.Compile.HegelNif do
  use Mix.Task.Compiler

  @impl true
  def run(_args) do
    package = Mix.Project.project_file() |> Path.dirname()
    root = Path.expand("../..", package)
    manifest = Path.join(root, "native/hegel_nif/Cargo.toml")
    output = Path.join(root, "native/hegel_nif/target/release/libhegel_nif.so")
    destination = Path.join(root, "priv/hegel_nif.so")

    build_destination =
      Mix.Project.build_path()
      |> Path.dirname()
      |> Path.join("hegel/priv/hegel_nif.so")

    lib_build_destination =
      Mix.Project.build_path()
      |> Path.join("lib/hegel/priv/hegel_nif.so")

    build_root = Mix.Project.build_path() |> Path.dirname() |> Path.dirname()

    output = prebuilt() || build(manifest, output)

    install_native!(output, destination)
    install_native!(output, build_destination)
    install_native!(output, lib_build_destination)

    for profile <- ~w(dev test prod) do
      profile_destination =
        Path.join(build_root, Path.join(["_build", profile, "lib/hegel/priv/hegel_nif.so"]))

      install_native!(output, profile_destination)
    end

    :ok
  end

  @doc false
  @spec install_native!(Path.t(), Path.t()) :: :ok
  def install_native!(source, destination) do
    File.mkdir_p!(Path.dirname(destination))
    suffix = "#{System.pid()}.#{System.unique_integer([:positive, :monotonic])}"
    temporary = destination <> ".install-" <> suffix

    # Never truncate the destination: another VM may have its ELF segments
    # mapped. Renaming a complete sibling file leaves that VM's inode intact.
    # Exclusive creation ensures concurrent installers cannot share staging.
    file = File.open!(temporary, [:write, :binary, :exclusive])

    try do
      :ok = File.close(file)
      File.cp!(source, temporary)
      File.rename!(temporary, destination)
    after
      File.rm(temporary)
    end
  end

  # A packager or sandboxed build (for example Nix, which cannot fetch crates)
  # supplies an engine built elsewhere through HEGEL_NIF_PATH, which the
  # runtime loader already honours; cargo is then not run.
  defp prebuilt do
    case System.get_env("HEGEL_NIF_PATH") do
      nil ->
        nil

      "" ->
        nil

      path ->
        library = if File.regular?(path), do: path, else: path <> ".so"

        unless File.regular?(library),
          do: Mix.raise("HEGEL_NIF_PATH does not name a library: #{path}")

        library
    end
  end

  defp build(manifest, output) do
    unless File.exists?(manifest), do: Mix.raise("Hegel native manifest is missing: #{manifest}")

    {result, status} =
      System.cmd("cargo", ["build", "--release", "--manifest-path", manifest],
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("Hegel native engine failed to build:\n#{result}")

    # cargo names the library .dylib on macOS; erlang:load_nif/2 still wants .so.
    dylib = Path.rootname(output) <> ".dylib"
    if File.exists?(dylib), do: install_native!(dylib, output)

    unless File.exists?(output), do: Mix.raise("Hegel native engine did not produce #{output}")
    output
  end
end

defmodule HegelEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :hegel_ex,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:hegel_nif] ++ Mix.compilers(),
      description: "Idiomatic Elixir facade for the Erlang Hegel SDK",
      package: [
        licenses: ["MIT"],
        links: %{
          "Hegel" => "https://hegel.dev",
          "GitHub" => "https://github.com/ghuntley/hegel-erlang"
        }
      ]
    ]
  end

  def application, do: [extra_applications: [:logger]]
  defp deps, do: [{:hegel, path: "../.."}]
end
