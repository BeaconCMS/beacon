defmodule Mix.Tasks.Beacon.CreateAdmin do
  @shortdoc "Creates a Beacon super admin user"

  @moduledoc """
  Creates a new Beacon super admin user.

  ## Usage

      mix beacon.create_admin --email admin@example.com --name "Admin User"

  In dev mode, you can also set a password:

      mix beacon.create_admin --email admin@example.com --name "Admin" --password secret123

  ## Options

    * `--email` (required) - The admin user's email address
    * `--name` - The admin user's display name
    * `--password` - A password for local login (dev mode only, min 8 chars)

  """

  use Mix.Task

  @requirements ["app.start"]

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [email: :string, name: :string, password: :string]
      )

    email = opts[:email] || Mix.raise("--email is required")
    name = opts[:name]

    Mix.shell().info("Creating Beacon super admin user: #{email}")

    case Beacon.Auth.create_user(%{email: email, name: name}) do
      {:ok, user} ->
        case Beacon.Auth.assign_role(user, "super_admin") do
          {:ok, _role} ->
            Mix.shell().info("Super admin role assigned.")

          {:error, changeset} ->
            Mix.raise("Failed to assign super_admin role: #{inspect(changeset.errors)}")
        end

        if password = opts[:password] do
          case Beacon.Auth.set_password(user, password) do
            {:ok, _user} ->
              Mix.shell().info("Password set successfully.")

            {:error, changeset} ->
              Mix.raise("Failed to set password: #{inspect(changeset.errors)}")
          end
        end

        Mix.shell().info("Done! User #{email} is now a super admin.")

      {:error, changeset} ->
        Mix.raise("Failed to create user: #{inspect(changeset.errors)}")
    end
  end
end
