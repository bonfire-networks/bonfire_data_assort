# Bonfire.Data.Assort Usage Rules

Bonfire.Data.Assort provides database models for ranking and ordering items in the Bonfire ecosystem. It's built on top of the `ecto_ranked` library and enables scoped ranking of any pointer-based entities.

## Core Concepts

### Ranked Table
A reusable table (`bonfire_data_ranked`) that links and ranks items with optional scoping. This allows you to:
- Order items within a specific scope (e.g., pins per user)
- Create global rankings (no scope)
- Support multiple ranking types via `rank_type_id`

### Key Fields
- `item_id`: The pointer to the item being ranked (required)
- `scope_id`: Optional pointer defining the ranking scope (e.g., user, instance)
- `rank_type_id`: Optional pointer for different ranking types
- `rank`: Integer field storing the actual rank position
- `rank_set`: Virtual field for setting position (`:first`, `:last`, or numeric position)

## Basic Usage

### Creating a Ranked Item

```elixir
# Global ranking (no scope)
{:ok, ranked} = Bonfire.Data.Assort.Ranked.changeset(%{
  item_id: "01FGTH48ZZD08ADBHQ260KYJHW"
}) |> repo().insert()

# Scoped ranking (e.g., per user)
{:ok, ranked} = Bonfire.Data.Assort.Ranked.changeset(%{
  item_id: pin_id,
  scope_id: user_id,
  rank_set: :first  # Put at the beginning
}) |> repo().insert()
```

### Querying Ranked Items

```elixir
import Ecto.Query

# Get all items in rank order
Bonfire.Data.Assort.Ranked 
|> order_by(:rank) 
|> repo().all()

# Get items for a specific scope
Bonfire.Data.Assort.Ranked
|> where([r], r.scope_id == ^scope_id)
|> order_by(:rank)
|> repo().all()
```

### Updating Rank Position

```elixir
# Move item to last position
ranked 
|> Bonfire.Data.Assort.Ranked.changeset(%{rank_set: :last}) 
|> repo().update()

# Set specific position (1-based)
ranked 
|> Bonfire.Data.Assort.Ranked.changeset(%{rank_set: 3}) 
|> repo().update()
```

## Advanced Patterns

### Using as Join Table for Many-to-Many Relationships

Configure in your schema configuration:

```elixir
# In config/bonfire_data.exs
many_to_many(:choices, Bonfire.Poll.Choice,
  join_through: Bonfire.Data.Assort.Ranked,
  unique: true,
  join_keys: [scope_id: :id, item_id: :id],
  on_replace: :delete
)
```

### Real-World Example: Pin Ranking

From `Bonfire.Social.Pins`:

```elixir
def rank_pin(pin, scope, position) do
  with {:ok, %Ecto.Changeset{valid?: true} = cs} <-
         Bonfire.Data.Assort.Ranked.changeset(%{
           item_id: pin,
           scope_id: uid(scope),
           rank_set: position
         })
         |> Ecto.Changeset.unique_constraint([:item_id, :scope_id],
           name: :bonfire_data_ranked_unique_per_scope
         )
         |> dump(),
       {:ok, ins} <- repo().insert(cs) do
    {:ok, ins}
  else
    # Handle upsert for existing rankings
    {:error, %Ecto.Changeset{} = cs} ->
      repo().update(cs, [:rank])
    
    %Ecto.Changeset{} = cs ->
      repo().upsert(cs, [:rank])
  end
end
```

## Migration Patterns

### Creating the Ranked Table

```elixir
defmodule MyApp.Repo.Migrations.CreateRankedTable do
  use Ecto.Migration
  import Bonfire.Data.Assort.Ranked.Migration

  def up do
    create_ranked_table()
    create_unique_index()
  end

  def down do
    drop_unique_index()
    drop_ranked_table()
  end
end
```

### Using the migrate_ranked Macro

```elixir
defmodule MyApp.Repo.Migrations.AddRankedTable do
  use Ecto.Migration
  import Bonfire.Data.Assort.Ranked.Migration

  def change do
    migrate_ranked()
  end
end
```

## Database Constraints

The extension creates several unique indexes to ensure data integrity:

1. **Full unique constraint**: `[:item_id, :scope_id, :rank_type_id]`
2. **Global ranking**: Unique on `item_id` when both `scope_id` and `rank_type_id` are NULL
3. **Per rank type**: Unique on `[:item_id, :rank_type_id]` when `scope_id` is NULL
4. **Per scope**: Unique on `[:item_id, :scope_id]` when `rank_type_id` is NULL

## Best Practices

### Always Use Changesets
Use the provided changeset function to ensure proper ranking behavior:

```elixir
# ✅ Good
Bonfire.Data.Assort.Ranked.changeset(%{item_id: id, rank_set: :first})

# ❌ Bad - bypasses ranking logic
%Bonfire.Data.Assort.Ranked{item_id: id, rank: 1}
```

### Handle Upserts Properly
When updating ranks, handle both insert and update cases:

```elixir
case repo().insert(changeset) do
  {:ok, ranked} -> 
    {:ok, ranked}
  
  {:error, changeset} ->
    # Item already ranked, update instead
    repo().update(changeset, [:rank])
end
```

### Query with Proper Ordering
Always include `order_by(:rank)` when fetching ranked items:

```elixir
# ✅ Good
query |> order_by(:rank)

# ❌ Bad - items won't be in rank order
query |> repo().all()
```

## Common Use Cases

### Instance-Wide Pinning
Used in Bonfire for pinning content at the instance level:

```elixir
# Pin to instance
Bonfire.Data.Assort.Ranked.changeset(%{
  item_id: post_id,
  scope_id: instance_scope_id(),
  rank_set: :first
})
```

### User-Specific Rankings
Personal rankings scoped to individual users:

```elixir
# User's pinned items
Bonfire.Data.Assort.Ranked.changeset(%{
  item_id: content_id,
  scope_id: user_id,
  rank_set: position
})
```

### Ordered Collections
Managing ordered lists like poll choices or page sections:

```elixir
# Add choice to poll with specific position
Bonfire.Data.Assort.Ranked.changeset(%{
  item_id: choice_id,
  scope_id: poll_id,
  rank_set: 2
})
```

## Integration with Other Extensions

### Using with Edges
Often used alongside `Bonfire.Data.Edges` for relationships that need ordering:

```elixir
# Create edge first
{:ok, edge} = Edges.insert(Pin, user, :pin, object, opts)

# Then rank it
{:ok, ranked} = Bonfire.Data.Assort.Ranked.changeset(%{
  item_id: edge.id,
  scope_id: user.id,
  rank_set: :first
}) |> repo().insert()
```

### Preloading Ranked Items
When using as a join table, items come pre-ordered:

```elixir
poll
|> repo().preload(:choices)  # Automatically ordered by rank
```

## Anti-Patterns to Avoid

### ❌ Direct Rank Manipulation
```elixir
# Bad - can break ranking consistency
%Bonfire.Data.Assort.Ranked{rank: 100}
```

### ❌ Forgetting Scope Constraints
```elixir
# Bad - allows duplicate items in same scope
Bonfire.Data.Assort.Ranked.changeset(%{item_id: id})
|> repo().insert!()  # May fail on second insert
```

### ❌ Ignoring Unique Constraints
```elixir
# Bad - doesn't handle existing rankings
changeset |> repo().insert()

# Good - handles updates
changeset |> repo().insert()
|> case do
  {:error, _} -> repo().update(changeset, [:rank])
  ok -> ok
end
```

## Performance Considerations

- The `rank` column should not have a unique index (causes issues with reordering)
- Use database indexes on `scope_id` for efficient scoped queries
- Batch operations when reordering multiple items
- Consider pagination for large ranked lists

## Debugging

### Check Current Rankings
```elixir
# See all rankings for a scope
Bonfire.Data.Assort.Ranked
|> where([r], r.scope_id == ^scope_id)
|> order_by(:rank)
|> select([r], %{item_id: r.item_id, rank: r.rank})
|> repo().all()
```

### Verify Constraints
```elixir
# Check for duplicates
Bonfire.Data.Assort.Ranked
|> group_by([r], [r.item_id, r.scope_id])
|> having([r], count(r.id) > 1)
|> repo().all()
```