defmodule LectureTranscriber.Whisper do
  alias LectureTranscriber.ExternalTool

  def transcribe(wav_path, model_path, opts \\ []) do
    bin = Keyword.get(opts, :whisper_bin, "whisper-cli")
    lang = Keyword.get(opts, :lang, "en")
    out_prefix = Path.rootname(wav_path)
    json_path = out_prefix <> ".json"

    args = ["-m", model_path, "-f", wav_path, "-l", lang, "-oj", "-of", out_prefix, "-np"]

    result =
      case ExternalTool.run(bin, args) do
        {:ok, {_output, 0}} -> parse_json(json_path)
        {:ok, {output, code}} -> {:error, {:whisper_failed, code, output}}
        {:error, :not_found} -> {:error, {:binary_not_found, bin}}
      end

    File.rm(json_path)
    result
  end

  defp parse_json(json_path) do
    with {:ok, content} <- File.read(json_path),
         {:ok, %{"transcription" => transcription}} <- Jason.decode(content) do
      segments =
        Enum.map(transcription, fn entry ->
          %{
            start_ms: entry["offsets"]["from"],
            end_ms: entry["offsets"]["to"],
            text: String.trim(entry["text"])
          }
        end)

      {:ok, segments}
    else
      {:error, reason} -> {:error, {:json_parse_failed, reason}}
    end
  end
end
