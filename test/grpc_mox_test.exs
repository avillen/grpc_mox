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

  describe "expect/3" do
    test "on success" do
      Mox.defmock(GRPCClientMock, for: GRPC.Client.Adapter)

      req = Helloworld.HelloRequest.new(name: "Álvaro")
      res = Helloworld.HelloResponse.new(message: "Hola")

      GrpcMox.expect_grpc(GRPCClientMock, res)

      {:ok, conn} = GRPC.Stub.connect("localhost:0", adapter: GRPCClientMock)

      assert {:ok, res} == Helloworld.Stub.say_hello(conn, req)

      GRPC.Stub.disconnect(conn)
    end
  end
end
