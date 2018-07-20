do return end

local log = function (x) log(serpent.block(x)) end

local function count(t)
  local i = 0
  for _ in pairs(t) do
    i = i + 1
  end
  return i
end

local function deep_equals(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then
    return false
  elseif ta == "table" then
    for k in pairs(b) do
      if a[k] == nil then
        return false
      end
    end
    for k,v in pairs(a) do
      if not deep_equals(v, b[k]) then
        return false
      end
    end
  elseif a ~= b then
    return false
  end
  return true
end

-- actually traverse as a player would
local crafted_by = {}
local accessible_items = {}

--[[
tech_status[name] = {
  -- one entry for each ingredient required for tech "name" and all (recursive) predicates
  ["science-pack-1"] = true,
  ["science-pack-2"] = true,
  ...
}
]]
local tech_status = {}

local function can_research(tech)
  local ingredients_needed = {}
  for _, ingredient in ipairs(tech.unit.ingredients) do
    if not accessible_items[ingredient[1]] then
      return nil
    end
    ingredients_needed[ingredient] = true
  end
  local prereqs = tech.prerequisites or {}
  for _, prereq in ipairs(prereqs) do
    if not tech_status[prereq] then
      return nil
    end
    for _, ingredient in ipairs(data.raw.technology[prereq].unit.ingredients) do
      ingredients_needed[ingredient] = true
    end
  end
  return ingredients_needed
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

local accessible_crafting_categories = {}
for _, category in ipairs(data.raw.player.player.crafting_categories) do
  accessible_crafting_categories[category] = true
end

local recipe_status = {}

local function can_craft(recipe)
  local category = recipe.category or "crafting"
  local ingredients = recipe.ingredients or recipe.normal.ingredients
  for _, ing in ipairs(ingredients) do
    local ingredient_name = ing.name or ing[1]
    if not accessible_items[ingredient_name] then
      return false
    elseif not accessible_crafting_categories[category] then
      return false
    end
  end
  return true
end

for name, recipe in pairs(data.raw.recipe) do
  local is_enabled = recipe.normal and (recipe.normal.enabled or recipe.normal.enabled == nil) or (recipe.enabled or recipe.enabled == nil)
  if is_enabled then
    if can_craft(recipe) then
      recipe_status[name] = 2
    else
      recipe_status[name] = 1
    end
  end
end

local function unlock_crafting_categories()
  local changed = false
  for item_name in pairs(accessible_items) do
    if data.raw.item[item_name] and data.raw.item[item_name].place_result then
      local item_proto = data.raw.item[item_name]
      local entity_name = item_proto.place_result
      local entity_proto = nil
      for type in pairs(data.raw) do
        if type ~= "item" then
          for _, proto in pairs(data.raw[type]) do
            if proto.name == entity_name then
              entity_proto = proto
              break
            end
          end
          if entity_proto then
            break
          end
        end
      end

      if entity_proto and entity_proto.crafting_categories then
        for _, category in ipairs(entity_proto.crafting_categories) do
          if not accessible_crafting_categories[category] then
            accessible_crafting_categories[category] = true
            changed = true
            log("marked category "..category.." accessible via entity "..entity_proto.name)
          end
        end
      end
    end
  end
  return changed
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
      local prereqs = can_research(tech)
      if prereqs and not tech_status[name] then
        tech_status[name] = prereqs
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

local changed = true
while changed do
  changed = unlock_recipes() or unlock_items() or unlock_crafting_categories()
  if not changed then changed = unlock_technologies() end
end

for name, status in pairs(recipe_status) do
  if status == 1 then
    log("recipe "..name.." unlocked but missing prerequisites:")
    local recipe = data.raw.recipe[name]
    local category = recipe.category or "crafting"
    if not accessible_crafting_categories[category] then
      log(category.." (crafting category not unlocked)")
    end

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

-- audit technologies
local function research_unit_ingredients(tech)
  local out = {}
  for _, ingredient in pairs(tech.unit.ingredients) do
    out[ingredient[1]] = true
  end
  return out
end

local research_unit_ingredients_cache = {}
local function recursive_research_unit_ingredients(tech)
  if not research_unit_ingredients_cache[tech.name] then
    local ingredients_needed = research_unit_ingredients(tech)
    local prereqs = tech.prerequisites or {}
    for _, prereq in ipairs(prereqs) do
      for ingredient in pairs(recursive_research_unit_ingredients(data.raw.technology[prereq])) do
        ingredients_needed[ingredient] = true
      end
    end
    research_unit_ingredients_cache[tech.name] = ingredients_needed
  end
  return research_unit_ingredients_cache[tech.name]
end

local prerequisites_cache = {}
local function research_prerequisites(tech)
  if not prerequisites_cache[tech.name] then
    local all_prereqs = {}
    local prereqs = tech.prerequisites or {}
    for _, direct in ipairs(prereqs) do
      all_prereqs[direct] = true
      for _, indirect in ipairs(research_prerequisites(data.raw.technology[direct])) do
        all_prereqs[indirect] = true
      end
    end
    local as_list = {}
    for k in pairs(all_prereqs) do
      as_list[#as_list + 1] = k
    end
    prerequisites_cache[tech.name] = as_list
  end
  return prerequisites_cache[tech.name]
end

local function indirect_research_prerequisites(tech)
  local all_prereqs = {}
  local prereqs = tech.prerequisites or {}
  for _, prereq in ipairs(prereqs) do
    for _, indirect in ipairs(research_prerequisites(data.raw.technology[prereq])) do
      all_prereqs[indirect] = true
    end
  end
  local as_list = {}
  for k in pairs(all_prereqs) do
    as_list[#as_list + 1] = k
  end
  return as_list
end

for name, tech in pairs(data.raw.technology) do
  --[[
  local direct_ingredients = research_unit_ingredients(tech)
  direct_ingredients["science-pack-0"] = nil
  local indirect_ingredients = recursive_research_unit_ingredients(tech)
  indirect_ingredients["science-pack-0"] = nil
  if name == "inserter-long-fast" then
    log(serpent.block{direct=direct_ingredients, indirect=indirect_ingredients})
  end
  if not deep_equals(direct_ingredients, indirect_ingredients) then
    log("technology "..name.." has indirect ingredients "..serpent.line(indirect_ingredients).." but only requires "..serpent.line(direct_ingredients))
  end
  ]]

  local indirect = indirect_research_prerequisites(tech)
  for _, prereq in ipairs(tech.prerequisites or {}) do
    for _, indirect_prereq in ipairs(indirect) do
      if indirect_prereq == prereq then
        log("technology "..name.." requires "..prereq.." that is already indirectly required")
      end
    end
  end
end