local research = {}

function research.unlock(force, technology_name)
  local technology = force.technologies[technology_name]
  if technology and not technology.researched then
    technology.enabled = true
    technology.researched = true
  end
end

return research
