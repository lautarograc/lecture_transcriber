defmodule LectureTranscriber.SceneDetect do
  alias LectureTranscriber.ExternalTool

  def extract_slides(video_path, out_dir, opts \\ []) do
    threshold = Keyword.get(opts, :scene_threshold, 0.4)
    bin = Keyword.get(opts, :ffmpeg_bin, "ffmpeg")

    with {:ok, change_times_ms} <- detect_scene_changes(video_path, threshold, bin) do
      File.mkdir_p!(out_dir)

      [0 | change_times_ms]
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, []}, fn {time_ms, index}, {:ok, acc} ->
        image_path = Path.join(out_dir, "slide_#{pad(index)}.png")

        case extract_frame(video_path, time_ms, image_path, bin) do
          :ok -> {:cont, {:ok, [%{time_ms: time_ms, image_path: image_path} | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, slides} -> {:ok, Enum.reverse(slides)}
        error -> error
      end
    end
  end

  defp detect_scene_changes(video_path, threshold, bin) do
    args = [
      "-i",
      video_path,
      "-vf",
      "select='gt(scene,#{threshold})',showinfo",
      "-vsync",
      "vfr",
      "-f",
      "null",
      "-"
    ]

    case ExternalTool.run(bin, args) do
      {:ok, {output, _code}} ->
        times =
          ~r/pts_time:(\d+(?:\.\d+)?)/
          |> Regex.scan(output)
          |> Enum.map(fn [_, t] ->
            {value, _} = Float.parse(t)
            round(value * 1000)
          end)

        {:ok, times}

      {:error, :not_found} ->
        {:error, {:binary_not_found, bin}}
    end
  end

  defp extract_frame(video_path, time_ms, out_path, bin) do
    seconds = :erlang.float_to_binary(time_ms / 1000, decimals: 3)
    args = ["-y", "-ss", seconds, "-i", video_path, "-frames:v", "1", out_path]

    case ExternalTool.run(bin, args) do
      {:ok, {_output, 0}} -> :ok
      {:ok, {output, code}} -> {:error, {:ffmpeg_failed, code, output}}
      {:error, :not_found} -> {:error, {:binary_not_found, bin}}
    end
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(4, "0")
end
