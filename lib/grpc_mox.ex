defmodule GrpcMox do
  @spec expect_grpc(module(), function(), Keyword.t()) :: :ok
  def expect_grpc(grpcClientMock, callback, opts \\ []) do
    case callback.() do
      {:ok, proto_response} ->
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

        Mox.expect(grpcClientMock, :connect, fn _, _ -> {:ok, grpc_channel} end)
        Mox.expect(grpcClientMock, :send_request, fn _, _encoded_request, _ -> stream end)
        Mox.expect(grpcClientMock, :recv_headers, fn _, _, _ -> {:ok, [], :fin} end)

        {:ok, data, _} =
          proto_response_mod
          |> encode_proto(proto_response)
          |> GRPC.Message.to_data()

        Mox.expect(grpcClientMock, :recv_data_or_trailers, fn _, _, _ -> {:data, data} end)

        Mox.expect(grpcClientMock, :recv_data_or_trailers, fn _, _, _ ->
          {:trailers, %{"grpc-status" => grpc_status}}
        end)

        Mox.expect(grpcClientMock, :disconnect, fn _ -> {:ok, grpc_channel} end)

      {:error, %GRPC.RPCError{} = rpc_error} ->
        grpc_channel = %GRPC.Channel{
          adapter: grpcClientMock
        }

        stream = %GRPC.Client.Stream{
          channel: grpc_channel
        }

        Mox.expect(grpcClientMock, :connect, fn _, _ -> {:ok, grpc_channel} end)
        Mox.expect(grpcClientMock, :send_request, fn _, _encoded_request, _ -> stream end)
        Mox.expect(grpcClientMock, :recv_headers, fn _, _, _ -> {:ok, [], :fin} end)
        Mox.expect(grpcClientMock, :recv_data_or_trailers, fn _, _, _ -> {:error, rpc_error} end)
        Mox.expect(grpcClientMock, :disconnect, fn _ -> {:ok, grpc_channel} end)
    end

    :ok
  end

  defp encode_proto(mod, struct) do
    apply(mod, :encode, [struct])
  end
end
