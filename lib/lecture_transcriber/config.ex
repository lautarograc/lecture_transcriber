defmodule LectureTranscriber.Config do
  def default_path do
    Path.join(config_dir(), "config.json")
  end

  def load(path \\ nil) do
    path = path || default_path()

    with {:ok, content} <- File.read(path),
         {:ok, map} <- Jason.decode(content) do
      Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
    else
      _ -> %{}
    end
  end

  defp config_dir do
    case :os.type() do
      {:win32, _} ->
        base = System.get_env("APPDATA") || Path.expand("~")
        Path.join(base, "lecture_transcriber")

      _ ->
        base = System.get_env("XDG_CONFIG_HOME") || Path.join(Path.expand("~"), ".config")
        Path.join(base, "lecture_transcriber")
    end
  end
end
