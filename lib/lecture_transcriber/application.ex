defmodule LectureTranscriber.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = []
    opts = [strategy: :one_for_one, name: LectureTranscriber.Supervisor]
    result = Supervisor.start_link(children, opts)

    case Burrito.Util.Args.argv() do
      [] ->
        :ok

      args ->
        LectureTranscriber.CLI.main(args)
        System.halt(0)
    end

    result
  end
end
