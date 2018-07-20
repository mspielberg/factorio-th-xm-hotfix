-- make regular burners able to use chemical fuel
for _, category in pairs(data.raw) do
  for _, proto in pairs(category) do
    local es = proto.energy_source or proto.burner
    if es and es.fuel_category == "crude" then
      es.fuel_category = nil
      es.fuel_categories = {"crude", "chemical"}
    end
  end
end

data.raw.recipe["wood"].category = "basic-machine"

-- relays, vacuum tubes, quartz oscillators are assembled, not machined
data.raw.recipe["components-1-a"].category = "basic-crafting"
data.raw.recipe["components-1-b"].category = "crafting"
data.raw.recipe["components-2-a"].category = "crafting"
data.raw.recipe["components-2-b"].category = "crafting"
data.raw.recipe["components-3"].category = "advanced-crafting"

data.raw.recipe["components-1-b"].ingredients[2][1] = "gear-3"
table.insert(data.raw.technology["automation"].effects, {type = "unlock-recipe", recipe = "components-1-b"})

data:extend{
--XM Iron Plate from Forging
  {
    type = "recipe",
    name = "iron-plate-c",
    category = "machine",
    energy_required = 4,
    enabled = false,
    ingredients = {{"forging-iron", 1}},
    result = "iron-plate",
    result_count = 4
  },
}
data.raw.technology["forging-iron"].effects[1].recipe = "forging-iron-c"
data.raw.technology["forging-iron"].effects[3] = {
  type = "unlock-recipe",
  recipe = "iron-plate-c",
}

-- fix steam-turbine ingredients
local st1 = data.raw.recipe["steam-turbine"]
if st1.ingredients[1][1] == "forging-superalloy" then
  local st2 = data.raw.recipe["steam-turbine-2"]
  st1.ingredients, st2.ingredients = st2.ingredients, st1.ingredients
end

--update ingredient references
local ingredient_updates = {
}
for name in pairs(ingredient_updates) do
  data.raw.item[name] = nil
end
for _, recipe in pairs(data.raw.recipe) do
  for _, recipe_root in ipairs{recipe, recipe.normal, recipe.expensive} do
    if recipe_root then
      for _, item_list in ipairs{recipe_root.ingredients, recipe_root.results} do
        if item_list then
          for _, stack in ipairs(item_list) do
            if stack.name and ingredient_updates[stack.name] then
              stack.name = ingredient_updates[stack.name]
            elseif stack[1] and ingredient_updates[stack[1]] then
              stack[1] = ingredient_updates[stack[1]]
            end
          end
        end
      end
    end
  end
end

-- fix early nickel accessibility
data.raw.technology["nickel-smelting"].effects[1] = {type="unlock-recipe",recipe="hand-garnierite"}

-- fix borax availability
data.raw.technology["boron-processing"].effects[1] = {type="unlock-recipe",recipe="borax"}

-- unlock milled-bauxite for concrete
if data.raw.recipe["milled-bauxite"] then
  data.raw.technology["bauxite-sediment"].effects[2].recipe = "milled-bauxite"
end

if data.raw.technology["radar-amplifier"] then
  data.raw.technology["radar-amplifier"].prerequisites[2] = nil
end
if data.raw.technology["radar-efficiency"] then
  data.raw.technology["radar-efficiency"].prerequisites[2] = nil
end
