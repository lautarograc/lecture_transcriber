defmodule LectureTranscriber.Render do
  def to_markdown(segments, slides \\ [], opts \\ []) do
    image_dir = Keyword.get(opts, :image_dir_name, "slides")

    speech_events = Enum.map(segments, &{&1.start_ms, :speech, &1})
    slide_events = Enum.map(slides, &{&1.time_ms, :slide, &1})

    (speech_events ++ slide_events)
    |> Enum.sort_by(fn {time_ms, _type, _data} -> time_ms end)
    |> Enum.map(&render_event(&1, image_dir))
    |> Enum.join("\n\n")
  end

  defp render_event({start_ms, :speech, %{text: text}}, _image_dir) do
    "**[#{timestamp(start_ms)}]** #{text}"
  end

  defp render_event({time_ms, :slide, %{image_path: path, ocr_text: ocr_text}}, image_dir) do
    image_name = Path.basename(path)
    heading = "---\n\n**[#{timestamp(time_ms)}] Slide**\n\n![slide](#{image_dir}/#{image_name})"

    case ocr_text do
      "" -> heading
      text -> heading <> "\n\n> " <> String.replace(text, "\n", "\n> ")
    end
  end

  def to_srt(segments) do
    segments
    |> Enum.with_index(1)
    |> Enum.map(fn {%{start_ms: s, end_ms: e, text: text}, index} ->
      "#{index}\n#{srt_timestamp(s)} --> #{srt_timestamp(e)}\n#{text}\n"
    end)
    |> Enum.join("\n")
  end

  defp timestamp(ms) do
    {h, m, s, _} = parts(ms)
    :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s]) |> to_string()
  end

  defp srt_timestamp(ms) do
    {h, m, s, ms_rem} = parts(ms)
    :io_lib.format("~2..0B:~2..0B:~2..0B,~3..0B", [h, m, s, ms_rem]) |> to_string()
  end

  defp parts(ms) do
    total_seconds = div(ms, 1000)
    h = div(total_seconds, 3600)
    m = div(rem(total_seconds, 3600), 60)
    s = rem(total_seconds, 60)
    {h, m, s, rem(ms, 1000)}
  end
end
