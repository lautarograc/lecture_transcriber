defmodule LectureTranscriber.ExternalTool do
  def run(binary, args, opts \\ []) do
    merge_stderr = Keyword.get(opts, :merge_stderr, true)

    case System.find_executable(binary) do
      nil -> {:error, :not_found}
      path -> {:ok, System.cmd(path, args, stderr_to_stdout: merge_stderr)}
    end
  end
end
