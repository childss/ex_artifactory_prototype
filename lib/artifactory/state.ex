defmodule Artifactory.State do
  @name __MODULE__

  def start_link do
    config = Artifactory.Config.read
    Agent.start_link(__MODULE__, :init, [config], name: @name)
  end

  def init(config) do
    %{home: Path.expand(Artifactory.default_home),
      artifactory_url: assert_config(config, :artifactory_url),
      artifactory_repo: assert_config(config, :artifactory_repo),
      registry_updated: false}
  end

  def fetch(key) do
    Agent.get(@name, Map, :fetch, [key])
  end

  def fetch!(key) do
    Agent.get(@name, Map, :fetch!, [key])
  end

  def get(key, default \\ nil) do
    Agent.get(@name, Map, :get, [key, default])
  end

  def put(key, value) do
    Agent.update(@name, Map, :put, [key, value])
  end

  def assert_config(config, key) do
    if value = Keyword.get(config, key) do
      value
    else
      raise "missing required Artifactory configuration key: #{key}"
    end
  end
end
