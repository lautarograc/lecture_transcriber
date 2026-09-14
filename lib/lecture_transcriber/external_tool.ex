defmodule LectureTranscriber.ExternalTool do
  def run(binary, args) do
    case System.find_executable(binary) do
      nil -> {:error, :not_found}
      path -> {:ok, System.cmd(path, args, stderr_to_stdout: true)}
    end
  end
end
