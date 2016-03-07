defmodule Artifactory.API do
  def request(method, url, headers, body \\ nil) when body == nil or is_map(body) do
    default_headers = %{'user-agent' => user_agent()}
    headers = Dict.merge(default_headers, headers)

    # http_opts = [relaxed: true, timeout: @request_timeout]
    http_opts = [relaxed: true]
    opts = [body_format: :binary]
    url = String.to_char_list(url)

    request =
      cond do
        # body ->
        #   body = Hex.Utils.safe_serialize_erlang(body)
        #   {url, Map.to_list(headers), @erlang_vendor, body}
        # method in [:put, :post] ->
        #   body = :erlang.term_to_binary(%{})
        #   {url, Map.to_list(headers), @erlang_vendor, body}
        true ->
          {url, Map.to_list(headers)}
      end

    case :httpc.request(method, request, http_opts, opts, :artifactory) do
      {:ok, response} ->
        handle_response(response)
      {:error, reason} ->
        {:http_error, reason}
    end
  end

  defp handle_response({{_version, code, _reason}, _headers, body}) do
    # headers = Enum.into(headers, %{})
    # Utils.handle_hex_message(headers['x-hex-message'])

    # body = body |> unzip(headers) |> decode(headers)

    {code, body}
  end

  def api_url(path) do
    Path.join(Artifactory.State.fetch!(:artifactory_url), path)
  end

  def repo_url(path) do
    Path.join([
      Artifactory.State.fetch!(:artifactory_url),
      Artifactory.State.fetch!(:artifactory_repo),
      path
    ])
  end

  def package_url(filename) do
    repo_url(Path.join("tarballs", filename))
  end

  def user_agent do
    'Artifactory/#{Artifactory.version} (Elixir/#{System.version}) (OTP/#{Hex.Utils.otp_version})'
  end
end
