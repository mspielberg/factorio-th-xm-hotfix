local LOG = log
local function log(x) LOG(serpent.block(x)) end

local ko_items = {}
local no_recipe_items = {}
local ko_recipes = {}

local function mark_accessible(name)
  ko_items[name] = nil
  no_recipe_items[name] = nil
end

for name in pairs(data.raw.item) do
  ko_items[name] = true
  no_recipe_items[name] = true
end
for name in pairs(data.raw.fluid) do
  ko_items[name] = true
end
for name in pairs(data.raw["autoplace-control"]) do
  mark_accessible(name)
end

local ignore_from_base = {
  "belt-immunity-equipment",
  "coin",
  "computer",
  "infinity-chest",
  "raw-wood",
  "simple-entity",
  "simple-entity-with-force",
  "simple-entity-with-owner",
  "steam",
  "used-up-uranium-fuel-cell",
}
for _, name in ipairs(ignore_from_base) do
  mark_accessible(name)
end

local changed = true
while changed do
  log("starting pass")
  changed = false
  for name, recipe in pairs(data.raw.recipe) do
    if recipe.normal then recipe = recipe.normal end
    local missing = {}
    for _, ing in ipairs(recipe.ingredients) do
      local ingredient_name = ing.name or ing[1]
      if ko_items[ingredient_name] then
        if name == "battery" then
          log(ingredient_name)
        end
        missing[#missing+1] = ingredient_name
      end
    end

    if next(missing) then
      ko_recipes[name] = missing
    else
      ko_recipes[name] = nil
    end

    local results = recipe.results or {{recipe.result, 1}}
    for _, result in ipairs(results) do
      local result_name = result.name or result[1]
      no_recipe_items[result_name] = nil
      if not next(missing) and ko_items[result_name] then
        log("marking "..result_name.." as accessible via recipe "..name)
        mark_accessible(result_name)
        changed = true
      end
    end
  end
end

local function count(t)
  local i = 0
  for _ in pairs(t) do
    i = i + 1
  end
  return i
end

--log(ok_items)
log("Found "..count(no_recipe_items).. " items without recipes or autoplace-controls:")
log(no_recipe_items)
log("Found "..count(ko_items).." inaccessible items:")
log(ko_items)
log("Found "..count(ko_recipes).." inaccessible recipes:")
log(ko_recipes)












-- actually traverse as a player would
local crafted_by = {}
local accessible_items = {}
local function can_craft(recipe)
  local ingredients = recipe.ingredients or recipe.normal.ingredients
  for _, ing in ipairs(ingredients) do
    local ingredient_name = ing.name or ing[1]
    if not accessible_items[ingredient_name] then
      return false
    end
  end
  return true
end

local tech_status = {}
local function can_research(tech)
  for _, ingredient in ipairs(tech.unit.ingredients) do
    if not accessible_items[ingredient[1]] then
      return false
    end
  end
  local prereqs = tech.prerequisites or {}
  for _, prereq in ipairs(prereqs) do
    if not tech_status[prereq] then
      return false
    end
  end
  return true
end

local function to_set(t)
  local out = {}
  for _, x in ipairs(t) do out[x] = true end
  return out
end
local accessible_at_start = {"raw-wood", "water", "steam"}
accessible_items = to_set(accessible_at_start)

for name in pairs(data.raw["autoplace-control"]) do
  accessible_items[name] = true
end

local recipe_status = {}
for name, recipe in pairs(data.raw.recipe) do
  if recipe.normal then recipe = recipe.normal end
  if recipe.enabled or recipe.enabled == nil then
    if can_craft(recipe) then
      log("can craft: "..name)
      recipe_status[name] = 2
    else
      log("accessible recipe: "..name)
      recipe_status[name] = 1
    end
  end
end


local function unlock_recipes()
  local unlocked = {}
  local craftable = {}
  local changed = true
  while changed do
    changed = false
    for name in pairs(tech_status) do
      local tech = data.raw.technology[name]
      if tech.effects then
        for _, effect in ipairs(tech.effects) do
          if effect.type == "unlock-recipe" and not recipe_status[effect.recipe] then
            unlocked[name] = true
            recipe_status[effect.recipe] = 1
            changed = true
          end
        end
      end
    end
    for name, status in pairs(recipe_status) do
      if status == 1 then
        local recipe = data.raw.recipe[name]
        if can_craft(recipe) then
          recipe_status[name] = 2
          craftable[name] = true
          changed = true
        end
      end
    end
  end
  if next(unlocked) then
    log("unlocked "..count(unlocked).." recipes: "..serpent.line(unlocked))
  end
  if next(craftable) then
    log("now able to craft "..count(craftable).." recipes: "..serpent.line(craftable))
  end
  return next(unlocked) ~= nil or next(craftable)
end

local function unlock_items()
  local unlocked = {}
  local changed = true
  while changed do
    changed = false
    for name, status in pairs(recipe_status) do
      local recipe = data.raw.recipe[name]
      if recipe.normal then recipe = recipe.normal end
      local results = recipe.results or {{name=recipe.result}}
      for _, result in pairs(results) do
        local result_name = result.name or result[1]
        if status == 2 and not accessible_items[result_name] then
          accessible_items[result_name] = true
          unlocked[result_name] = true
          changed = true
          crafted_by[result_name] = nil
        elseif status == 1 then
          crafted_by[result_name] = crafted_by[result_name] or {}
          crafted_by[result_name][name] = true
        end
      end
    end
  end
  if next(unlocked) then
    log("unlocked "..count(unlocked).." items: "..serpent.line(unlocked))
  end
  return next(unlocked) ~= nil
end

local function unlock_technologies()
  local unlocked = {}
  local changed = true
  while changed do
    changed = false
    for name, tech in pairs(data.raw.technology) do
      if can_research(tech) and not tech_status[name] then
        tech_status[name] = true
        unlocked[name] = true
        changed = true
      end
    end
  end
  if next(unlocked) then
    log("unlocked "..count(unlocked).." technologies: "..serpent.line(unlocked))
  end
  return next(unlocked) ~= nil
end

changed = true
while changed do
  changed = unlock_recipes() or unlock_items() or unlock_technologies()
end

for name, status in pairs(recipe_status) do
  if status == 1 then
    log("recipe "..name.." unlocked but missing ingredients:")
    local recipe = data.raw.recipe[name]
    local ingredients = recipe.ingredients or recipe.normal.ingredients
    for _, ingredient in ipairs(ingredients) do
      local ingredient_name = ingredient.name or ingredient[1]
      if not accessible_items[ingredient_name] then
        if crafted_by[ingredient_name] then
          log(ingredient_name.." (uncraftable recipe(s) "..serpent.line(crafted_by[ingredient_name])..")")
        else
          log(ingredient_name.." (no recipe unlocked)")
        end
      end
    end
  end
end