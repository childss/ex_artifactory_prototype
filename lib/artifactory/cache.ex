defmodule Artifactory.Cache do
  @packages_dir "packages"

  def fetch_and_cache({name, version}) do
    name = format_file(name, version)
    path = cache_path(name)
    File.mkdir_p!(cache_path)
    Artifactory.API.Packages.fetch_package(name, path)
  end

  def is_cached?(name, version) do
    format_file(name, version)
    |> cache_path
    |> File.regular?
  end

  def checksum({name, version}) do
    path =
      format_file(name, version)
      |> cache_path
    case :erl_tar.extract(path, [:memory]) do
      {:ok, files} ->
        files = Enum.into(files, %{})
        tar_version = files['VERSION']
        meta = metadata(tar_version, files)
        blob = tar_version <> meta <> files['contents.tar.gz']

        :crypto.hash(:sha256, blob) |> Base.encode16
      :ok ->
        Mix.raise "Unpacking #{path} failed: tarball empty"
      {:error, reason} ->
        Mix.raise "Unpacking #{path} failed: " <> format_error(reason)
    end
  end

  defp metadata("3", files), do: files['metadata.config']

  def extract_metadata({name, version}) do
    ensure_cached(name, version)
    path =
      name
      |> format_file(version)
      |> cache_path

    case :erl_tar.extract(path, [:memory]) do
      {:ok, files} ->
        files
        |> Enum.into(%{})
        |> Map.get('metadata.config')
        |> Artifactory.Config.read_from_binary

      :ok ->
        Mix.raise "Unpacking #{path} failed: tarball empty"

      {:error, reason} ->
        Mix.raise "Unpacking #{path} failed: " <> format_error(reason)
    end
  end

  defp ensure_cached(name, version) do
    unless is_cached?(name, version), do: fetch_and_cache({name, version})
  end

  defp cache_path do
    Path.join(Artifactory.State.fetch!(:home), @packages_dir)
  end

  defp cache_path(name) do
    Path.join([Artifactory.State.fetch!(:home), @packages_dir, name])
  end

  defp format_file(name, version), do: "#{name}-#{version}.tar"

  defp format_error(reason) do
    :erl_tar.format_error(reason)
    |> List.to_string
  end
end
