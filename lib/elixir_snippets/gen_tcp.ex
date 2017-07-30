defmodule ElixirSnippets.TCPClient do
  require Logger
  
  def spawn do
    spawn(ElixirSnippets.TCPClient, :init, [])
  end
  
  def init do
    {:ok, socket} = :gen_tcp.connect('localhost', 5798, [:binary, {:packet, 0}])
    loop(socket)
  end

  def send_message(pid, message) do
    send(pid, {:send, message})
  end
  
  def loop(socket) do
    receive do
      {:send, message} ->
	:gen_tcp.send(socket, message)
	loop(socket)
      {:tcp, socket, message} ->
	Logger.info("#{inspect(self())} received #{message}")
	loop(socket)
      {:EXIT, from, reason} ->
	Logger.info("closing #{inspect(socket)}")
	:gen_tcp.close(socket)
    end
  end  
end

defmodule ElixirSnippets.TCPServer do
  require Logger
  
  def spawn do
    spawn(ElixirSnippets.TCPServer, :init, [])
  end

  def init do
    Process.flag(:trap_exit, true)
    {:ok, listen_socket} = :gen_tcp.listen(5798, [:binary, {:packet, 0}, {:active, true}])
    ElixirSnippets.Acceptor.spawn_link(listen_socket)
    loop(listen_socket)
  end

  def loop(listen_socket) do
    receive do
      {:EXIT, _from, _reason} ->
	Logger.info("closing socket #{inspect(listen_socket)}")
	:gen_tcp.close(listen_socket)
    end
  end
end

defmodule ElixirSnippets.Acceptor do
  def spawn_link(listen_socket) do
    spawn_link(ElixirSnippets.Acceptor, :loop, [listen_socket])
  end

  def loop(listen_socket) do
    response = :gen_tcp.accept(listen_socket)
    case response do
      {:ok, socket} ->
	pid = ElixirSnippets.RequestHandler.spawn_link()
	:ok = :gen_tcp.controlling_process(socket, pid)
	loop(listen_socket)
      {:error, _} ->
	:exit
    end
  end  
end


defmodule ElixirSnippets.RequestHandler do
  require Logger
  
  def spawn_link do
    spawn_link(ElixirSnippets.RequestHandler, :handle_request, [])
  end
  
  def handle_request do
    receive do
      {:tcp, socket, message} ->
	Logger.info("#{inspect(self())} received #{message}")
	:gen_tcp.send(socket, message)
	handle_request()
    end    
  end  
end

defmodule ElixirSnippets.GenTCPDemo do
  def demo do
    server = ElixirSnippets.TCPServer.spawn()
    client = ElixirSnippets.TCPClient.spawn()

    ElixirSnippets.TCPClient.send_message(client, "message")

    Process.sleep(1000)
    Process.exit(server, :normal)
    Process.exit(client, :normal)
  end  
end


