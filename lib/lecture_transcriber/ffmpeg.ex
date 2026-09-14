defmodule LectureTranscriber.Ffmpeg do
  alias LectureTranscriber.ExternalTool

  def extract_audio(video_path, wav_path, bin \\ "ffmpeg") do
    args = ["-y", "-i", video_path, "-vn", "-ac", "1", "-ar", "16000", "-f", "wav", wav_path]

    case ExternalTool.run(bin, args) do
      {:ok, {_output, 0}} -> {:ok, wav_path}
      {:ok, {output, code}} -> {:error, {:ffmpeg_failed, code, output}}
      {:error, :not_found} -> {:error, {:binary_not_found, bin}}
    end
  end
end
