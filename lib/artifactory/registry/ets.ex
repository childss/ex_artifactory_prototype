defmodule Artifactory.Registry.ETS do
  @behaviour Hex.PackageRegistry

  @name     __MODULE__
  @versions [3, 4]
  @filename "registry.ets"
  @timeout  60_000

  def start_link do
    Agent.start_link(fn -> nil end, name: @name)
  end

  def open(opts) do
    Agent.get_and_update(@name, fn
      nil ->
        path = opts[:registry_path] || path()

        case :ets.file2tab(String.to_char_list(path)) do
          {:ok, tid} ->
            # check_version(tid)
            {{:ok, tid}, tid}

          {:error, reason} ->
            {{:error, reason}, nil}
        end

      tid ->
        {{:ok, tid}, tid}
    end, @timeout)
  end

  def close do
    if tid = Agent.get(@name, & &1) do
      close(tid)
    else
      false
    end
  end

  def close(tid) do
    Agent.get_and_update(@name, fn
      nil ->
        {false, nil}
      agent_tid ->
        ^agent_tid = tid
        :ets.delete(tid)
        {true, nil}
    end, @timeout)
  end

  def path do
    Path.join(Artifactory.State.fetch!(:home), @filename)
  end

  def version(_tid) do
    {:error, :no_package}
  end

  def installs(tid) do
    case :ets.lookup(tid, :"$$installs2$$") do
      [{:"$$installs2$$", installs}] ->
        {:ok, installs}
      _ ->
        {:error, :no_package}
    end
  end

  def stat(_tid) do
    {:error, :no_package}
  end

  def search(tid, term) do
    fun = fn
      {package, list}, packages when is_binary(package) and is_list(list) ->
        if String.contains?(package, term) do
          [package|packages]
        else
          packages
        end
      _, packages ->
        packages
    end

    results =
      :ets.foldl(fun, [], tid)
      |> Enum.sort

    case results do
      [] -> {:error, :no_package}
      results -> {:ok, results}
    end
  end

  def all_packages(tid) do
    fun = fn
      {package, list}, packages when is_binary(package) and is_list(list) ->
        [package|packages]
      _, packages ->
        packages
    end

    results =
      :ets.foldl(fun, [], tid)
      |> Enum.sort

    case results do
      [] -> {:error, :no_package}
      results -> {:ok, results}
    end
  end

  def get_versions(tid, package) do
    case :ets.lookup(tid, package) do
      [] -> {:error, :no_package}
      [{^package, [versions|_]}] when is_list(versions) -> {:ok, versions}
    end
  end

  def get_deps(tid, package, version) do
    case :ets.lookup(tid, {package, version}) do
      [] ->
        {:error, :no_package}
      [{{^package, ^version}, [deps|_]}] when is_list(deps) ->
        {:ok, Enum.map(deps, fn
          [name, req, optional, app | _] -> {name, app, req, optional}
        end)}
    end
  end

  def get_checksum(tid, package, version) do
    case :ets.lookup(tid, {package, version}) do
      [] ->
        {:error, :no_package}
      [{{^package, ^version}, [_, checksum | _]}] when is_nil(checksum) or is_binary(checksum) ->
        {:ok, checksum}
    end
  end

  def get_build_tools(tid, package, version) do
    case :ets.lookup(tid, {package, version}) do
      [] ->
        {:error, :no_package}
      [{{^package, ^version}, [_, _, build_tools | _]}] when is_list(build_tools) ->
        {:ok, build_tools}
    end
  end

  def to_lock(tid, {name, app, version}) do
    case :ets.lookup(tid, name) do
      [] -> {:error, :no_package}
      [{^name, [versions|_]}] when is_list(versions) ->
        result = {String.to_atom(app), {:artifactory, String.to_atom(name), version}}
        {:ok, result}
    end
  end

  def from_lock(_tid, {app, {:artifactory, name, version}}) do
    {:ok, [{Atom.to_string(name), Atom.to_string(app), version}]}
  end
  def from_lock(_tid, _), do: {:error, :no_package}


  defp check_version(tid) do
    unless version(tid) in @versions do
      raise Mix.Error,
        message: "The registry file version is not supported. " <>
                 "Try updating Hex with `mix local.hex`."
    end
  end
end
