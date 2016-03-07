defmodule Artifactory.EmbeddedConfig do
  @embedded_path "config/embedded.config"

  def config, do: []

  defoverridable [config: 0]

  # TODO: template file
  if File.exists?(@embedded_path) do
    @external_resource Path.expand(@embedded_path)
    def config, do: unquote(Artifactory.Config.read(@embedded_path))
  end
end
