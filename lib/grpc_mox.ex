defmodule GrpcMox do
  @spec expect_grpc(module(), struct(), struct(), Keyword.t()) :: :ok
  def expect_grpc(grpcClientMock, proto_request, proto_response, opts \\ []) do
    case proto_response do
      %GRPC.RPCError{} = response ->
        proto_request_mod = proto_request.__struct__

        grpc_channel = %GRPC.Channel{
          adapter: grpcClientMock
        }

        stream = %GRPC.Client.Stream{
          channel: grpc_channel,
          request_mod: proto_request_mod
        }

        encoded_request = encode_proto(proto_request_mod, proto_request)

        Mox.expect(grpcClientMock, :connect, fn _, _ -> {:ok, grpc_channel} end)
        Mox.expect(grpcClientMock, :send_request, fn _, ^encoded_request, _ -> stream end)
        Mox.expect(grpcClientMock, :recv_headers, fn _, _, _ -> {:ok, [], :fin} end)

        Mox.expect(grpcClientMock, :recv_data_or_trailers, fn _, _, _ -> {:error, response} end)

        Mox.expect(grpcClientMock, :disconnect, fn _ -> {:ok, grpc_channel} end)

      proto_response ->
        grpc_status = opts |> Keyword.get(:grpc_status, 0) |> Integer.to_string()
        proto_request_mod = proto_request.__struct__
        proto_response_mod = proto_response.__struct__

        grpc_channel = %GRPC.Channel{
          adapter: grpcClientMock
        }

        stream = %GRPC.Client.Stream{
          channel: grpc_channel,
          codec: GRPC.Codec.Proto,
          request_mod: proto_request_mod,
          response_mod: proto_response_mod
        }

        encoded_request = encode_proto(proto_request_mod, proto_request)

        Mox.expect(grpcClientMock, :connect, fn _, _ -> {:ok, grpc_channel} end)
        Mox.expect(grpcClientMock, :send_request, fn _, ^encoded_request, _ -> stream end)
        Mox.expect(grpcClientMock, :recv_headers, fn _, _, _ -> {:ok, [], :fin} end)

        {:ok, encoded_response_data, _} =
          proto_response_mod
          |> encode_proto(proto_response)
          |> GRPC.Message.to_data()

        Mox.expect(grpcClientMock, :recv_data_or_trailers, fn _, _, _ ->
          {:data, encoded_response_data}
        end)

        Mox.expect(grpcClientMock, :recv_data_or_trailers, fn _, _, _ ->
          {:trailers, %{"grpc-status" => grpc_status}}
        end)

        Mox.expect(grpcClientMock, :disconnect, fn _ -> {:ok, grpc_channel} end)
    end

    :ok
  end

  defp encode_proto(mod, struct) do
    apply(mod, :encode, [struct])
  end
end
