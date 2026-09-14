defmodule LectureTranscriber.CLI do
  alias LectureTranscriber.ExternalTool

  def main(["ffmpeg-check"]) do
    case ExternalTool.run("ffmpeg", ["-version"]) do
      {:ok, {output, 0}} -> IO.puts(output |> String.split("\n") |> List.first())
      {:ok, {output, code}} -> IO.puts(:stderr, "ffmpeg exited with #{code}: #{output}")
      {:error, :not_found} -> IO.puts(:stderr, "ffmpeg not found on PATH")
    end
  end

  def main(_args) do
    IO.puts("usage: lecture_transcriber ffmpeg-check")
  end
end
