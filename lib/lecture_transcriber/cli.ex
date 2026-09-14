defmodule LectureTranscriber.CLI do
  alias LectureTranscriber.{ExternalTool, Pipeline}

  def main(["transcribe" | rest]) do
    {opts, args, _} =
      OptionParser.parse(rest,
        strict: [
          model: :string,
          out_dir: :string,
          lang: :string,
          whisper_bin: :string,
          ffmpeg_bin: :string
        ]
      )

    with [video_path] <- args,
         model_path when is_binary(model_path) <- opts[:model] do
      run_opts =
        [lang: opts[:lang] || "en"]
        |> put_if_present(:out_dir, opts[:out_dir])
        |> put_if_present(:bin, opts[:whisper_bin])
        |> put_if_present(:ffmpeg_bin, opts[:ffmpeg_bin])

      case Pipeline.transcribe_video(video_path, model_path, run_opts) do
        {:ok, %{markdown: md, srt: srt}} ->
          IO.puts("wrote #{md}")
          IO.puts("wrote #{srt}")

        {:error, reason} ->
          IO.puts(:stderr, "transcription failed: #{inspect(reason)}")
          System.halt(1)
      end
    else
      _ ->
        IO.puts(:stderr, transcribe_usage())
        System.halt(1)
    end
  end

  def main(["ffmpeg-check"]) do
    case ExternalTool.run("ffmpeg", ["-version"]) do
      {:ok, {output, 0}} -> IO.puts(output |> String.split("\n") |> List.first())
      {:ok, {output, code}} -> IO.puts(:stderr, "ffmpeg exited with #{code}: #{output}")
      {:error, :not_found} -> IO.puts(:stderr, "ffmpeg not found on PATH")
    end
  end

  def main(_args) do
    IO.puts("""
    usage:
      lecture_transcriber #{transcribe_usage()}
      lecture_transcriber ffmpeg-check
    """)
  end

  defp transcribe_usage do
    "transcribe <video> --model <path> [--out-dir DIR] [--lang en] [--whisper-bin BIN] [--ffmpeg-bin BIN]"
  end

  defp put_if_present(keyword, _key, nil), do: keyword
  defp put_if_present(keyword, key, value), do: Keyword.put(keyword, key, value)
end
