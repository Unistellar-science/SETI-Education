sections = ["Week 1", "Week 2", "Week 3", "Week 4"]

Dict(
    "main" => [uppercase(section) => collections[section].pages for section in sections],
)
