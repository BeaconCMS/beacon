defmodule BeaconWeb.Admin.PageEditorLive do
  use BeaconWeb, :live_view

  alias Beacon.Layouts
  alias Beacon.Layouts.Layout
  alias Beacon.Pages

  alias BeaconWeb.Admin.PageLive.MetaTagsInputs

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    page = Pages.get_page!(id, [:versions])
    changeset = Pages.change_page(page)

    socket =
      socket
      |> assign(:page_id, id)
      |> assign(:new_attribute_modal_visible?, false)
      |> assign(:extra_meta_attributes, [])
      |> assign(:page, page)
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

  def handle_event("validate", %{"page" => page_params}, socket) do
    {extra_params, page_params} = Map.pop(page_params, "extra")
    page_params = MetaTagsInputs.coerce_meta_tag_param(page_params, "meta_tags")

    changeset =
      socket.assigns.page
      |> Pages.change_page(page_params)
      |> Map.put(:action, :validate)
      |> Beacon.PageField.apply_changesets(socket.assigns.page.site, extra_params)

    {:noreply,
     socket
     |> assign_form(changeset)
     |> assign_extra_fields(changeset)}
  end

  def handle_event("copy_version", %{"version" => version_str}, socket) do
    version = Enum.find(socket.assigns.page.versions, &(&1.version == String.to_integer(version_str)))

    {:ok, page} =
      Pages.update_page_pending(
        socket.assigns.page,
        version.template,
        socket.assigns.page.layout_id
      )

    changeset = Pages.change_page(page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign_form(changeset)}
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
    params = MetaTagsInputs.coerce_meta_tag_param(params, "meta_tags")

    update_page = fn page, params -> Pages.update_page(page, params) end

    maybe_publish_page = fn page, publish? ->
      if publish? do
        Pages.publish_page(page)
      else
        {:ok, page}
      end
    end

    with {:ok, page} <- update_page.(page, params),
         {:ok, page} <- maybe_publish_page.(page, publish?) do
      page = Pages.get_page!(page.id, [:versions])
      changeset = Pages.change_page(page)

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
    errors = changeset.errors[:extra]
    change = Ecto.Changeset.get_change(changeset, :extra)
    field = Ecto.Changeset.get_field(changeset, :extra)

    # account for validate_required to display empty fields instead of the field value
    extra =
      if errors && is_nil(change) do
        Map.new(field, fn {k, _v} -> {k, nil} end)
      else
        field
      end

    extra_fields = Beacon.PageField.extra_fields(socket.assigns.page.site, socket.assigns.form, extra, errors)
    assign(socket, :extra_fields, extra_fields)
  end

  defp assign_site_layotus(socket) do
    site = socket.assigns.page.site
    assign(socket, site_layouts: Layouts.list_layouts_for_site(site))
  end

  defp layouts_to_options(layouts) do
    Enum.map(layouts, fn %Layout{id: id, title: title} ->
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

  defp sort_page_versions(page_versions) do
    Enum.sort_by(page_versions, & &1.version, :desc)
  end

  defp extra_page_field(mod, field, env) do
    Phoenix.LiveView.TagEngine.component(
      &mod.render/1,
      [field: field],
      {env.module, env.function, env.file, env.line}
    )
  end
end
