defmodule Artifactory do
  use Application

  def default_home, do: "~/.ex_artifactory"
  def version, do: unquote(Mix.Project.config[:version])

  def start do
    {:ok, _} = Application.ensure_all_started(:artifactory)
  end

  def stop do
    case Application.stop(:artifactory) do
      :ok -> :ok
      {:error, {:not_started, :artifactory}} -> :ok
    end
  end

  def start(type, args) do
    import Supervisor.Spec

    start_httpc()

    children = [
      worker(Artifactory.State, []),
      worker(Hex.Parallel, [:artifactory_fetcher, [max_parallel: 8]]),
    ]

    opts = [strategy: :one_for_one, name: Artifactory.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp start_httpc() do
    :inets.start(:httpc, profile: :artifactory)
    opts = [
      max_sessions: 4,
      max_keep_alive_length: 4,
      keep_alive_timeout: 120_000,
      max_pipeline_length: 4,
      pipeline_timeout: 60_000
    ]
    :httpc.set_options(opts, :artifactory)
  end
end
