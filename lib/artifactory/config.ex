defmodule Artifactory.Config do
  def read(path \\ config_path) do
    case File.read(path) do
      {:ok, binary} ->
        case decode_term(binary) do
          {:ok, term} -> term
          {:error, _} -> decode_elixir(binary)
        end
      {:error, :enoent} ->
        config = Artifactory.EmbeddedConfig.config
        case config do
          [] -> print_missing_config(path)
          config ->
            print_building_config
            write(config, path)
            print_embedded_info(path, config)
            config
        end
      {:error, _} ->
        []
    end
  end

  def read_from_binary(binary) when is_binary(binary) do
    case decode_term(binary) do
      {:ok, term} -> term
      {:error, _} -> decode_elixir(binary)
    end
  end

  def update(config) do
    read()
    |> Keyword.merge(config)
    |> write()
  end

  def write(config, path \\ config_path) do
    string = encode_term(config)

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, string)
  end

  defp config_path do
    Path.join(artifactory_home(), "artifactory.config")
  end

  defp artifactory_home do
    if Process.whereis(Artifactory.State) do
      Artifactory.State.fetch!(:home)
    else
      Path.expand(Artifactory.default_home)
    end
  end

  defp encode_term(list) do
    list
    |> Enum.map(&[:io_lib.print(&1) | ".\n"])
    |> IO.iodata_to_binary
  end

  defp decode_term(string) do
    {:ok, pid} = StringIO.open(string)
    try do
      consult(pid, [])
    after
      StringIO.close(pid)
    end
  end

  defp consult(pid, acc) when is_pid(pid) do
    case :io.read(pid, '') do
      {:ok, term}      -> consult(pid, [term|acc])
      {:error, reason} -> {:error, reason}
      :eof             -> {:ok, Enum.reverse(acc)}
    end
  end

  defp decode_elixir(string) do
    {term, _binding} = Code.eval_string(string)
    term
  end

  defp print_missing_config(path) do
    Artifactory.Shell.error """
    Using the Artifactory plugin requires a configuration file,
    but one could not be found at: #{path}

    The version of `artifactory` you are using was not compiled
    with an embedded configuration so the required file could
    not be generated for you. Please download and install a new
    `artifactory` archive built for your Artifactory server,
    or create the configuration file yourself.

    Run `mix help artifactory.config` for more information.
    """
    []
  end

  defp print_building_config do
    msg = "Artifactory configuration missing, building from embedded data."
    Artifactory.Shell.info(msg)
  end

  defp print_embedded_info(path, config) do
    Artifactory.Shell.info "Generated Artifactory config at #{path}:"
    Enum.each config, fn {k,v} ->
      Artifactory.Shell.info "  #{k}: #{v}"
    end
    config
  end
end
