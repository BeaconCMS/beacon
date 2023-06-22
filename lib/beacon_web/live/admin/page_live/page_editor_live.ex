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
      |> assign(:pending_template, page.pending_template)
      |> assign(:raw_schema, Jason.encode!(page.raw_schema, pretty: true))
      |> assign_form(changeset)
      |> assign_extra_fields(changeset)
      |> assign_site_layotus()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"page" => page_params, "save" => ""}, socket) do
    save_page(socket, page_params, false)
  end

  def handle_event("save", %{"page" => page_params, "publish" => ""}, socket) do
    save_page(socket, page_params, true)
  end

  def handle_event("validate", %{"_target" => ["live_monaco_editor", "template"]}, socket) do
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
    {:noreply, assign(socket, :pending_template, value)}
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

  defp save_page(socket, params, publish?) do
    page = socket.assigns.page

    params =
      params
      |> MetaTagsInputs.coerce_meta_tag_param("meta_tags")
      |> Map.put("pending_template", socket.assigns.pending_template)
      |> Map.put("raw_schema", socket.assigns.raw_schema)

    update_page = fn page, params -> Content.update_page(page, params) end

    maybe_publish_page = fn page, publish? ->
      if publish? do
        Content.publish_page(page)
      else
        {:ok, page}
      end
    end

    with {:ok, page} <- update_page.(page, params),
         {:ok, page} <- maybe_publish_page.(page, publish?) do
      page = Content.get_page!(page.id)
      changeset = Content.change_page(page)

      message =
        if publish? do
          "Page published successfully"
        else
          "Page updated successfully"
        end

      {:noreply,
       socket
       |> put_flash(:info, message)
       |> assign(:page, page)
       |> assign_form(changeset)
       |> assign_extra_fields(changeset)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign_form(changeset)
         |> assign_extra_fields(changeset)}

      _error ->
        {:noreply, put_flash(socket, :error, "Failed to update page")}
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
end
