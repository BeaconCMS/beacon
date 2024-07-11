Application.ensure_all_started(:postgrex)

Beacon.BeaconTest.Repo.start_link()

Application.put_env(:beacon, Beacon.BeaconTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base: "dVxFbSNspBVvkHPN5m6FE6iqNtMnhrmPNw7mO57CJ6beUADllH0ux3nhAI1ic65X",
  live_view: [signing_salt: "ykjYicLHN3EuW0FO"],
  render_errors: [view: Beacon.BeaconTest.ErrorView],
  pubsub_server: Beacon.BeaconTest.PubSub,
  check_origin: false,
  debug_errors: true
)

Supervisor.start_link(
  [
    {Phoenix.PubSub, name: Beacon.BeaconTest.PubSub},
    {Beacon,
     sites: [
       [
         site: :my_site,
         endpoint: Beacon.BeaconTest.Endpoint,
         router: Beacon.BeaconTest.Router,
         repo: Beacon.BeaconTest.Repo,
         skip_boot?: true,
         tailwind_config: Path.join([File.cwd!(), "test", "support", "tailwind.config.templates.js"]),
         live_socket_path: "/custom_live",
         extra_page_fields: [Beacon.BeaconTest.PageFields.TagsField],
         lifecycle: [
           load_template: [
             {:heex,
              [
                tailwind_test: fn
                  template, %{site: :my_site, path: "/tailwind-test-post-process"} ->
                    template = String.replace(template, "text-gray-200", "text-blue-200")
                    {:cont, template}

                  template, _metadata ->
                    {:cont, template}
                end
              ]}
           ]
         ]
       ],
       [
         site: :not_booted,
         skip_boot?: true,
         endpoint: Beacon.BeaconTest.Endpoint,
         router: Beacon.BeaconTest.Router,
         repo: Beacon.BeaconTest.Repo
       ],
       [
         site: :booted,
         skip_boot?: false,
         endpoint: Beacon.BeaconTest.Endpoint,
         router: Beacon.BeaconTest.Router,
         repo: Beacon.BeaconTest.Repo
       ],
       [
         site: :s3_site,
         endpoint: Beacon.BeaconTest.Endpoint,
         router: Beacon.BeaconTest.Router,
         repo: Beacon.BeaconTest.Repo,
         skip_boot?: true,
         assets: [
           {"image/*", [backends: [Beacon.MediaLibrary.Backend.S3, Beacon.MediaLibrary.Backend.Repo], validations: []]}
         ],
         lifecycle: [upload_asset: []]
       ],
       [
         site: :data_source_test,
         skip_boot?: true,
         endpoint: Beacon.BeaconTest.Endpoint,
         router: Beacon.BeaconTest.Router,
         repo: Beacon.BeaconTest.Repo
       ],
       [
         site: :raw_schema_test,
         skip_boot?: true,
         endpoint: Beacon.BeaconTest.Endpoint,
         router: Beacon.BeaconTest.Router,
         repo: Beacon.BeaconTest.Repo
       ],
       [
         site: :default_meta_tags_test,
         skip_boot?: true,
         endpoint: Beacon.BeaconTest.Endpoint,
         router: Beacon.BeaconTest.Router,
         repo: Beacon.BeaconTest.Repo,
         default_meta_tags: [
           %{"name" => "foo", "content" => "bar"}
         ]
       ],
       [
         site: :lifecycle_test,
         endpoint: Beacon.BeaconTest.Endpoint,
         router: Beacon.BeaconTest.Router,
         repo: Beacon.BeaconTest.Repo,
         skip_boot?: true,
         lifecycle: [
           load_template: [
             {:markdown,
              [
                assigns: fn template, _metadata -> {:cont, String.replace(template, "{ title }", "Beacon")} end,
                downcase: fn template, _metadata -> {:cont, String.downcase(template)} end
              ]}
           ],
           render_template: [
             {:markdown,
              [
                div_to_p: fn template, _metadata -> {:cont, String.replace(template, "div", "p")} end,
                assigns: fn template, _metadata -> {:cont, String.replace(template, "{ title }", "Beacon")} end,
                compile: fn template, metadata ->
                  {:ok, ast} = Beacon.Template.HEEx.compile(metadata.site, metadata.path, template)
                  {:cont, ast}
                end,
                eval: fn template, _metadata ->
                  {rendered, _bindings} = Code.eval_quoted(template, [assigns: %{}], file: "nofile")
                  {:halt, rendered}
                end
              ]}
           ],
           after_create_page: [
             maybe_create_page: fn page ->
               send(self(), :lifecycle_after_create_page)
               {:cont, page}
             end
           ],
           after_update_page: [
             maybe_update_page: fn page ->
               send(self(), :lifecycle_after_update_page)
               {:cont, page}
             end
           ],
           after_publish_page: [
             maybe_publish_page: fn page ->
               {:ok, page} = Beacon.Content.update_page(page, %{title: "updated after publish page"})
               {:cont, page}
             end
           ]
         ]
       ],
       [
         site: :lifecycle_test_fail,
         endpoint: Beacon.BeaconTest.Endpoint,
         router: Beacon.BeaconTest.Router,
         repo: Beacon.BeaconTest.Repo,
         skip_boot?: true,
         lifecycle: [
           render_template: [
             {:markdown, [assigns: fn template, _metadata -> {:cont, template} end]}
           ]
         ]
       ]
     ],
     authorization_source: Beacon.BeaconTest.BeaconAuthorizationSource},
    Beacon.BeaconTest.Endpoint
  ],
  strategy: :one_for_one
)

# TODO: better control :booted default data when we introduce Beacon.Test functions
Beacon.BeaconTest.Repo.delete_all(Beacon.Content.Component)
Beacon.BeaconTest.Repo.delete_all(Beacon.Content.ErrorPage)
Beacon.BeaconTest.Repo.delete_all(Beacon.Content.Page)
Beacon.BeaconTest.Repo.delete_all(Beacon.Content.Layout)

# TODO: add hooks into Beacon.Testing to reload these shared/global modules
Beacon.Loader.reload_routes_module(:my_site)
Beacon.Loader.reload_routes_module(:not_booted)
Beacon.Loader.reload_routes_module(:booted)
Beacon.Loader.reload_routes_module(:s3_site)
Beacon.Loader.reload_routes_module(:data_source_test)
Beacon.Loader.reload_routes_module(:default_meta_tags_test)
Beacon.Loader.reload_routes_module(:lifecycle_test)
Beacon.Loader.reload_routes_module(:lifecycle_test_fail)
Beacon.Loader.reload_components_module(:my_site)
Beacon.Loader.reload_components_module(:not_booted)
Beacon.Loader.reload_components_module(:booted)
Beacon.Loader.reload_components_module(:s3_site)
Beacon.Loader.reload_components_module(:data_source_test)
Beacon.Loader.reload_components_module(:default_meta_tags_test)
Beacon.Loader.reload_components_module(:lifecycle_test)
Beacon.Loader.reload_components_module(:lifecycle_test_fail)

ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(Beacon.BeaconTest.Repo, :manual)
