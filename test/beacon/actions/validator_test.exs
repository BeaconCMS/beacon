defmodule Beacon.Actions.ValidatorTest do
  use ExUnit.Case, async: true

  alias Beacon.Actions.Validator

  describe "validate/1" do
    test "valid document with steps" do
      doc = %{"steps" => [%{"action" => "navigate", "to" => "/home"}]}
      assert :ok = Validator.validate(doc)
    end

    test "valid document with version" do
      doc = %{"version" => 1, "steps" => [%{"action" => "flash", "kind" => "info", "message" => "ok"}]}
      assert :ok = Validator.validate(doc)
    end

    test "rejects missing steps" do
      assert {:error, _} = Validator.validate(%{})
    end

    test "rejects unknown action type" do
      doc = %{"steps" => [%{"action" => "explode"}]}
      assert {:error, errors} = Validator.validate(doc)
      assert Enum.any?(errors, &String.contains?(&1, "unknown action"))
    end

    test "rejects navigate without to" do
      doc = %{"steps" => [%{"action" => "navigate"}]}
      assert {:error, errors} = Validator.validate(doc)
      assert Enum.any?(errors, &String.contains?(&1, "to"))
    end

    test "rejects flash without kind" do
      doc = %{"steps" => [%{"action" => "flash", "message" => "hi"}]}
      assert {:error, errors} = Validator.validate(doc)
      assert Enum.any?(errors, &String.contains?(&1, "kind"))
    end

    test "rejects submit without endpoint" do
      doc = %{"steps" => [%{"action" => "submit", "query" => "mutation { ... }"}]}
      assert {:error, errors} = Validator.validate(doc)
      assert Enum.any?(errors, &String.contains?(&1, "endpoint"))
    end

    test "validates nested on_success steps" do
      doc = %{"steps" => [
        %{"action" => "submit", "endpoint" => "api", "query" => "...",
          "on_success" => [%{"action" => "navigate", "to" => "/ok"}],
          "on_error" => [%{"action" => "flash", "kind" => "error", "message" => "fail"}]
        }
      ]}
      assert :ok = Validator.validate(doc)
    end

    test "validates conditional with test" do
      doc = %{"steps" => [
        %{"action" => "conditional", "test" => %{"path" => "state.x", "op" => "eq", "value" => true},
          "then" => [%{"action" => "navigate", "to" => "/yes"}],
          "else" => [%{"action" => "navigate", "to" => "/no"}]
        }
      ]}
      assert :ok = Validator.validate(doc)
    end

    test "rejects conditional without test" do
      doc = %{"steps" => [%{"action" => "conditional", "then" => []}]}
      assert {:error, errors} = Validator.validate(doc)
      assert Enum.any?(errors, &String.contains?(&1, "test"))
    end

    test "validates all action types" do
      actions = [
        %{"action" => "navigate", "to" => "/"},
        %{"action" => "patch", "to" => "/"},
        %{"action" => "redirect", "to" => "/"},
        %{"action" => "open_url", "url" => "https://example.com"},
        %{"action" => "scroll_to", "target" => "#top"},
        %{"action" => "dismiss"},
        %{"action" => "set_state", "key" => "x", "value" => 1},
        %{"action" => "toggle_state", "key" => "x"},
        %{"action" => "show"},
        %{"action" => "hide"},
        %{"action" => "toggle"},
        %{"action" => "add_class", "target" => "#el", "class" => "active"},
        %{"action" => "remove_class", "target" => "#el", "class" => "active"},
        %{"action" => "toggle_class", "target" => "#el", "class" => "active"},
        %{"action" => "set_attribute", "target" => "#el", "attr" => "disabled", "value" => "true"},
        %{"action" => "remove_attribute", "target" => "#el", "attr" => "disabled"},
        %{"action" => "transition", "target" => "#el", "class" => "fade-in"},
        %{"action" => "focus", "target" => "#input"},
        %{"action" => "flash", "kind" => "info", "message" => "ok"},
        %{"action" => "dispatch_event", "event" => "click"},
        %{"action" => "push_event", "event" => "update"},
        %{"action" => "track", "event" => "page_view"},
        %{"action" => "validate", "form" => "contact"},
        %{"action" => "conditional", "test" => %{}},
        %{"action" => "sequence", "steps" => []},
        %{"action" => "custom", "handler" => "my_handler"},
        %{"action" => "submit", "endpoint" => "api", "query" => "..."},
        %{"action" => "fetch", "endpoint" => "api", "query" => "..."}
      ]

      doc = %{"steps" => actions}
      assert :ok = Validator.validate(doc)
    end
  end
end
