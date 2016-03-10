# Artifactory plugin for Hex

The goal for this is to be able to add dependencies to a Mix project that exist
as "private Hex packages" in an
[Artifactory](https://www.jfrog.com/artifactory/) repository.

## Mix example

```
  def project do
    [app: :my_app,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     hex_plugins: [Artifactory.HexPlugin],
     deps: deps]
  end

  defp deps do
    [
      {:internal_sdk, "~> 1.2.0", in_artifactory: true},
      # other Hex dependencies like normal
    ]
  end
```
