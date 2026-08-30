# Credo runs in strict mode, so `mix credo` locally reports exactly what CI
# reports. The settings below are the ones this repository pins on purpose;
# everything else is Credo's own default.
#
# Waived checks carry the reason and the number of sites they fired on when the
# waiver was written. The list is allowed to shrink and not to grow.
%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["lib/", "src/", "test/", "config/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: %{
        extra: [
          # Classic McCabe cyclomatic complexity, at the ceiling shared by every
          # project in this family, in Elixir and in JavaScript alike.
          {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 9},
          # Credo's strict default, or `line_length` from .formatter.exs where
          # that is larger, so the formatter and the linter cannot disagree
          # about a line the formatter itself produced.
          {Credo.Check.Readability.MaxLineLength, max_length: 150}
        ],
        disabled: [
          # TODO and FIXME notes are tracked in the issue tracker. Failing a
          # build on one only encourages deleting the note.
          {Credo.Check.Design.TagTODO, []},
          {Credo.Check.Design.TagFIXME, []},
          # 109 sites. Whether a call is written out or aliased is a question of
          # naming, not of complexity, and a sweep would touch most files in the
          # tree at once. Worth doing as a change of its own.
          {Credo.Check.Design.AliasUsage, []},
          # 1 site: `Beacon.Config`, at 42 fields. That struct is the site
          # configuration; every field is one documented option, and splitting
          # it would change the public API rather than reduce anything.
          {Credo.Check.Warning.StructFieldAmount, []}
        ]
      }
    }
  ]
}
