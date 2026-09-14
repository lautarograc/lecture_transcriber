defmodule LectureTranscriber.ModelResolver do
  def resolve(nil, _models_dir), do: nil

  def resolve(model, models_dir) do
    cond do
      File.exists?(model) -> model
      is_binary(models_dir) -> Path.join(models_dir, "ggml-#{model}.bin")
      true -> model
    end
  end
end
