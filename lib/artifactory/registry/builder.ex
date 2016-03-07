defmodule Artifactory.Registry.Builder do
  def full_rebuild do
    registry = :ets.new(:artifactory_registry, [])
    :ets.insert(registry, {:"$$version$$", 4})
    update(registry)
  end

  def update(registry) do
    all_packages = Artifactory.API.Packages.get_index
    indexed = get_package_versions(registry)
    unindexed =
      all_packages
      |> Enum.reject(fn {package, version} ->
        version in Map.get(indexed, package, [])
      end)
    
    new_indexed =
      unindexed
      |> Enum.map(&package_metadata/1)
      |> insert(registry)

    indexed
    |> update_versions(new_indexed)
    |> insert(registry)

    registry
  end

  defp insert(data, registry) do
    :ets.insert(registry, data)
    data
  end

  defp update_versions(indexed_pacakges, new_packages) do
    Enum.map new_packages, fn {{name, version}, _} ->
      current_versions = Map.get(indexed_pacakges, name, [])
      {name, [[version | current_versions]]}
    end
  end

  defp package_metadata({name, version} = package) do
    requirements =
      package
      |> Artifactory.Cache.extract_metadata
      |> extract_requirements

    checksum = Artifactory.Cache.checksum(package)
    build_tools = ["mix"]
    {{name, version}, [requirements, checksum, build_tools]}
  end

  defp extract_requirements(data) do
    data
    |> Enum.into(%{})
    |> Map.get("requirements", [])
    |> Enum.map(fn {name, [{"app", app}, {"optional", optional}, {"requirement", req}]} ->
      [name, req, optional, app]
    end)
  end

  defp get_package_versions(registry) do
    registry
    |> Hex.Registry.ETS.all_packages
    |> Enum.map(&make_version_tuple(registry, &1))
    |> Map.new
  end

  defp make_version_tuple(registry, package) do
    {package, Hex.Registry.ETS.get_versions(registry, package)}
  end
end
