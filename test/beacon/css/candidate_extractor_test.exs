defmodule Beacon.CSS.CandidateExtractorTest do
  use ExUnit.Case, async: true

  alias Beacon.CSS.CandidateExtractor

  describe "extract/1" do
    test "extracts basic Tailwind classes from HTML" do
      template = ~s(<div class="flex items-center justify-between p-4">Hello</div>)

      candidates = CandidateExtractor.extract(template)

      assert "flex" in candidates
      assert "items-center" in candidates
      assert "justify-between" in candidates
      assert "p-4" in candidates
    end

    test "extracts responsive variant classes" do
      template = ~s(<div class="sm:flex md:grid lg:hidden xl:block">)

      candidates = CandidateExtractor.extract(template)

      assert "sm:flex" in candidates
      assert "md:grid" in candidates
      assert "lg:hidden" in candidates
      assert "xl:block" in candidates
    end

    test "extracts state variant classes" do
      template = ~s(<button class="hover:bg-blue-500 focus:ring-2 active:scale-95 disabled:opacity-50">)

      candidates = CandidateExtractor.extract(template)

      assert "hover:bg-blue-500" in candidates
      assert "focus:ring-2" in candidates
      assert "active:scale-95" in candidates
      assert "disabled:opacity-50" in candidates
    end

    test "extracts arbitrary value classes" do
      template = ~S|<div class="w-[calc(100%-2rem)] h-[300px] bg-[#1a1a2e]">|

      candidates = CandidateExtractor.extract(template)

      assert "w-[calc(100%-2rem)]" in candidates
      assert "h-[300px]" in candidates
      assert "bg-[#1a1a2e]" in candidates
    end

    test "extracts modifier classes with slash" do
      template = ~s(<div class="bg-red-500/50 text-white/75">)

      candidates = CandidateExtractor.extract(template)

      assert "bg-red-500/50" in candidates
      assert "text-white/75" in candidates
    end

    test "extracts negative value classes" do
      template = ~s(<div class="-mt-4 -translate-x-1/2">)

      candidates = CandidateExtractor.extract(template)

      assert "-mt-4" in candidates
      assert "-translate-x-1/2" in candidates
    end

    test "extracts important modifier classes" do
      template = ~s(<div class="!font-bold !p-0">)

      candidates = CandidateExtractor.extract(template)

      assert "!font-bold" in candidates
      assert "!p-0" in candidates
    end

    test "extracts dark mode classes" do
      template = ~s(<div class="dark:bg-gray-900 dark:text-white">)

      candidates = CandidateExtractor.extract(template)

      assert "dark:bg-gray-900" in candidates
      assert "dark:text-white" in candidates
    end

    test "extracts stacked variants" do
      template = ~s(<div class="sm:hover:bg-blue-500 dark:md:text-lg">)

      candidates = CandidateExtractor.extract(template)

      assert "sm:hover:bg-blue-500" in candidates
      assert "dark:md:text-lg" in candidates
    end

    test "extracts classes from HEEx templates" do
      template = ~S"""
      <div class={"flex #{if @active, do: "bg-blue-500", else: "bg-gray-200"}"}>
        <span class="text-sm font-medium"><%= @title %></span>
      </div>
      """

      candidates = CandidateExtractor.extract(template)

      assert "flex" in candidates
      assert "bg-blue-500" in candidates
      assert "bg-gray-200" in candidates
      assert "text-sm" in candidates
      assert "font-medium" in candidates
    end

    test "excludes single-character tokens" do
      template = ~s(<p class="a b flex">)

      candidates = CandidateExtractor.extract(template)

      refute "a" in candidates
      refute "b" in candidates
      assert "flex" in candidates
    end

    test "excludes URLs" do
      template = ~s(<a href="https://example.com" class="text-blue-500">link</a>)

      candidates = CandidateExtractor.extract(template)

      refute Enum.any?(candidates, &String.starts_with?(&1, "http"))
      assert "text-blue-500" in candidates
    end

    test "excludes comment-like tokens" do
      template = ~s(// this is a comment\n<div class="flex">)

      candidates = CandidateExtractor.extract(template)

      refute "//" in candidates
      assert "flex" in candidates
    end

    test "excludes template interpolation markers" do
      template = ~s({{variable}} <div class="flex">)

      candidates = CandidateExtractor.extract(template)

      refute "{{variable}}" in candidates
      assert "flex" in candidates
    end

    test "excludes comparison operators" do
      template = ~s(<%= if x == y do %><div class="flex"><% end %>)

      candidates = CandidateExtractor.extract(template)

      refute Enum.any?(candidates, &String.contains?(&1, "=="))
      assert "flex" in candidates
    end

    test "returns a MapSet with deduplicated candidates" do
      template = ~s(<div class="flex flex flex">)

      candidates = CandidateExtractor.extract(template)

      assert %MapSet{} = candidates
      assert "flex" in candidates
      # "flex" appears 3 times but is deduplicated. Other tokens like
      # "div" and "class" may also be extracted as false positives,
      # which is by design (over-match rather than under-match).
      assert MapSet.size(candidates) >= 1
    end

    test "handles empty string" do
      assert CandidateExtractor.extract("") == MapSet.new()
    end

    test "extracts @ prefixed classes" do
      template = ~s(<div class="@container @lg:grid-cols-3">)

      candidates = CandidateExtractor.extract(template)

      assert "@container" in candidates
      assert "@lg:grid-cols-3" in candidates
    end

    test "extracts classes with dots" do
      template = ~s(<div class="text-[1.5rem] leading-[1.2]">)

      candidates = CandidateExtractor.extract(template)

      assert "text-[1.5rem]" in candidates
      assert "leading-[1.2]" in candidates
    end

    test "extracts from multiline templates" do
      template = """
      <div
        class="
          flex
          items-center
          justify-between
          p-4
          sm:p-6
        "
      >
      """

      candidates = CandidateExtractor.extract(template)

      assert "flex" in candidates
      assert "items-center" in candidates
      assert "justify-between" in candidates
      assert "p-4" in candidates
      assert "sm:p-6" in candidates
    end
  end
end
