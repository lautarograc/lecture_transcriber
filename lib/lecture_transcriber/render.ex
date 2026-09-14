defmodule LectureTranscriber.Render do
  def to_markdown(segments) do
    segments
    |> Enum.map(fn %{start_ms: start_ms, text: text} ->
      "**[#{timestamp(start_ms)}]** #{text}"
    end)
    |> Enum.join("\n\n")
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
