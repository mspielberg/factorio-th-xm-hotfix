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

-- remove chemical-burner
data.raw.inserter["inserter-chemical-burner"] = nil
data.raw.recipe["inserter-chemical-burner"] = nil
data.raw.item["inserter-chemical-burner"] = nil
data.raw.recipe["recycle-inserter-chemical-burner"] = nil
data.raw.technology["iron-recycling"].effects[5] = nil

data.raw.recipe["wood"].category = "basic-machine"

-- relays, vacuum tubes, quartz oscillators are assembled, not machined
data.raw.recipe["components-1-a"].category = "basic-crafting"
data.raw.recipe["components-1-b"].category = "crafting"
data.raw.recipe["components-2-a"].category = "crafting"
data.raw.recipe["components-2-b"].category = "crafting"
data.raw.recipe["components-3"].category = "advanced-crafting"

table.insert(data.raw.technology["lead-brass"].effects, {type = "unlock-recipe", recipe = "components-1-b"})

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

local st1 = data.raw.recipe["steam-turbine"]
local st2 = data.raw.recipe["steam-turbine-2"]
st1.ingredients, st2.ingredients = st2.ingredients, st1.ingredients

--update ingredient references
local ingredient_updates = {
  ["apatite"] = "phosphorite",
  ["bauxite"] = "laterite",
  ["granitic-ore"] = "skarn",
  ["heavy-sand"] = "sand",
  ["lead-ore"] = "massive-sulfide",
  ["sulfidic-ore"] = "igneous-sulfide",

  ["lead-plate"] = "lead-ingot",
  ["tin-plate"] = "tin-ingot",
}
for name in pairs(ingredient_updates) do
  data.raw.item[name] = nil
end
for _, recipe in pairs(data.raw.recipe) do
  local ingredients = recipe.ingredients or recipe.normal.ingredients or recipe.expensive.ingredients
  for _, ingredient in ipairs(ingredients) do
    if ingredient_updates[ingredient[1]] then
      ingredient[1] = ingredient_updates[ingredient[1]]
    end
  end
end

-- fix early nickel accessibility
data.raw.technology["nickel-smelting"].effects[1] = {type="unlock-recipe",recipe="hand-garnierite"}

-- fix borax availability
data.raw.technology["boron-processing"].effects[1] = {type="unlock-recipe",recipe="borax"}

--data.raw.technology["brick-clay"].effects[1].recipe = "brick-clay-b"
if data.raw.technology["radar-amplifier"] then
  data.raw.technology["radar-amplifier"].prerequisites[2] = nil
end
if data.raw.technology["radar-efficiency"] then
  data.raw.technology["radar-efficiency"].prerequisites[2] = nil
end
