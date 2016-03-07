defmodule Artifactory.Registry do
  @filename "registry.ets"

  def new do
    Artifactory.Registry.Builder.full_rebuild
  end

  def save(registry, compress \\ false) do
    file_path = String.to_char_list(registry_path)
    :ets.tab2file(registry, file_path)
    if compress do
      gz_file = "#{registry_path}.gz"
      compressed =
        registry_path
        |> File.read!
        |> :zlib.gzip
      File.write!(gz_file, compressed)
    end
  end

  def load(path \\ registry_path) do
    :ets.file2tab(String.to_char_list(path))
  end

  def registry_path do
    Path.join(Artifactory.State.fetch!(:home), @filename)
  end
end
