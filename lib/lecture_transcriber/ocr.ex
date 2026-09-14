defmodule LectureTranscriber.Ocr do
  alias LectureTranscriber.ExternalTool

  def recognize(image_path, opts \\ []) do
    bin = Keyword.get(opts, :tesseract_bin, "tesseract")

    case ExternalTool.run(bin, [image_path, "stdout"], merge_stderr: false) do
      {:ok, {output, 0}} -> {:ok, String.trim(output)}
      {:ok, {output, code}} -> {:error, {:tesseract_failed, code, output}}
      {:error, :not_found} -> {:error, {:binary_not_found, bin}}
    end
  end
end
