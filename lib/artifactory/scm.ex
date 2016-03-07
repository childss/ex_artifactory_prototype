defmodule Artifactory.SCM do
  @moduledoc false

  @behaviour Mix.SCM
  @packages_dir "packages"
  @fetch_timeout 120_000

  def fetchable? do
    true
  end

  def format(_opts) do
    "Artifactory package"
  end

  def format_lock(opts) do
    case opts[:lock] do
      {:artifactory, version, name} ->
        "#{version} (#{name})"
      _ ->
        nil
    end
  end

  def accepts_options(name, opts) do
    cond do
      opts[:in_artifactory] -> Keyword.put_new(opts, :artifactory, name)
      true -> nil
    end
  end

  def checked_out?(opts) do
    File.dir?(opts[:dest])
  end

  def lock_status(opts) do
    case opts[:lock] do
      {:artifactory, name, version} ->
        lock_status(opts[:dest], Atom.to_string(name), version)
      nil ->
        :mismatch
      _ ->
        :outdated
    end
  end

  defp lock_status(dest, name, version) do
    case File.read(Path.join(dest, ".artifactory")) do
      {:ok, file} ->
        case parse_manifest(file) do
          {^name, ^version} -> :ok
          _ -> :mismatch
        end
      {:error, _} ->
        :mismatch
    end
  end

  def equal?(opts1, opts2) do
    opts1[:artifactory] == opts2[:artifactory]
  end

  def managers(opts) do
    Hex.PackageRegistry.open!(Hex.Registry.ETS)

    case opts[:lock] do
      {:artifactory, name, version} ->
        name        = Atom.to_string(name)
        build_tools = Hex.PackageRegistry.get_build_tools(name, version) || []
        Enum.map(build_tools, &String.to_atom/1)
      _ ->
        []
    end
  after
    Hex.PackageRegistry.pdict_clean
  end

  def checkout(opts) do
    Hex.PackageRegistry.open!(Artifactory.Registry.ETS)

    {:artifactory, _name, version} = opts[:lock]
    name     = opts[:artifactory]
    dest     = opts[:dest]
    filename = "#{name}-#{version}.tar"
    path     = cache_path(filename)
    url      = Artifactory.API.package_url(filename)

    Artifactory.Shell.info "Checking package (#{url})"

    case Hex.Parallel.await(:artifactory_fetcher, {name, version}, @fetch_timeout) do
      {:ok, :cached} ->
        Artifactory.Shell.info "Using locally cached package"
      {:ok, :offline} ->
        Artifactory.Shell.info "[OFFLINE] Using locally cached package"
      {:ok, :new} ->
        Artifactory.Shell.info "Fetched package"
      {:error, reason} ->
        Artifactory.Shell.error(reason)
        unless File.exists?(path) do
          Mix.raise "Package fetch failed and no cached copy available"
        end
        Artifactory.Shell.info "Check failed. Using locally cached package"
    end

    File.rm_rf!(dest)
    Hex.Tar.unpack(path, dest, {name, version})
    manifest = encode_manifest(name, version)
    File.write!(Path.join(dest, ".artifactory"), manifest)

    opts[:lock]
  after
    Hex.PackageRegistry.pdict_clean
  end

  def update(opts) do
    checkout(opts)
  end

  defp parse_manifest(file) do
    file
    |> String.strip
    |> String.split(",")
    |> List.to_tuple
  end

  defp encode_manifest(name, version) do
    "#{name},#{version}"
  end

  defp cache_path(name) do
    Path.join([Artifactory.State.fetch!(:home), @packages_dir, name])
  end

  def prefetch(lock) do
    fetch = fetch_from_lock(lock)

    Enum.each(fetch, fn package ->
      Hex.Parallel.run(:artifactory_fetcher, package, fn ->
        Artifactory.Cache.fetch_and_cache(package)
        {:ok, :new}
      end)
    end)
  end

  defp fetch_from_lock(lock) do
    deps_path = Mix.Project.deps_path

    Enum.flat_map(lock, fn
      {_app, {:artifactory, name, version}} ->
        if fetch?(name, version, deps_path) do
          [{name, version}]
        else
          []
        end
      _ ->
        []
    end)
  end

  defp fetch?(name, version, deps_path) do
    dest = Path.join(deps_path, "#{name}")

    case File.read(Path.join(dest, ".artifactory")) do
      {:ok, contents} ->
        {name, version} != parse_manifest(contents)
      {:error, _} ->
        true
    end
  end
end
