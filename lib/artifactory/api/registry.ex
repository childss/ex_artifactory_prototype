defmodule Artifactory.API.Registry do
  alias Artifactory.API

  def get(opts \\ []) do
    headers =
      if etag = opts[:etag] do
        %{'if-none-match' => etag}
      end

    API.request(:get, API.repo_url("registry.ets.gz"), headers || [])
  end

  defp packages_api_url do
    repo = Artifactory.State.fetch!(:artifactory_repo)
    package_path = Path.join(repo, "tarballs")
    "/api/storage"
    |> Path.join(package_path)
    |> API.api_url
  end
end
