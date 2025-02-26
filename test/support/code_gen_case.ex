defmodule Beacon.CodeGenCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import Igniter.Test

      def phoenix_project(opts \\ []) do
        app_name = Keyword.get(opts, :app_name, "test")
        source_base_path = Path.expand("../../../deps/phx_new/templates", __DIR__)

        project =
          app_name
          |> Phx.New.Project.new([])
          |> Phx.New.Single.prepare_project()
          |> Phx.New.Generator.put_binding()

        templates =
          for {_, _, files} <- Phx.New.Single.template_files(:new),
              {source, target_path} <- files,
              String.ends_with?(target_path, [".ex", ".exs", ".heex"]),
              source = to_string(source) do
            {Path.expand(source, source_base_path), expand_path_with_bindings(target_path, project)}
          end

        templates
        |> Enum.reduce(Igniter.Test.test_project(), fn {source, target}, igniter ->
          Igniter.copy_template(igniter, source, target, project.binding, on_exists: :overwrite)
        end)
        |> Igniter.copy_template(".formatter.exs", ".formatter.exs", [], on_exists: :overwrite)
        |> Igniter.Test.apply_igniter!()
      end

      defp expand_path_with_bindings(path, %Phx.New.Project{} = project) do
        Regex.replace(Regex.recompile!(~r/:[a-zA-Z0-9_]+/), path, fn ":" <> key, _ ->
          project |> Map.fetch!(:"#{key}") |> to_string()
        end)
      end
    end
  end
end
