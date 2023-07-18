defmodule BeaconWeb.Admin.PageEditorLive do
  use BeaconWeb, :live_view

  alias Beacon.Content
  alias BeaconWeb.Admin.PageLive.MetaTagsInputs

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    page = Content.get_page!(id)
    changeset = Content.change_page(page)

    socket =
      socket
      |> assign(:page_id, id)
      |> assign(:new_attribute_modal_visible?, false)
      |> assign(:extra_meta_attributes, [])
      |> assign(:page, page)
      |> assign(:initial_language, language(page.format))
      |> assign(:template, page.template)
      |> assign(:raw_schema, Jason.encode!(page.raw_schema, pretty: true))
      |> assign_form(changeset)
      |> assign_extra_fields(changeset)
      |> assign_page_status(page)
      |> assign_site_layotus()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"page" => page_params, "save" => ""}, socket) do
    save_page(socket, page_params)
  end

  def handle_event("save", %{"page" => page_params, "publish" => ""}, socket) do
    save_and_publish_page(socket, page_params)
  end

  def handle_event("validate", %{"_target" => ["live_monaco_editor", _]}, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", %{"_target" => ["page", "format"], "page" => %{"format" => format}}, socket) do
    socket = LiveMonacoEditor.change_language(socket, language(format), to: "template")
    {:noreply, socket}
  end

  def handle_event("validate", %{"page" => page_params}, socket) do
    {extra_params, page_params} = Map.pop(page_params, "extra")
    page_params = MetaTagsInputs.coerce_meta_tag_param(page_params, "meta_tags")

    changeset =
      socket.assigns.page
      |> Content.change_page(page_params)
      |> Map.put(:action, :validate)
      |> Content.PageField.apply_changesets(socket.assigns.page.site, extra_params)

    {:noreply,
     socket
     |> assign_form(changeset)
     |> assign_extra_fields(changeset)}
  end

  def handle_event("template_editor_lost_focus", %{"value" => value}, socket) do
    {:noreply, assign(socket, :template, value)}
  end

  def handle_event("raw_schema_editor_lost_focus", %{"value" => value}, socket) do
    {:noreply, assign(socket, :raw_schema, value)}
  end

  def handle_event("show-new-attribute-modal", _, socket) do
    {:noreply, assign(socket, :new_attribute_modal_visible?, true)}
  end

  def handle_event("hide-new-attribute-modal", _, socket) do
    {:noreply, assign(socket, :new_attribute_modal_visible?, false)}
  end

  def handle_event("save-new-attribute", %{"attribute" => %{"name" => name}}, socket) do
    # Basic validation
    attributes =
      case String.trim(name) do
        "" -> socket.assigns.extra_meta_attributes
        name -> Enum.uniq(socket.assigns.extra_meta_attributes ++ [name])
      end

    {:noreply, assign(socket, extra_meta_attributes: attributes, new_attribute_modal_visible?: false)}
  end

  defp save_page(socket, params) do
    case do_save_page(socket, params) do
      {:ok, {socket, _page}} ->
        {:noreply, put_flash(socket, :info, "Page updated successfully")}

      {:error, {socket, _page}} ->
        {:noreply, put_flash(socket, :error, "Failed to updated page")}
    end
  end

  defp save_and_publish_page(socket, params) do
    with {:ok, {socket, page}} <- do_save_page(socket, params),
         {:ok, _page} <- Content.publish_page(page) do
      {:noreply,
       socket
       |> assign_page_status(page)
       |> put_flash(:info, "Page published successfully")}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to publish page")}
    end
  end

  defp do_save_page(socket, params) do
    page = socket.assigns.page

    params =
      params
      |> MetaTagsInputs.coerce_meta_tag_param("meta_tags")
      |> Map.put("template", socket.assigns.template)
      |> Map.put("raw_schema", socket.assigns.raw_schema)

    case Content.update_page(page, params) do
      {:ok, page} ->
        changeset = Content.change_page(page)

        socket =
          socket
          |> assign(:page, page)
          |> assign_form(changeset)
          |> assign_extra_fields(changeset)

        {:ok, {socket, page}}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign_form(changeset)
          |> assign_extra_fields(changeset)

        {:error, {socket, page}}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp assign_extra_fields(socket, changeset) do
    params = Ecto.Changeset.get_field(changeset, :extra)
    extra_fields = Content.PageField.extra_fields(socket.assigns.page.site, socket.assigns.form, params, changeset.errors)
    assign(socket, :extra_fields, extra_fields)
  end

  defp assign_page_status(socket, page) do
    status = Content.get_latest_page_event(page.site, page.id)
    assign(socket, :page_status, status.event)
  end

  defp assign_site_layotus(socket) do
    site = socket.assigns.page.site
    assign(socket, site_layouts: Content.list_layouts(site))
  end

  defp layouts_to_options(layouts) do
    Enum.map(layouts, fn %Content.Layout{id: id, title: title} ->
      {title, id}
    end)
  end

  defp template_format_options(form) do
    site = Ecto.Changeset.get_field(form.source, :site)

    if site do
      Keyword.new(
        Beacon.Config.fetch!(site).template_formats,
        fn {identifier, description} ->
          {String.to_atom(description), identifier}
        end
      )
    else
      []
    end
  end

  defp extra_page_field(mod, field, env) do
    Phoenix.LiveView.TagEngine.component(
      &mod.render/1,
      [field: field],
      {env.module, env.function, env.file, env.line}
    )
  end

  defp language("heex" = _format), do: "html"
  defp language(:heex), do: "html"
  defp language(format), do: to_string(format)

  defp template_error(form) do
    errors = form.source.errors

    message =
      case Enum.find(errors, fn {k, _v} -> k == :template end) do
        {:template, {message, _}} -> message
        _ -> nil
      end

    assigns = %{message: message}

    ~H"""
    <code>
      <pre>
    <.error :if={@message}><%= @message %></.error>
    </pre>
    </code>
    """
  end
end
