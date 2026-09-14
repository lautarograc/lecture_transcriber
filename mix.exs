defmodule LectureTranscriber.MixProject do
  use Mix.Project

  def project do
    [
      app: :lecture_transcriber,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {LectureTranscriber.Application, []}
    ]
  end

  defp deps do
    [
      {:burrito, "~> 1.0"}
    ]
  end

  defp releases do
    [
      lecture_transcriber: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            linux: [os: :linux, cpu: :x86_64],
            windows: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
