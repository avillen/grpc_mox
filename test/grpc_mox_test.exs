defmodule GrpcMoxTest do
  use ExUnit.Case, async: true

  alias GrpcMox

  defmodule Helloworld do
    defmodule HelloRequest do
      use Protobuf, syntax: :proto3

      field(:name, 1, type: :string)
    end

    defmodule HelloResponse do
      use Protobuf, syntax: :proto3

      field(:message, 1, type: :string)
    end

    defmodule Service do
      use GRPC.Service, name: "helloworld"

      rpc(:SayHello, HelloRequest, HelloResponse)
    end

    defmodule Stub do
      use GRPC.Stub, service: Service
    end
  end

  Mox.defmock(GRPCClientMock, for: GRPC.Client.Adapter)

  describe "expect_grpc/4" do
    test "on success" do
      req = Helloworld.HelloRequest.new(name: "Álvaro")
      res = Helloworld.HelloResponse.new(message: "Hola")

      GrpcMox.expect_grpc(GRPCClientMock, req, res)

      {:ok, conn} = GRPC.Stub.connect("localhost:0", adapter: GRPCClientMock)

      assert {:ok, res} == Helloworld.Stub.say_hello(conn, req)

      GRPC.Stub.disconnect(conn)
    end

    test "on rpc error" do
      req = Helloworld.HelloRequest.new(name: "Álvaro")
      res = %GRPC.RPCError{status: 3, message: "Hola"}

      GrpcMox.expect_grpc(GRPCClientMock, req, res)

      {:ok, conn} = GRPC.Stub.connect("localhost:0", adapter: GRPCClientMock)

      assert {:error, res} == Helloworld.Stub.say_hello(conn, req)

      GRPC.Stub.disconnect(conn)
    end
  end
end
