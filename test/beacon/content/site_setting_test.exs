defmodule Beacon.Content.SiteSettingTest do
  use Beacon.DataCase

  alias Beacon.Content
  alias Beacon.Content.SiteSetting

  describe "create_site_setting/1" do
    test "creates a site setting with valid attrs" do
      assert {:ok, %SiteSetting{} = setting} =
               Content.create_site_setting(%{
                 site: :my_site,
                 key: "notification_template",
                 value: "<div>Hello</div>",
                 format: :heex,
                 description: "Test setting"
               })

      assert setting.site == :my_site
      assert setting.key == "notification_template"
      assert setting.value == "<div>Hello</div>"
      assert setting.format == :heex
      assert setting.description == "Test setting"
    end

    test "fails with invalid key" do
      assert {:error, changeset} =
               Content.create_site_setting(%{
                 site: :my_site,
                 key: "invalid-key!",
                 value: "some value"
               })

      assert %{key: [_msg]} = errors_on(changeset)
    end

    test "fails without required fields" do
      assert {:error, changeset} =
               Content.create_site_setting(%{site: :my_site})

      errors = errors_on(changeset)
      assert Map.has_key?(errors, :key)
      assert Map.has_key?(errors, :value)
    end

    test "fails with invalid format" do
      assert {:error, changeset} =
               Content.create_site_setting(%{
                 site: :my_site,
                 key: "test_key",
                 value: "some value",
                 format: :invalid
               })

      assert %{format: [_msg]} = errors_on(changeset)
    end
  end

  describe "get_site_setting/2" do
    test "returns the setting for existing key" do
      {:ok, created} =
        Content.create_site_setting(%{
          site: :my_site,
          key: "test_setting",
          value: "test_value"
        })

      setting = Content.get_site_setting(:my_site, "test_setting")
      assert setting.id == created.id
      assert setting.key == "test_setting"
      assert setting.value == "test_value"
    end

    test "returns nil for nonexistent key" do
      assert Content.get_site_setting(:my_site, "nonexistent") == nil
    end
  end

  describe "get_site_setting_value/2" do
    test "returns the stored value" do
      {:ok, _setting} =
        Content.create_site_setting(%{
          site: :my_site,
          key: "custom_key",
          value: "custom_value"
        })

      assert Content.get_site_setting_value(:my_site, "custom_key") == "custom_value"
    end

    test "returns default for known key when no setting exists" do
      value = Content.get_site_setting_value(:my_site, "notification_template")
      assert value == SiteSetting.default_notification_template()
    end

    test "returns nil for unknown key when no setting exists" do
      assert Content.get_site_setting_value(:my_site, "totally_unknown") == nil
    end
  end

  describe "update_site_setting/2" do
    test "updates the setting value" do
      {:ok, setting} =
        Content.create_site_setting(%{
          site: :my_site,
          key: "update_test",
          value: "original"
        })

      assert {:ok, updated} = Content.update_site_setting(setting, %{value: "updated"})
      assert updated.value == "updated"
      assert updated.id == setting.id
    end
  end

  describe "list_site_settings/1" do
    test "lists all settings for a site" do
      {:ok, _} = Content.create_site_setting(%{site: :my_site, key: "alpha", value: "1"})
      {:ok, _} = Content.create_site_setting(%{site: :my_site, key: "beta", value: "2"})

      settings = Content.list_site_settings(:my_site)
      keys = Enum.map(settings, & &1.key)
      assert "alpha" in keys
      assert "beta" in keys
    end

    test "returns empty list when no settings exist" do
      assert Content.list_site_settings(:my_site) == []
    end
  end

  describe "delete_site_setting/1" do
    test "deletes a setting" do
      {:ok, setting} =
        Content.create_site_setting(%{
          site: :my_site,
          key: "delete_test",
          value: "to_delete"
        })

      assert {:ok, _deleted} = Content.delete_site_setting(setting)
      assert Content.get_site_setting(:my_site, "delete_test") == nil
    end
  end

  describe "change_site_setting/2" do
    test "returns a changeset" do
      setting = %SiteSetting{}
      changeset = Content.change_site_setting(setting, %{key: "test", value: "val"})
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "default_notification_template/0" do
    test "returns the default HEEx template" do
      template = SiteSetting.default_notification_template()
      assert is_binary(template)
      assert template =~ "beacon-update-notification"
      assert template =~ "beacon:apply-update"
      assert template =~ "beacon:dismiss-update"
    end
  end

  describe "known_keys/0" do
    test "includes notification_template" do
      keys = SiteSetting.known_keys()
      assert Map.has_key?(keys, "notification_template")
      assert %{default: _, format: :heex, description: _} = keys["notification_template"]
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
