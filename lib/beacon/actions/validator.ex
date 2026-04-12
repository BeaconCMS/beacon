defmodule Beacon.Actions.Validator do
  @moduledoc false

  @valid_actions ~w(
    navigate patch redirect open_url scroll_to dismiss
    submit fetch
    set_state toggle_state
    show hide toggle add_class remove_class toggle_class
    set_attribute remove_attribute transition focus
    flash dispatch_event push_event track
    validate
    conditional sequence
    custom
  )

  @doc """
  Validate an action document structure.

  Returns `:ok` or `{:error, reasons}` where reasons is a list of error strings.
  """
  @spec validate(map()) :: :ok | {:error, [binary()]}
  def validate(%{"steps" => steps}) when is_list(steps) do
    errors = validate_steps(steps, [], [])

    case errors do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  def validate(%{"version" => _, "steps" => steps}) when is_list(steps) do
    validate(%{"steps" => steps})
  end

  def validate(_) do
    {:error, ["action document must have a \"steps\" key containing a list"]}
  end

  @doc """
  Validate that all referenced endpoints exist for a site.
  """
  @spec validate_endpoints(map(), atom()) :: :ok | {:error, [binary()]}
  def validate_endpoints(%{"steps" => steps}, site) do
    endpoint_names = extract_endpoint_names(steps, [])

    missing =
      Enum.filter(endpoint_names, fn name ->
        Beacon.Content.get_graphql_endpoint_by(site, name: name) == nil
      end)

    case missing do
      [] -> :ok
      names -> {:error, Enum.map(names, &"GraphQL endpoint \"#{&1}\" not found for site #{site}")}
    end
  end

  def validate_endpoints(_, _), do: :ok

  defp validate_steps([], _path, errors), do: errors

  defp validate_steps([step | rest], path, errors) do
    step_path = path ++ [length(path)]
    errors = validate_step(step, step_path, errors)
    validate_steps(rest, path, errors)
  end

  defp validate_step(%{"action" => action} = step, path, errors) when action in @valid_actions do
    errors = validate_step_fields(action, step, path, errors)

    # Recursively validate nested steps
    errors = validate_nested(step["on_success"], path ++ ["on_success"], errors)
    errors = validate_nested(step["on_error"], path ++ ["on_error"], errors)
    errors = validate_nested(step["then"], path ++ ["then"], errors)
    errors = validate_nested(step["else"], path ++ ["else"], errors)
    errors = validate_nested(step["steps"], path ++ ["steps"], errors)

    errors
  end

  defp validate_step(%{"action" => action}, path, errors) do
    ["unknown action \"#{action}\" at #{inspect(path)}" | errors]
  end

  defp validate_step(step, path, errors) do
    ["step at #{inspect(path)} is missing the \"action\" key: #{inspect(step)}" | errors]
  end

  defp validate_nested(nil, _path, errors), do: errors
  defp validate_nested(steps, path, errors) when is_list(steps), do: validate_steps(steps, path, errors)
  defp validate_nested(_, path, errors), do: ["expected list at #{inspect(path)}" | errors]

  defp validate_step_fields("navigate", step, path, errors), do: require_field(step, "to", path, errors)
  defp validate_step_fields("patch", step, path, errors), do: require_field(step, "to", path, errors)
  defp validate_step_fields("redirect", step, path, errors), do: require_field(step, "to", path, errors)
  defp validate_step_fields("open_url", step, path, errors), do: require_field(step, "url", path, errors)
  defp validate_step_fields("submit", step, path, errors) do
    errors = require_field(step, "endpoint", path, errors)
    require_field(step, "query", path, errors) |> require_field_alt(step, "operation", path)
  end
  defp validate_step_fields("fetch", step, path, errors) do
    errors = require_field(step, "endpoint", path, errors)
    require_field(step, "query", path, errors) |> require_field_alt(step, "operation", path)
  end
  defp validate_step_fields("set_state", step, path, errors) do
    require_field(step, "key", path, errors)
  end
  defp validate_step_fields("toggle_state", step, path, errors), do: require_field(step, "key", path, errors)
  defp validate_step_fields("add_class", step, path, errors) do
    errors = require_field(step, "target", path, errors)
    require_field(step, "class", path, errors)
  end
  defp validate_step_fields("remove_class", step, path, errors) do
    errors = require_field(step, "target", path, errors)
    require_field(step, "class", path, errors)
  end
  defp validate_step_fields("toggle_class", step, path, errors) do
    errors = require_field(step, "target", path, errors)
    require_field(step, "class", path, errors)
  end
  defp validate_step_fields("set_attribute", step, path, errors) do
    errors = require_field(step, "target", path, errors)
    errors = require_field(step, "attr", path, errors)
    require_field(step, "value", path, errors)
  end
  defp validate_step_fields("remove_attribute", step, path, errors) do
    errors = require_field(step, "target", path, errors)
    require_field(step, "attr", path, errors)
  end
  defp validate_step_fields("flash", step, path, errors) do
    errors = require_field(step, "kind", path, errors)
    require_field(step, "message", path, errors)
  end
  defp validate_step_fields("conditional", step, path, errors), do: require_field(step, "test", path, errors)
  defp validate_step_fields("custom", step, path, errors), do: require_field(step, "handler", path, errors)
  defp validate_step_fields("dispatch_event", step, path, errors), do: require_field(step, "event", path, errors)
  defp validate_step_fields("push_event", step, path, errors), do: require_field(step, "event", path, errors)
  defp validate_step_fields("track", step, path, errors), do: require_field(step, "event", path, errors)
  defp validate_step_fields(_, _step, _path, errors), do: errors

  defp require_field(step, field, path, errors) do
    if Map.has_key?(step, field) do
      errors
    else
      ["\"#{field}\" is required for action at #{inspect(path)}" | errors]
    end
  end

  defp require_field_alt(errors, step, field, _path) do
    # If there are already errors about the primary field and the alt exists, remove them
    if Map.has_key?(step, field), do: [], else: errors
  end

  defp extract_endpoint_names([], acc), do: Enum.uniq(acc)
  defp extract_endpoint_names([%{"endpoint" => name} = step | rest], acc) do
    acc = [name | acc]
    acc = extract_endpoint_names(step["on_success"] || [], acc)
    acc = extract_endpoint_names(step["on_error"] || [], acc)
    acc = extract_endpoint_names(step["then"] || [], acc)
    acc = extract_endpoint_names(step["else"] || [], acc)
    acc = extract_endpoint_names(step["steps"] || [], acc)
    extract_endpoint_names(rest, acc)
  end
  defp extract_endpoint_names([step | rest], acc) when is_map(step) do
    acc = extract_endpoint_names(step["on_success"] || [], acc)
    acc = extract_endpoint_names(step["on_error"] || [], acc)
    acc = extract_endpoint_names(step["then"] || [], acc)
    acc = extract_endpoint_names(step["else"] || [], acc)
    acc = extract_endpoint_names(step["steps"] || [], acc)
    extract_endpoint_names(rest, acc)
  end
  defp extract_endpoint_names([_ | rest], acc), do: extract_endpoint_names(rest, acc)
end
