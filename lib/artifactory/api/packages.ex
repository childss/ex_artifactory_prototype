defmodule Artifactory.API.Packages do
  alias Artifactory.API

  def get_index(opts \\ []) do
    headers =
      if etag = opts[:etag] do
        %{'if-none-match' => etag}
      end

    {200, body} = API.request(:get, packages_api_url(), headers || [])
    extract_packages(body)
  end

  def fetch_package(name, path) do
    # if Artifactory.State.fetch!(:offline?) do
    #   {:ok, :offline}
    # else
      etag = Hex.Utils.etag(path)
      url  = Artifactory.API.package_url(name)

      case request(url, etag) do
        {:ok, body} when is_binary(body) ->
          File.write!(path, body)
          {:ok, :new}
        other ->
          other
      end
    # end
  end

  defp request(url, etag) do
    opts = [body_format: :binary]
    headers = [{'user-agent', Artifactory.API.user_agent}]
    headers = if etag, do: [{'if-none-match', etag}|headers], else: headers
    # http_opts = [relaxed: true, timeout: @request_timeout]
    http_opts = [relaxed: true]
    url = String.to_char_list(url)

    case :httpc.request(:get, {url, headers}, http_opts, opts, :artifactory) do
      {:ok, {{_version, 200, _reason}, _headers, body}} ->
        {:ok, body}
      {:ok, {{_version, 304, _reason}, _headers, _body}} ->
        {:ok, :cached}
      {:ok, {{_version, code, _reason}, _headers, _body}} ->
        {:error, "Request failed (#{code})"}
      {:error, reason} ->
        {:error, "Request failed: #{inspect reason}"}
    end
  end

  defp extract_packages(body) when is_binary(body) do
    body
    |> Poison.decode!
    |> extract_packages
  end

  defp extract_packages(json) when is_map(json) do
    regex = ~r/(?<dep>\w+)-(?<vsn>.*)\.tar/

    for artifact <- extract_children(json),
        captures = Regex.named_captures(regex, artifact),
        !is_nil(captures) do
      {captures["dep"], captures["vsn"]}
    end
  end

  defp extract_children(json) do
    json["children"]
    |> Enum.reject(&Map.get(&1, "folder", false))
    |> Enum.map(&Map.fetch!(&1, "uri"))
  end

  defp packages_api_url do
    repo = Artifactory.State.fetch!(:artifactory_repo)
    package_path = Path.join(repo, "tarballs")
    "/api/storage"
    |> Path.join(package_path)
    |> API.api_url
  end
end
