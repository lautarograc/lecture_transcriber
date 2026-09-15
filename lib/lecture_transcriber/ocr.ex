defmodule LectureTranscriber.Ocr do
  alias LectureTranscriber.{ExternalTool, BundledTools}

  def recognize(image_path, opts \\ []) do
    bin = Keyword.get(opts, :tesseract_bin, "tesseract")

    case ExternalTool.run(bin, [image_path, "stdout"], merge_stderr: false, env: env_for(bin)) do
      {:ok, {output, 0}} -> {:ok, String.trim(output)}
      {:ok, {output, code}} -> {:error, {:tesseract_failed, code, output}}
      {:error, :not_found} -> {:error, {:binary_not_found, bin}}
    end
  end

  defp env_for(bin) do
    with true <- bin == BundledTools.path("tesseract"),
         tessdata when tessdata != nil <- BundledTools.tessdata_dir() do
      [{"TESSDATA_PREFIX", tessdata}]
    else
      _ -> []
    end
  end
end
