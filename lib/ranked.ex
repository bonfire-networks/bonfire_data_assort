defmodule Bonfire.Data.Assort.Ranked do
  @moduledoc """
  A reusable table to link child or related items and also rank sibling items.

  Usage (for global ranking, otherwise you should specify scope):
  ```
  {:ok, first} = Bonfire.Data.Assort.Ranked.changeset(%{item_id: "01FGTH48ZZD08ADBHQ260KYJHW"}) |> repo().insert
  second = Bonfire.Data.Assort.Ranked.changeset(%{item_id: "01FGTH0N3YPBS5MNNAEAEVV54J"}) |> repo().insert

  import Ecto.Query
  Bonfire.Data.Assort.Ranked |> order_by(:rank) |> repo().all

  first |> Bonfire.Data.Assort.Ranked.changeset(%{rank_set: :last}) |> repo().update

  Bonfire.Data.Assort.Ranked |> order_by(:rank) |> repo().all
  ```
  """

  use Ecto.Schema
  # import Ecto.Changeset
  import EctoRanked

  alias Needle.Pointer
  alias Bonfire.Data.Assort.Ranked

  @relations [:item_id, :scope_id, :rank_type_id]
  @required [:item_id]

  @foreign_key_type Needle.ULID
  schema "bonfire_data_ranked" do
    belongs_to(:item, Pointer)
    belongs_to(:scope, Pointer)
    belongs_to(:rank_type, Pointer)
    field(:rank, :integer)
    field(:rank_set, :any, virtual: true)
  end

  def changeset(model \\ %Ranked{}, params) do
    model
    |> Ecto.Changeset.cast(params, [:rank_set, :rank] ++ @relations)
    |> Ecto.Changeset.validate_required(@required)
    |> set_rank(
      rank: :rank,
      position: :rank_set,
      scope: [:scope_id, :rank_type_id]
    )
  end
end

defmodule Bonfire.Data.Assort.Ranked.Migration do
  @table_name "bonfire_data_ranked"
  @unique_index [:item_id, :scope_id, :rank_type_id]

  use Ecto.Migration
  import Needle.Migration
  alias Needle.Pointer

  # create_ranked_table/{0,1}

  defp make_ranked_table(_exprs) do
    quote do
      require Needle.Migration

      create table(unquote(@table_name)) do
        add(:item_id, strong_pointer(Pointer))
        add(:scope_id, weak_pointer(Pointer))
        add(:rank_type_id, weak_pointer())
        add(:rank, :integer)
        # timestamps()
      end
    end
  end

  defmacro create_ranked_table(), do: make_ranked_table([])
  defmacro create_ranked_table(do: {_, _, body}), do: make_ranked_table(body)

  defp make_unique_index(opts) do
    quote do
      flush()

      Ecto.Migration.create_if_not_exists(
        Ecto.Migration.unique_index(
          unquote(@table_name),
          unquote(@unique_index),
          unquote(opts)
        )
      )

      Ecto.Migration.execute(
        "CREATE UNIQUE INDEX bonfire_data_ranked_unique_without_scope ON #{unquote(@table_name)} (item_id) WHERE scope_id IS NULL AND rank_type_id IS NULL;"
      )

      Ecto.Migration.execute(
        "CREATE UNIQUE INDEX bonfire_data_ranked_unique_per_rank_type ON #{unquote(@table_name)} (item_id, rank_type_id) WHERE scope_id IS NULL;"
      )

      Ecto.Migration.execute(
        "CREATE UNIQUE INDEX bonfire_data_ranked_unique_per_scope ON #{unquote(@table_name)} (item_id, scope_id) WHERE rank_type_id IS NULL;"
      )
    end
  end

  defmacro create_unique_index(opts \\ [])
  defmacro create_unique_index(opts), do: make_unique_index(opts)

  def drop_unique_index(opts \\ [])

  def drop_unique_index(opts),
    do: drop_if_exists(unique_index(@table_name, @unique_index, opts))

  # drop_ranked_table/0

  def drop_ranked_table() do
    drop_if_exists(table(@table_name))
  end

  # migrate_ranked/{0,1}

  defp mu(:up) do
    quote do
      unquote(make_ranked_table([]))
      unquote(make_unique_index([]))
    end
  end

  defp mu(:down) do
    quote do
      Bonfire.Data.Assort.Ranked.Migration.drop_unique_index()
      Bonfire.Data.Assort.Ranked.Migration.drop_ranked_table()
    end
  end

  defmacro migrate_ranked() do
    quote do
      if Ecto.Migration.direction() == :up,
        do: unquote(mu(:up)),
        else: unquote(mu(:down))
    end
  end

  defmacro migrate_ranked(dir), do: mu(dir)
end
