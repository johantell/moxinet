defmodule Moxinet.MixProject do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :moxinet,
      version: @version,
      description: "Mocking server that, just like mox, allows parallel testing, but over HTTP.",
      elixir: "~> 1.15",
      start_permanent: false,
      deps: deps(),
      aliases: aliases(),
      docs: [
        main: "readme",
        extras: ["README.md"],
        before_closing_head_tag: &before_closing_head_tag/1
      ],
      package: [
        licenses: licenses(),
        links: links()
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, ">= 0.0.0"},
      {:jason, ">= 0.0.0"},
      {:plug, ">= 0.0.0"},
      {:ex_doc, "~> 0.37.3", only: :dev, runtime: false},
      {:credo, "~> 1.7.5", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4.3", only: :dev, runtime: false}
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <script src="https://cdn.jsdelivr.net/npm/mermaid@10.2.3/dist/mermaid.min.js"></script>
    <script>
    document.addEventListener("DOMContentLoaded", function () {
      mermaid.initialize({
        startOnLoad: false,
        theme: document.body.className.includes("dark") ? "dark" : "default"
      });
      let id = 0;
      for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
        const preEl = codeEl.parentElement;
        const graphDefinition = codeEl.textContent;
        const graphEl = document.createElement("div");
        const graphId = "mermaid-graph-" + id++;
        mermaid.render(graphId, graphDefinition).then(({svg, bindFunctions}) => {
          graphEl.innerHTML = svg;
          bindFunctions?.(graphEl);
          preEl.insertAdjacentElement("afterend", graphEl);
          preEl.remove();
        });
      }
    });
    </script>
    """
  end

  defp before_closing_head_tag(:epub), do: ""

  defp licenses do
    ["MIT"]
  end

  defp links do
    %{
      "Github" => "https://github.com/johantell/moxinet",
      "HexDocs" => "https://hexdocs.pm/moxinet"
    }
  end

  defp aliases do
    [
      ci: ["format --check-formatted", "credo", "dialyzer"]
    ]
  end
end
