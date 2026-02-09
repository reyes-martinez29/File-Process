defmodule WebWeb.PageController do
  use WebWeb, :controller

  def home(conn, _params) do
    IO.inspect(FProcess.Core, label: "core module")
    render(conn, :home)
  end
end
