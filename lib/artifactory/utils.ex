defmodule Artifactory.Utils do
  @filename "registry.ets"

  def ensure_registry!(opts \\ []) do
    update_result = update_registry(opts)

    if update_result == :error and not File.exists?(registry_path) do
      Mix.raise "Failed to fetch registry"
    end

    Hex.PackageRegistry.open!(Artifactory.Registry.ETS)

    # Show available newer versions
    if update_result in [{:ok, :new}, {:ok, :no_fetch}] do
      Hex.PackageRegistry.info_installs
    end
  end

  defp update_registry(opts) do
    cond do
      # Artifactory.State.fetch!(:offline?) ->
      #   {:ok, :offline}
      Artifactory.State.fetch!(:registry_updated) ->
        {:ok, :cached}
      true ->
        Artifactory.State.put(:registry_updated, true)

        closed? = Hex.PackageRegistry.close
        path    = registry_path
        path_gz = path <> ".gz"
        fetch?  = Keyword.get(opts, :fetch, true) and
          Keyword.get(opts, :update, true)

        try do
          if fetch? do
            api_opts =
              if Keyword.get(opts, :cache, true) do
                [etag: Hex.Utils.etag(path)]
              else
                []
              end

            case Artifactory.API.Registry.get(api_opts) do
              {200, body} ->
                Artifactory.Shell.info "Fetched new registry"
                File.mkdir_p!(Path.dirname(path))
                File.write!(path_gz, body)
                data = :zlib.gunzip(body)

                Artifactory.Shell.warn "Skipping writing registry file until Artifactory is fixed"
                # File.write!(path, data)
                {:ok, :new}
              {304, _} ->
                Artifactory.Shell.info "Using cached registry"
                {:ok, :new}
              {code, body} ->
                Artifactory.Shell.error "Registry update failed (#{code})"
                Hex.Utils.print_error_result(code, body)
                :error
            end
          else
            {:ok, :no_fetch}
          end
        after
          # Open registry if it was already open when update began
          if closed?, do: Hex.PackageRegistry.open!(Artifactory.Registry.ETS)
        end
    end
  end

  @week_seconds 7 * 24 * 60 * 60

  def week_fresh?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{mtime: mtime}} ->
        now   = :calendar.local_time |> :calendar.datetime_to_gregorian_seconds
        mtime = mtime                |> :calendar.datetime_to_gregorian_seconds

        now - mtime < @week_seconds
      {:error, _} ->
        false
    end
  end

  defp registry_path do
    Path.join(Artifactory.State.fetch!(:home), @filename)
  end
end
