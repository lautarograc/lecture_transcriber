defmodule LectureTranscriber.BundledTools do
  def path(tool) do
    with priv_dir when priv_dir != nil <- priv_dir(),
         candidate = Path.join([priv_dir, "bin", target_dir(), filename(tool)]),
         true <- File.exists?(candidate) do
      candidate
    else
      _ -> nil
    end
  end

  def tessdata_dir do
    with priv_dir when priv_dir != nil <- priv_dir(),
         candidate = Path.join(priv_dir, "tessdata"),
         true <- File.dir?(candidate) do
      candidate
    else
      _ -> nil
    end
  end

  defp priv_dir do
    case :code.priv_dir(:lecture_transcriber) do
      {:error, :bad_name} -> nil
      dir -> List.to_string(dir)
    end
  end

  defp target_dir do
    case :os.type() do
      {:win32, _} -> "windows"
      _ -> "linux"
    end
  end

  defp filename(tool) do
    case :os.type() do
      {:win32, _} -> tool <> ".exe"
      _ -> tool
    end
  end
end
