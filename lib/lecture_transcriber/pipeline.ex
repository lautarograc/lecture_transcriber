defmodule LectureTranscriber.Pipeline do
  alias LectureTranscriber.{Ffmpeg, Whisper, Render}

  def transcribe_video(video_path, model_path, opts \\ []) do
    out_dir = Keyword.get(opts, :out_dir, Path.dirname(video_path))
    base = Path.basename(video_path, Path.extname(video_path))
    wav_path = Path.join(System.tmp_dir!(), "#{base}_#{:erlang.unique_integer([:positive])}.wav")

    result =
      with {:ok, _} <-
             Ffmpeg.extract_audio(video_path, wav_path, Keyword.get(opts, :ffmpeg_bin, "ffmpeg")),
           {:ok, segments} <- Whisper.transcribe(wav_path, model_path, opts) do
        File.mkdir_p!(out_dir)
        md_path = Path.join(out_dir, base <> ".md")
        srt_path = Path.join(out_dir, base <> ".srt")
        File.write!(md_path, Render.to_markdown(segments))
        File.write!(srt_path, Render.to_srt(segments))
        {:ok, %{markdown: md_path, srt: srt_path}}
      end

    File.rm(wav_path)
    result
  end
end
