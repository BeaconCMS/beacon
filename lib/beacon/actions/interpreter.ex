defmodule Beacon.Actions.Interpreter do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3], warn: false
  import Phoenix.LiveView, only: [push_navigate: 2, push_patch: 2, redirect: 2, push_event: 3, put_flash: 3], warn: false

  alias Beacon.GraphQL.Client

  require Logger

  @max_steps 100

  @doc """
  Execute an action document against a LiveView socket.

  Returns `{:noreply, socket}`.
  """
  @spec execute(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def execute(%{"version" => 1, "steps" => steps}, event_params, socket) when is_list(steps) do
    ctx = %{
      socket: socket,
      event_params: event_params,
      state: %{},
      step_count: 0,
      fetch_results: %{},
      site: socket.assigns.beacon.site
    }

    ctx = execute_steps(steps, ctx)
    {:noreply, ctx.socket}
  end

  def execute(%{"steps" => steps}, event_params, socket) when is_list(steps) do
    # Accept documents without explicit version (default to v1)
    execute(%{"version" => 1, "steps" => steps}, event_params, socket)
  end

  def execute(invalid, _event_params, _socket) do
    raise Beacon.Web.ServerError,
          "invalid action document: expected %{\"version\" => 1, \"steps\" => [...]}, got: #{inspect(invalid)}"
  end

  defp execute_steps(steps, ctx) do
    Enum.reduce_while(steps, ctx, fn step, ctx ->
      if ctx.step_count >= @max_steps do
        Logger.error("[Beacon.Actions] Step limit (#{@max_steps}) exceeded, aborting")
        {:halt, ctx}
      else
        ctx = %{ctx | step_count: ctx.step_count + 1}
        {:cont, execute_step(step, ctx)}
      end
    end)
  end

  # -- Navigation --

  defp execute_step(%{"action" => "navigate", "to" => to}, ctx) do
    %{ctx | socket: push_navigate(ctx.socket, to: resolve_value(to, ctx))}
  end

  defp execute_step(%{"action" => "patch", "to" => to}, ctx) do
    %{ctx | socket: push_patch(ctx.socket, to: resolve_value(to, ctx))}
  end

  defp execute_step(%{"action" => "redirect", "to" => to}, ctx) do
    %{ctx | socket: redirect(ctx.socket, to: resolve_value(to, ctx))}
  end

  defp execute_step(%{"action" => "open_url", "url" => url}, ctx) do
    %{ctx | socket: push_event(ctx.socket, "beacon:open_url", %{url: resolve_value(url, ctx)})}
  end

  defp execute_step(%{"action" => "scroll_to", "target" => target}, ctx) do
    %{ctx | socket: push_event(ctx.socket, "beacon:scroll_to", %{target: target})}
  end

  defp execute_step(%{"action" => "dismiss"}, ctx) do
    %{ctx | socket: push_event(ctx.socket, "beacon:dismiss", %{})}
  end

  # -- Data (GraphQL) --

  defp execute_step(%{"action" => action, "endpoint" => endpoint} = step, ctx)
       when action in ["submit", "fetch"] do
    query = step["query"] || step["operation"]
    variables = resolve_variables(step["variables"] || %{}, ctx)
    result_key = step["result"]

    case Client.execute(ctx.site, endpoint, query, variables) do
      {:ok, data} ->
        ctx = if result_key, do: put_in(ctx, [:fetch_results, result_key], data), else: ctx
        execute_branch(step["on_success"], ctx)

      {:partial, data, _errors} ->
        ctx = if result_key, do: put_in(ctx, [:fetch_results, result_key], data), else: ctx
        execute_branch(step["on_success"], ctx)

      {:error, reason} ->
        Logger.warning("[Beacon.Actions] #{action} failed: #{inspect(reason)}")
        ctx = %{ctx | state: Map.put(ctx.state, "error", %{"message" => inspect(reason)})}
        execute_branch(step["on_error"], ctx)
    end
  end

  # -- State --

  defp execute_step(%{"action" => "set_state", "key" => key, "value" => value}, ctx) do
    resolved = resolve_value(value, ctx)
    assign_key = String.to_atom(key)
    ctx = %{ctx | state: Map.put(ctx.state, key, resolved)}
    %{ctx | socket: assign(ctx.socket, assign_key, resolved)}
  end

  defp execute_step(%{"action" => "toggle_state", "key" => key}, ctx) do
    current = Map.get(ctx.state, key, false)
    new_val = !current
    assign_key = String.to_atom(key)
    ctx = %{ctx | state: Map.put(ctx.state, key, new_val)}
    %{ctx | socket: assign(ctx.socket, assign_key, new_val)}
  end

  # -- DOM --

  defp execute_step(%{"action" => "show"} = step, ctx) do
    js_cmd = Phoenix.LiveView.JS.show(target_opts(step))
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  defp execute_step(%{"action" => "hide"} = step, ctx) do
    js_cmd = Phoenix.LiveView.JS.hide(target_opts(step))
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  defp execute_step(%{"action" => "toggle"} = step, ctx) do
    js_cmd = Phoenix.LiveView.JS.toggle(target_opts(step))
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  defp execute_step(%{"action" => "add_class", "target" => target, "class" => class}, ctx) do
    js_cmd = Phoenix.LiveView.JS.add_class(class, to: target)
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  defp execute_step(%{"action" => "remove_class", "target" => target, "class" => class}, ctx) do
    js_cmd = Phoenix.LiveView.JS.remove_class(class, to: target)
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  defp execute_step(%{"action" => "toggle_class", "target" => target, "class" => class}, ctx) do
    js_cmd = Phoenix.LiveView.JS.toggle_class(class, to: target)
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  defp execute_step(%{"action" => "set_attribute", "target" => target, "attr" => attr, "value" => value}, ctx) do
    js_cmd = Phoenix.LiveView.JS.set_attribute({attr, resolve_value(value, ctx)}, to: target)
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  defp execute_step(%{"action" => "remove_attribute", "target" => target, "attr" => attr}, ctx) do
    js_cmd = Phoenix.LiveView.JS.remove_attribute(attr, to: target)
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  defp execute_step(%{"action" => "transition", "target" => target, "class" => class} = step, ctx) do
    time = step["time"] || 200
    js_cmd = Phoenix.LiveView.JS.transition(class, to: target, time: time)
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  defp execute_step(%{"action" => "focus", "target" => target}, ctx) do
    js_cmd = Phoenix.LiveView.JS.focus(to: target)
    %{ctx | socket: push_event(ctx.socket, "beacon:js", %{ops: js_cmd.ops})}
  end

  # -- Feedback --

  defp execute_step(%{"action" => "flash", "kind" => kind, "message" => message}, ctx) do
    %{ctx | socket: put_flash(ctx.socket, String.to_atom(kind), resolve_value(message, ctx))}
  end

  defp execute_step(%{"action" => "dispatch_event", "event" => event} = step, ctx) do
    detail = step["detail"] || %{}
    %{ctx | socket: push_event(ctx.socket, "beacon:dispatch", %{event: event, detail: detail})}
  end

  defp execute_step(%{"action" => "push_event", "event" => event} = step, ctx) do
    payload = resolve_variables(step["payload"] || %{}, ctx)
    %{ctx | socket: push_event(ctx.socket, event, payload)}
  end

  defp execute_step(%{"action" => "track", "event" => event} = step, ctx) do
    properties = step["properties"] || %{}
    %{ctx | socket: push_event(ctx.socket, "beacon:track", %{event: event, properties: properties})}
  end

  # -- Forms --

  defp execute_step(%{"action" => "validate", "form" => _form} = step, ctx) do
    # Validation is primarily client-side. Push the rules to the client.
    rules = step["rules"] || %{}
    %{ctx | socket: push_event(ctx.socket, "beacon:validate", %{form: step["form"], rules: rules})}
  end

  # -- Control flow --

  defp execute_step(%{"action" => "conditional", "test" => test} = step, ctx) do
    if evaluate_test(test, ctx) do
      execute_branch(step["then"], ctx)
    else
      execute_branch(step["else"], ctx)
    end
  end

  defp execute_step(%{"action" => "sequence", "steps" => steps}, ctx) do
    execute_steps(steps, ctx)
  end

  # -- Escape hatch --

  defp execute_step(%{"action" => "custom", "handler" => handler_name} = step, ctx) do
    params = Map.merge(ctx.event_params, step["params"] || %{})

    # Only dispatch to :elixir format handlers to prevent infinite recursion
    table = :beacon_runtime_poc
    key = {ctx.site, :site_handler, :event, handler_name}

    case :ets.lookup(table, key) do
      [{_, {:elixir, _} = tagged}] ->
        case Beacon.RuntimeRenderer.dispatch_tagged_handler(tagged, params, ctx.socket) do
          {:noreply, socket} -> %{ctx | socket: socket}
          _ -> ctx
        end

      [{_, {:actions, _}}] ->
        Logger.warning("[Beacon.Actions] Custom handler '#{handler_name}' is itself an actions handler — skipping to prevent recursion")
        ctx

      _ ->
        Logger.warning("[Beacon.Actions] Custom handler '#{handler_name}' not found")
        ctx
    end
  end

  # -- Unknown action (no-op with warning) --

  defp execute_step(%{"action" => action}, ctx) do
    Logger.warning("[Beacon.Actions] Unknown action type: #{action}")
    ctx
  end

  # -- Helpers --

  defp execute_branch(nil, ctx), do: ctx
  defp execute_branch(steps, ctx) when is_list(steps), do: execute_steps(steps, ctx)

  defp target_opts(%{"target" => target}), do: [to: target]
  defp target_opts(_), do: []

  defp resolve_value(value, _ctx) when is_number(value) or is_boolean(value), do: value
  defp resolve_value(nil, _ctx), do: nil

  defp resolve_value(value, ctx) when is_binary(value) do
    cond do
      String.starts_with?(value, "$event_params.") ->
        path = String.trim_leading(value, "$event_params.") |> String.split(".")
        get_nested(ctx.event_params, path)

      String.starts_with?(value, "$state.") ->
        path = String.trim_leading(value, "$state.") |> String.split(".")
        get_nested(ctx.state, path)

      String.starts_with?(value, "$result.") ->
        path = String.trim_leading(value, "$result.") |> String.split(".")
        get_nested(ctx.fetch_results, path)

      String.starts_with?(value, "$error.") ->
        path = String.trim_leading(value, "$error.") |> String.split(".")
        get_nested(ctx.state, ["error" | path])

      true ->
        value
    end
  end

  defp resolve_value(value, _ctx) when is_map(value), do: value
  defp resolve_value(value, _ctx) when is_list(value), do: value

  defp resolve_variables(variables, ctx) when is_map(variables) do
    Map.new(variables, fn
      {key, %{"source" => "event_param", "key" => param_key}} ->
        {key, get_nested(ctx.event_params, String.split(param_key, "."))}

      {key, %{"source" => "state", "key" => state_key}} ->
        {key, Map.get(ctx.state, state_key)}

      {key, %{"source" => "literal", "value" => value}} ->
        {key, value}

      {key, %{"source" => "result", "from" => from, "path" => path}} ->
        {key, get_nested(ctx.fetch_results, [from | String.split(path, ".")])}

      {key, value} ->
        {key, resolve_value(value, ctx)}
    end)
  end

  defp evaluate_test(%{"path" => path, "op" => op, "value" => expected}, ctx) do
    actual = resolve_value("$" <> path, ctx)

    case op do
      "eq" -> actual == expected
      "neq" -> actual != expected
      "gt" -> is_number(actual) and actual > expected
      "lt" -> is_number(actual) and actual < expected
      "gte" -> is_number(actual) and actual >= expected
      "lte" -> is_number(actual) and actual <= expected
      "contains" -> is_binary(actual) and String.contains?(actual, expected)
      "exists" -> actual != nil
      "not_exists" -> actual == nil
      _ -> false
    end
  end

  defp evaluate_test(%{"field" => field, "op" => op, "value" => expected}, ctx) do
    evaluate_test(%{"path" => field, "op" => op, "value" => expected}, ctx)
  end

  defp evaluate_test(_, _ctx), do: false

  defp get_nested(nil, _), do: nil
  defp get_nested(value, []), do: value
  defp get_nested(value, [key | rest]) when is_map(value) do
    get_nested(Map.get(value, key) || Map.get(value, String.to_atom(key)), rest)
  end
  defp get_nested(_, _), do: nil
end
