sections = ["image processing", "photometry", "astrometry", "time series", "spectroscopy"]

Dict(
     "main" => [uppercase(section) => collections[section].pages for section in sections],
)
