defmodule Mix.Tasks.LazyDoc.Clean do
  require Logger
  use Mix.Task

  def run(_command_line_args) do
    _result = LazyDoc.Application.start("", "")

    Mix.Task.run("app.config")

    LazyDoc.extract_data_from_files()
  end
end
