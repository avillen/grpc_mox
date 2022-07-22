defmodule GrpcMox do
  import Mox

  @spec expect_grpc(module(), struct(), Keyword.t()) :: :ok
  def expect_grpc(grpcClientMock, proto_response, opts \\ []) do
    grpc_status = opts |> Keyword.get(:grpc_status, 0) |> Integer.to_string()
    proto_response_mod = proto_response.__struct__

    grpc_channel = %GRPC.Channel{
      adapter: grpcClientMock
    }

    stream = %GRPC.Client.Stream{
      channel: grpc_channel,
      codec: GRPC.Codec.Proto,
      response_mod: proto_response_mod
    }

    expect(grpcClientMock, :connect, fn _, _ -> {:ok, grpc_channel} end)
    expect(grpcClientMock, :send_request, fn _, _, _ -> stream end)
    expect(grpcClientMock, :recv_headers, fn _, _, _ -> {:ok, [], :fin} end)

    {:ok, data, _} =
      proto_response_mod
      |> encode_proto(proto_response)
      |> GRPC.Message.to_data()

    expect(grpcClientMock, :recv_data_or_trailers, fn _, _, _ -> {:data, data} end)

    expect(grpcClientMock, :recv_data_or_trailers, fn _, _, _ ->
      {:trailers, %{"grpc-status" => grpc_status}}
    end)

    expect(grpcClientMock, :disconnect, fn _ -> {:ok, grpc_channel} end)

    :ok
  end

  defp encode_proto(mod, struct) do
    apply(mod, :encode, [struct])
  end
end
