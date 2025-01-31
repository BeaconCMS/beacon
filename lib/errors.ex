defmodule Beacon.ConfigError do
  @moduledoc """
  Raised when some option in `Beacon.Config` is invalid.

  If you are seeing this error, check `application.ex` where your site's config is defined.
  Description and examples of each allowed configuration option can be found in `Beacon.Config.new/1`
  """

  defexception message: "error in Beacon.Config"
end

defmodule Beacon.LoaderError do
  @moduledoc """
  Raised when Beacon attempts to load content into memory unsuccessfully.

  There are several causes that can lead to this error, so if you're seeing it, be sure to read the
  full error message for any additional information or steps to take.  If a LoaderError is crashing
  your app on startup, it could indicate a problem in your `Beacon.Config`
  """

  defexception message: "error in Beacon.Loader", plug_status: 404
end

defmodule Beacon.RuntimeError do
  @moduledoc """
  Raised when Beacon attempts to read content from memory unsuccessfully.

  If you see this error consistently, check the message to see if `handle_event` is mentioned.
  If so, this can indicate that pages on your site are sending events (e.g. button clicks,
  form submissions) to an event handler which hasn't been implemented, or that the event name
  does not match your handler.
  """

  defexception message: "runtime error in Beacon", plug_status: 404
end

defmodule Beacon.InvokeError do
  @moduledoc """
  Raised when Beacon attempts to `apply` a module/function/arguments unsuccessfully.

  If you see this error consistently, make sure the resource being called is created and published,
  otherwise that might be a bug in Beacon.
  """

  defexception site: nil, error: nil, module: nil, function: nil, args: [], context: nil, message: "error applying function", plug_status: 404

  @impl true
  def message(%{site: site, module: module, function: function, args: args, context: context}) do
    mfa = Exception.format_mfa(module, function, length(args))

    if context do
      """
      error applying #{mfa} on site #{site}

      Context:

        #{inspect(context)}

      """
    else
      "error applying #{mfa} on site #{site}"
    end
  end
end

defmodule Beacon.ParserError do
  @moduledoc """
  Raised when Beacon's Markdown engine attempts to convert Markdown to HTML unsuccessfully.

  This error can be triggered by layouts, pages, and any other resource that display HTML.
  If you're seeing it, ensure that your template formats are correct. The full error message
  will have details on where to look.
  """

  defexception message: "error parsing template"
end

defmodule Beacon.SnippetError do
  @moduledoc """
  Raised when Beacon attempts to render a `Beacon.Content.Snippets.Helper` unsuccessfully.

  If you're seeing this error, check for typos in your helpers' `:body`.
  """

  defexception [:message]

  @type t() :: %__MODULE__{
          message: String.t()
        }

  @impl true
  def exception(%Solid.TemplateError{} = error) do
    message = Exception.message(error)
    %__MODULE__{message: message}
  end

  def exception(error) when is_binary(error), do: %__MODULE__{message: error}
  def exception(_error), do: %__MODULE__{message: "failed to process snippet"}
end

defmodule Beacon.Web.NotFoundError do
  @moduledoc """
  Raised when Beacon attempts to serve a page or asset on an invalid path.

  If you're seeing this error, it means some of your users are using the wrong URL.
  To some extent, this is unavoidable, but consistently seeing this error with the same path
  can indicate that somewhere in your page content, you are creating invalid links.
  """

  defexception [:message, plug_status: 404]
end

defmodule Beacon.Web.ServerError do
  @moduledoc """
  Raised when a `Beacon.Content.EventHandler` or a `Beacon.Content.InfoHandler` returns an invalid response.

  If you're seeing this error, check the code in your site's event handlers or info handlers, and
  ensure that each one returns `{:noreply, socket}`.
  """

  defexception [:message, plug_status: 500]
end
