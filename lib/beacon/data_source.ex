defmodule Beacon.DataSource do
  @moduledoc false

  @behaviour Beacon.DataSource.Behaviour

  def live_data(site, path, params) do
    user_data_source_mod = get_data_source(site)

    if user_data_source_mod && is_atom(user_data_source_mod) do
      user_data_source_mod.live_data(site, path, params)
    else
      %{}
    end
  rescue
    error in FunctionClauseError ->
      args = pop_args_from_stacktrace(__STACKTRACE__)
      function_arity = "#{error.function}/#{error.arity}"

      error_message = """
      Could not find #{function_arity} that matches the given args: \
      #{inspect(args)}.

      Make sure you have defined a implemention of Beacon.DataSource.#{function_arity} \
      that matches these args.\
      """

      reraise Beacon.DataSourceError, [message: error_message], __STACKTRACE__

    error ->
      reraise error, __STACKTRACE__
  end

  def page_title(site, path, params, live_data, page_title) do
    user_data_source_mod = get_data_source(site)

    if user_data_source_mod && function_exported?(user_data_source_mod, :page_title, 2) do
      user_data_source_mod.page_title(site, %{
        path: path,
        params: params,
        beacon_live_data: live_data,
        page_title: page_title
      })
    else
      page_title
    end
  rescue
    error ->
      stacktrace = __STACKTRACE__

      error_message = """
      Exception caught during execution of page_title/2 for site #{inspect(site)}:

      #{Exception.format(:error, error)}.
      """

      reraise Beacon.DataSourceError, [message: error_message], stacktrace
  end

  def meta_tags(site, path, params, live_data, meta_tags) do
    user_data_source_mod = get_data_source(site)

    if user_data_source_mod && function_exported?(user_data_source_mod, :meta_tags, 2) do
      user_data_source_mod.meta_tags(site, %{
        path: path,
        params: params,
        beacon_live_data: live_data,
        meta_tags: meta_tags
      })
    else
      meta_tags
    end
  rescue
    _error -> meta_tags
  end

  defp get_data_source(site) do
    Beacon.Config.fetch!(site).data_source
  end

  defp pop_args_from_stacktrace(stacktrace) do
    Enum.find_value(stacktrace, [], fn
      {_module, :live_data, args, _file_info} -> args
      _ -> []
    end)
  end
end
