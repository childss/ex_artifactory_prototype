defmodule Artifactory.HexPlugin do
  @behaviour Hex.Plugin

  def init do
    Artifactory.start
    :ok = Hex.Registry.append({:artifactory, Artifactory.Registry.ETS, Artifactory.SCM})
    Mix.SCM.append(Artifactory.SCM)
  end
end
