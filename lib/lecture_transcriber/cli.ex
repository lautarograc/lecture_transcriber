defmodule LectureTranscriber.CLI do
  alias LectureTranscriber.{ExternalTool, Pipeline, Config, ModelResolver, BundledTools}

  def main(["transcribe" | rest]) do
    {opts, args, _} =
      OptionParser.parse(rest,
        strict: [
          model: :string,
          models_dir: :string,
          out_dir: :string,
          lang: :string,
          whisper_bin: :string,
          ffmpeg_bin: :string,
          tesseract_bin: :string,
          scene_threshold: :float,
          no_slides: :boolean,
          config: :string
        ]
      )

    config = Config.load(opts[:config])

    model =
      ModelResolver.resolve(
        opts[:model] || config[:model],
        opts[:models_dir] || config[:models_dir]
      )

    with [video_path] <- args,
         model_path when is_binary(model_path) <- model do
      run_opts =
        [
          lang: opts[:lang] || config[:lang] || "en",
          slides: not (opts[:no_slides] || false),
          out_dir: opts[:out_dir] || config[:out_dir],
          whisper_bin:
            opts[:whisper_bin] || config[:whisper_bin] || BundledTools.path("whisper-cli") ||
              "whisper-cli",
          ffmpeg_bin:
            opts[:ffmpeg_bin] || config[:ffmpeg_bin] || BundledTools.path("ffmpeg") || "ffmpeg",
          tesseract_bin:
            opts[:tesseract_bin] || config[:tesseract_bin] || BundledTools.path("tesseract") ||
              "tesseract",
          scene_threshold: opts[:scene_threshold] || config[:scene_threshold] || 0.4
        ]
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)

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

    config file (JSON, all keys optional): #{Config.default_path()}
      model, models_dir, out_dir, lang, whisper_bin, ffmpeg_bin, tesseract_bin, scene_threshold

    --model accepts either a full path or a short name (e.g. "base.en") resolved
    against --models-dir / config models_dir as "<models_dir>/ggml-<name>.bin".
    """)
  end

  defp transcribe_usage do
    "transcribe <video> --model <path-or-name> [--models-dir DIR] [--out-dir DIR] [--lang en] " <>
      "[--whisper-bin BIN] [--ffmpeg-bin BIN] [--tesseract-bin BIN] [--scene-threshold FLOAT] " <>
      "[--no-slides] [--config PATH]"
  end
end
