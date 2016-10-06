defmodule Pit do

  defmodule PipedValueMismatch do
    defexception [:message, :pattern, :value]
  end


  @moduledoc ~S"""

  The `pit` macro lets you pipe value transformations by pattern matching
  on data as it is passed down the pipe.

  The syntax for transforming values is `expression |> pit(value <- pattern)`.


    iex> # The following will ensure there are no errors on
    iex> # the response and double the count value from data.
    iex> import Pit
    ...> response = {:ok, %{data: %{"count" => 10}, errors: []}}
    ...> response
    ...>    |> pit(data <- {:ok, %{errors: [], data: data}})
    ...>    |> pit(count * 2 <- %{"count" => count})
    20


    iex> # By using the ! operator, you can pipe values
    iex> # only if they dont match some pattern
    iex> # This example only pipes anything that aint an error
    iex> import Pit
    ...> response = {:cool, 22}
    ...> response
    ...>    |> pit(! {:error, _})
    ...>    |> pit(n <- {_, n})
    22


    iex> # if the piped value does not match an error is raised.
    iex> import Pit
    ...> response = {:error, :not_found}
    ...> response
    ...>    |> pit(! {:error, _})
    ...>    |> pit(n <- {:ok, n})
    ** (Pit.PipedValueMismatch) did not expect piped value to match `{:error, _}` but got `{:error, :not_found}`


    iex> # also, when a guard fails an error is raised
    iex> import Pit
    ...> response = {:ok, 22}
    ...> response
    ...>    |> pit({:ok, n} when n > 30)
    ...>    |> pit(n <- {:ok, n})
    ** (Pit.PipedValueMismatch) expected piped value to match `{:ok, n} when n > 30` but got `{:ok, 22}`


    iex> # You can provide a fallback value for mismatch
    iex> import Pit
    ...> response = {:error, :not_found}
    ...> response
    ...>    |> pit({:ok, _}, else: {:ok, :default})
    ...>    |> pit(n <- {:ok, n})
    :default

  """

  defmacro pit(pipe, expr, options \\ []) do
    hole = down_the_pit(expr, fallback(expr, options))
    quote do
      unquote(pipe) |> unquote(hole).()
    end
  end

  defp down_the_pit({:<-, _, [value, pattern]}, fallback) do
    quote do
      fn (it) ->
        case it do
          unquote(pattern) -> unquote(value)
          _ -> it |> unquote(fallback)
        end
      end
    end
  end

  defp down_the_pit({:!, _, [pattern]}, fallback) do
    quote do
      fn (it) ->
        case it do
          unquote(pattern) -> it |> unquote(fallback)
          _ -> it
        end
      end
    end
  end

  defp down_the_pit(pattern, fallback) do
    quote do
      fn (it) ->
        case it do
          unquote(pattern) -> it
          _ -> it |> unquote(fallback)
        end
      end
    end
  end

  defp fallback(_, [else_pipe: pipe]), do: pipe
  defp fallback(_, [else: code]) do
    quote do
      (fn (_) -> unquote(code) end).()
    end
  end
  defp fallback({:<-, _, [_, pattern]}, _) do
    mismatch({"expected piped value to match", pattern})
  end
  defp fallback({:!, _, [pattern]}, _) do
    mismatch({"did not expect piped value to match", pattern})
  end
  defp fallback(pattern, _) do
    mismatch({"expected piped value to match", pattern})
  end

  defp mismatch({message, pattern}) do
    quote do
      (fn (it) ->
        raise PipedValueMismatch,
        message: "#{unquote(message)} `#{unquote(Macro.to_string(pattern))}` but got `#{inspect(it)}`",
        pattern: unquote(Macro.escape(pattern)),
        value: it
      end).()
    end
  end

end
