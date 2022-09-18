# GrpcMox

GrpcMox is a library for defining concurrent mocks for [grpc library](https://github.com/elixir-grpc/grpc).


## Installation

Just add `grpc_mox` to your list of dependencies in mix.exs:

```elixir
def deps do
  [
      {:grpc_mox, git: "https://github.com/avillen/grpc_mox", tag: "v0.2.0"},
  ]
end
```

## Basic usage

### 0) Read the [Mox documentation](https://github.com/dashbitco/mox).

### 1) Define the mock in your test or in your `test/support/mocks.exs` file

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
