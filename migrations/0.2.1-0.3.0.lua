-- local function unlock_recipes()
--   for _, force in pairs(game.forces) do
--     force.reset_technologies()
--     for _, tech in pairs(force.technologies) do
--       if tech.researched then
--         for _, modifier in pairs(tech.effects) do
--           if modifier.type == "unlock-recipe" then
--             force.recipes[modifier.recipe].enabled = true
--           end
--         end
--       end
--     end
--   end
-- end

-- unlock_recipes()

function unlock_recipe(tech_name, recipe_name)
  for _, force in pairs(game.forces) do
    local tech = force.technologies[tech_name]
    local recipe = force.recipes[recipe_name]
    if tech and recipe then
      tech.reload()
      recipe.reload()
      if tech.researched then
        recipe.enabled = true
      end
    end
  end
end

unlock_recipe("automation", "components-1-b")
unlock_recipe("bauxite-sediment", "milled-bauxite")