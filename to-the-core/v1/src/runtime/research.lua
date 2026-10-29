local research = {}

-- Returns whether the technology was newly researched.
function research.unlock(force, technology_name)
  local technology = force.technologies[technology_name]
  if technology and not technology.researched then
    technology.enabled = true
    technology.researched = true
    return true
  end
  return false
end

return research
