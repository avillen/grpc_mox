defmodule GrpcMox do
  @moduledoc ~S"""
  GrpcMox is a library for defining concurrent mocks for [grpc library](https://github.com/elixir-grpc/grpc).

  ## Basic usage

  ### 0) Read the [Mox documentation](https://github.com/dashbitco/mox).

  ### 1) Define the mock in your `test/support/mocks.exs` file

  ```
  ...

  Mox.defmock(GRPCClientMock, for: GRPC.Client.Adapter)
  ```

  ### 2) Use the mock adapter creating the connection:

  You would want to use the mock or the real adapter based on a application
  environment variable, this example is to simplify the code.

  ```
  connect_opts = [
    adapter: GRPCClientMock
  ]

  GRPC.Stub.connect(base_url, connect_opts)
  ```

  ### 3) Add the expectation in your test:

  ```
  req = Helloworld.HelloRequest.new(name: "Álvaro")
  res = Helloworld.HelloResponse.new(message: "Hola")

  GrpcMox.expect_grpc(GRPCClientMock, req, res)

  {:ok, conn} = GRPC.Stub.connect("localhost:0", adapter: GRPCClientMock)

  assert {:ok, res} == Helloworld.Stub.say_hello(conn, req)

  GRPC.Stub.disconnect(conn)
  ```
  """

  @doc """
  Expects the name in mock with the proto of the request and the proto of the response.

  Returns `:ok`.

  ## Examples

      req = Helloworld.HelloRequest.new(name: "Álvaro")
      res = Helloworld.HelloResponse.new(message: "Hola")

      GrpcMox.expect_grpc(GRPCClientMock, req, res)

      {:ok, conn} = GRPC.Stub.connect("localhost:0", adapter: GRPCClientMock)

      assert {:ok, res} == Helloworld.Stub.say_hello(conn, req)

      GRPC.Stub.disconnect(conn)

  """
  @spec expect_grpc(module(), struct(), struct(), Keyword.t()) :: :ok
  def expect_grpc(mock, proto_request, proto_response, opts \\ []) do
    case proto_response do
      %GRPC.RPCError{} = response ->
        proto_request_mod = proto_request.__struct__

        grpc_channel = %GRPC.Channel{
          adapter: mock
        }

        stream = %GRPC.Client.Stream{
          channel: grpc_channel,
          request_mod: proto_request_mod
        }

        encoded_request = encode_proto(proto_request_mod, proto_request)

        Mox.expect(mock, :connect, fn _, _ -> {:ok, grpc_channel} end)
        Mox.expect(mock, :send_request, fn _, ^encoded_request, _ -> stream end)
        Mox.expect(mock, :recv_headers, fn _, _, _ -> {:ok, [], :fin} end)

        Mox.expect(mock, :recv_data_or_trailers, fn _, _, _ -> {:error, response} end)

        Mox.expect(mock, :disconnect, fn _ -> {:ok, grpc_channel} end)

      proto_response ->
        grpc_status = opts |> Keyword.get(:grpc_status, 0) |> Integer.to_string()
        proto_request_mod = proto_request.__struct__
        proto_response_mod = proto_response.__struct__

        grpc_channel = %GRPC.Channel{
          adapter: mock
        }

        stream = %GRPC.Client.Stream{
          channel: grpc_channel,
          codec: GRPC.Codec.Proto,
          request_mod: proto_request_mod,
          response_mod: proto_response_mod
        }

        encoded_request = encode_proto(proto_request_mod, proto_request)

        Mox.expect(mock, :connect, fn _, _ -> {:ok, grpc_channel} end)
        Mox.expect(mock, :send_request, fn _, ^encoded_request, _ -> stream end)
        Mox.expect(mock, :recv_headers, fn _, _, _ -> {:ok, [], :fin} end)

        {:ok, encoded_response_data, _} =
          proto_response_mod
          |> encode_proto(proto_response)
          |> GRPC.Message.to_data()

        Mox.expect(mock, :recv_data_or_trailers, fn _, _, _ ->
          {:data, encoded_response_data}
        end)

        Mox.expect(mock, :recv_data_or_trailers, fn _, _, _ ->
          {:trailers, %{"grpc-status" => grpc_status}}
        end)

        Mox.expect(mock, :disconnect, fn _ -> {:ok, grpc_channel} end)
    end

    :ok
  end

  defp encode_proto(mod, struct) do
    apply(mod, :encode, [struct])
  end
end
