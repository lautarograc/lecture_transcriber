defmodule LectureTranscriber.Pipeline do
  alias LectureTranscriber.{Ffmpeg, Whisper, Render, SceneDetect, Ocr}

  def transcribe_video(video_path, model_path, opts \\ []) do
    out_dir = Keyword.get(opts, :out_dir, Path.dirname(video_path))
    base = Path.basename(video_path, Path.extname(video_path))
    wav_path = Path.join(System.tmp_dir!(), "#{base}_#{:erlang.unique_integer([:positive])}.wav")
    slides_dir_name = "#{base}_slides"
    slides_dir = Path.join(out_dir, slides_dir_name)
    slides_enabled = Keyword.get(opts, :slides, true)

    result =
      with {:ok, _} <-
             Ffmpeg.extract_audio(video_path, wav_path, Keyword.get(opts, :ffmpeg_bin, "ffmpeg")),
           {:ok, segments} <- Whisper.transcribe(wav_path, model_path, opts),
           {:ok, slides} <- extract_slides(slides_enabled, video_path, slides_dir, opts) do
        File.mkdir_p!(out_dir)
        md_path = Path.join(out_dir, base <> ".md")
        srt_path = Path.join(out_dir, base <> ".srt")

        markdown = Render.to_markdown(segments, slides, image_dir_name: slides_dir_name)
        File.write!(md_path, markdown)
        File.write!(srt_path, Render.to_srt(segments))

        {:ok, %{markdown: md_path, srt: srt_path, slides: slides}}
      end

    File.rm(wav_path)
    result
  end

  defp extract_slides(false, _video_path, _slides_dir, _opts), do: {:ok, []}

  defp extract_slides(true, video_path, slides_dir, opts) do
    with {:ok, frames} <- SceneDetect.extract_slides(video_path, slides_dir, opts) do
      frames
      |> Enum.reduce_while({:ok, []}, fn %{time_ms: t, image_path: path}, {:ok, acc} ->
        case Ocr.recognize(path, opts) do
          {:ok, text} -> {:cont, {:ok, [%{time_ms: t, image_path: path, ocr_text: text} | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, slides} -> {:ok, Enum.reverse(slides)}
        error -> error
      end
    end
  end
end
