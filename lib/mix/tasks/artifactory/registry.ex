defmodule Mix.Tasks.Artifactory.Registry do
  use Mix.Task

  @shortdoc "Artifactory registry tasks"

  def run(args) do
    Hex.start

    {opts, rest, _} = OptionParser.parse(args)
    case rest do
      ["fetch"] ->
        fetch()
      ["update"] ->
        update(opts)
      # ["dump", path] ->
      #   dump(path)
      # ["load", path] ->
      #   load(path)
      _otherwise ->
        message = """
          Invalid arguments, expected one of:
            mix artifactory.registry fetch
          """
        Mix.raise message
    end
  end

  def fetch do
    Artifactory.Utils.ensure_registry!(update: true)
  end

  def update(opts) do
    if opts[:rebuild] do
      Artifactory.Shell.info "Doing full rebuild of package registry, this may take a while."

      compress = Keyword.get(opts, :compress, false)
      Artifactory.Registry.new |> Artifactory.Registry.save(compress)
    end
  end
end
