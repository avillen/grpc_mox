defmodule GrpcMox.MixProject do
  use Mix.Project

  def project do
    [
      app: :grpc_mox,
      version: "0.2.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:grpc, "~> 0.5.0"},
      {:protobuf, "~> 0.6"},
      {:mox, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
