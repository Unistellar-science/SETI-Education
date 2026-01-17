sections = ["asp", "ucan"]

Dict(
     "main" => [uppercase(section) => collections[section].pages for section in sections],
)
