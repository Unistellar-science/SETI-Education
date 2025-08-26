### A Pluto.jl notebook ###
# v0.20.17

#> [frontmatter]
#> image = "https://science.unistellar.com/wp-content/uploads/2023/03/90Antiope_shadow_cords_v1.png"
#> title = "Occultations Lab"
#> date = "2025-08-01"
#> tags = ["asteroids", "occultations", "light curves"]
#> description = "Measure asteroid occulation light curves."

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ 40272038-3af6-11ef-148a-8be0002c4bda
begin
	import Pkg
	Pkg.activate(Base.current_project())
		
	# Notebook UI
	using PlutoUI, CommonMark
	
	# Data wrangling
	using CCDReduction, DataFramesMeta, DataDeps

	# Visualization and analysis
	using Astroalign
	using AstroImages, PlutoPlotly, Photometry, ImageCore 
	using AstroImages: restrict
	using Dates, Unitful, UnitfulAstro, Measurements

	AstroImages.set_cmap!(:cividis)

	# Use DataDeps.jl for dataset management
	# Auto-download data to current directory by default
	ENV["DATADEPS_ALWAYS_ACCEPT"] = "true"
	ENV["DATADEPS_LOAD_PATH"] = @__DIR__
	DataDep(
		"data",
		"""
		UCAN Data Files
		Website: https://www.seti.org/education/ucan/unistellar-education-materials/
		""",
		["http://www.dropbox.com/scl/fo/go5ensqkpuumkhimuzy2p/ANQJTr6oGTsyz1y0hLbPHIc?rlkey=0pyprhkurx8lcs000z8ybty7t&st=tua7prd9&dl=1"],
		["9ad9e40401024482672a79dcb59da2a11d4ec4ebd4d185b35abb79eb9adef334"],
		post_fetch_method = unpack,
	) |> register

	Pkg.status()
end

# ╔═╡ d7f0393d-e2fa-44ea-a812-8f85820e661e
md"""
# 🪨 Unistellar Asteroid Occultation Lab

In this lab we will observe an asteroid passing in front of a star in real time and explore how to produce and analyze its resulting light curve. For more on taking these types of observations, see our [Unistellar Science page here](https://science.unistellar.com/asteroid-occultations/).

Having some familiarity in high-level programming languages like Julia or Python will be useful, but not necessary, for following along with the topics covered. At the end of this notebook, you will hopefully have the tools to build your own analysis pipelines for processing astronomical photometry, as well as understand the principles behind other astronomical software at a broad level. For an example of applying these tools to a similar set of eVscope observations, see our [Unistellar Eclipsing Binary lab](https://icweaver.github.io/UCAN/EBs/EB_lab.html).
"""

# ╔═╡ 0439db40-1572-4dac-af7e-d09d28631a37
md"""
With this requisite information out of the way, let's get started!
"""

# ╔═╡ e0a51a72-9300-41d0-bc5c-44772350d6cc
msg_adding_colors = md"""
##### Adding colors in Julia 🎨
This makes magenta!

```julia
using ImageCore

RGB(1, 0, 0) + RGB(0, 0, 1)
```

$(RGB(1, 0, 0) + RGB(0, 0, 1))
""";

# ╔═╡ 68d3d6ae-a0bd-468d-9b78-a2679b1c0be9
md"""
## Background 📖

Asteroids are small, rocky bodies orbiting our Sun, primarily in a circular orbit between Mars and Jupiter know as the _asteroid belt_. There are millions of these bodies present in our Solar System, and they are thought to be the remnants of our early Solar System during its formation. For this reason, understanding more about these dark wanderers can give us insight into our origins.

Asteroids do not emit their own light, so we must rely on other methods to observe them. One such method is to wait for an asteroid to pass in front of a background star from our point of view. When this happens, the light from the star is momentarily blocked out in what is known as an _occultation_ event.

$(Resource("https://science.unistellar.com/wp-content/uploads/2023/03/90Antiope_shadow_cords_v1.png"))

_Simplified diagram of an asteroid occultation. Each colored band represents a chord of the asteroid's shadow that an observer on Earth might catch. In aggregate, these observations can give us an idea of the asteroid's shape and size._

The duration of this event, combined with how fast the asteroid is moving, can then give us an estimate of the asteroid's size. In this lab, we will step through this process using eVscope data collected from an occulting asteroid.
"""

# ╔═╡ d9431fb9-2713-4982-b342-988e01445fed
md"""
## Data inspection 🔎

We start by loading in the raw sample data, which is [available here](https://www.dropbox.com/scl/fo/go5ensqkpuumkhimuzy2p/ANQJTr6oGTsyz1y0hLbPHIc?rlkey=0pyprhkurx8lcs000z8ybty7t&st=4y95ad2v&dl=0).

!!! note
	We placed the unzipped data into a folder named `data` at the same location as our notebook. This is done automatically with [DataDeps.jl](https://www.oxinabox.net/DataDeps.jl/stable/).
"""

# ╔═╡ 5f9767e3-d46b-4f2e-9c16-52946c03ae71
const DATA_DIR = datadep"data";

# ╔═╡ a1bd9062-65e3-494e-b3b9-aff1f4a0a1f2
df_sci = let
	df = fitscollection(basename(DATA_DIR); abspath=false)
	@transform! df :"DATE-OBS" = DateTime.(:"DATE-OBS")
end; # Semicolon hides automatic output

# ╔═╡ 23a4ed9c-f75c-4fb3-ae34-035ca943fc94
md"""
It looks like we have $(nrow(df_sci)) science frames of our "mystery" target gathered between the following times in UTC:
"""

# ╔═╡ bb936bb4-42a4-4e8c-af2e-137bc8d23715
t_start, t_end = extrema(df_sci.:"DATE-OBS")

# ╔═╡ 0ea1caa7-8b16-47b3-a20f-3e5d02903198
md"""
or about:
"""

# ╔═╡ 968bb800-5d85-4599-9a8a-95d9f689ee36
(t_end - t_start) |> canonicalize

# ╔═╡ 5a53889d-e99d-44bf-8516-a1397867a2b2
md"""
That's pretty quick! Let's see how each image frame looks (note that in the online version of this notebook that the slider will not work):
"""

# ╔═╡ a4a703be-1c6e-4643-a173-1e738e667652
imgs_sci = [load(f) for f in df_sci.path];

# ╔═╡ 355eb355-7db5-4df0-a5ee-9cbc599e1d6b
@bind frame_i Slider(1:length(imgs_sci); show_value=true)

# ╔═╡ c7c9966e-d1f7-4a29-a53c-662794d06d74
md"""
!!! tip "Plotting aside"
	We opted to use [plotly](https://plotly.com/javascript/) for our visualizations because it as a javascript library
    that integrates very well this notebook via [PlutoPlotly.jl](https://github.com/JuliaPluto/PlutoPlotly.jl). We've
    included the helper functions used to make these visualizations below.

	Another fantastic choice is [Makie.jl](https://docs.makie.org/v0.21/), which is more composable, modern, and simpler to develop with. Unfortunately, its web support still has a few rough edges, but they are quickly being ironed out.
"""

# ╔═╡ 41b95ea0-0564-465f-a7b2-ba9bb3cda8cc
md"""
There's definitely some wiggling going on due to our alt-az tracking. If we were really being careful, we would plate solve each frame and use the WCS information to align all of our images. This is computationally expensive and overkill for what we are trying to do, so instead we will align our images without WCS.
"""

# ╔═╡ 67125878-7c40-4599-9555-969d05908cd7
md"""
## Frame alignment 📐

To accomplish this, we will just align on asterisms instead! There is a ready-made python package for this ([`astroalign`](https://astroalign.quatrope.org/en/latest/)), which we can hook into with [PythonCall.jl](https://juliapy.github.io/PythonCall.jl/stable/):
"""

# ╔═╡ 60e9ac2c-728b-41ba-8863-8042daac4a16
md"""
With these aligned images, we can now pop some static apertures onto our frames to perform our photomoetry more reliably. The target is in the green aperture near the center of the frame, and for fun a sample comparison star is in the orange aperture. We went for a fairly tight aperture size to boost the signal-to-noise ratio of our final light curve.
"""

# ╔═╡ 79aed053-43f4-455a-9789-bfd615be015f
img_to, img_from = imgs_sci[[1, 4]]

# ╔═╡ 9c8fe79d-5b58-41e9-9b65-6d075a5fb558
img_aligned, params = let
	arr_aligned, params = align_frame(img_to, img_from; box_size = 9)
	shareheader(img_from, arr_aligned), params
end;

# ╔═╡ ed39c72f-da61-4ee3-b459-b85977ab66a1
img_aligned

# ╔═╡ 5bf51644-08f2-46a4-bfeb-69118b3c1c4c
imgs_sci[4].header

# ╔═╡ d5c21fcc-e0d7-4c17-b9b7-628a9c36e7b6
params.point_map

# ╔═╡ e28b90cf-c030-4be0-854d-1d11b709de28
let
	img = img_to
	box_size = 8 + 1 #Astroalign._compute_box_size(img)
	N_max = 10
	nsigma = 1
	
    clipped = sigma_clip(img, 1, fill = NaN)
    bkg, bkg_rms = estimate_background(clipped, box_size)
    subt = img .- bkg[axes(img)...]

    # return (
    #     # Sort detected sources from brightest to darkest
        first(extract_sources(PeakMesh(; box_size, nsigma), subt, bkg, true), N_max)
    #     # And also return the inputs, handy for debugging and data viz
    #     subt,
    #     bkg,
    # )
end


# ╔═╡ 48cf49ce-26e7-424c-a2cb-59aabfba8576
md"""
Ok, let's do some photometry next!
"""

# ╔═╡ 484c9b8d-339f-45c3-a52a-01c5dec1b46d
md"""
## Aperture photometry 🔾

Based on the visualization above, we were able to make some pretty good guesses for our target and comparison star apertures:
"""

# ╔═╡ 8e7fe041-042d-4475-8c35-a14fc0c2d305
# (x_center, y_center, radius)
ap_target = CircularAperture(668, 510, 11);

# ╔═╡ 2229f2f7-0a04-4383-b2ac-8db614b65a83
ap_comp1 = CircularAperture(147, 577, 11);

# ╔═╡ 156cda32-b464-42cc-aae0-d0a048f5cadc
md"""
We defined our apertures with the [Photometry.jl](http://juliaastro.org/dev/modules/Photometry/) package, e.g., `ap_target`, for analysis in Julia, and their corresponding plot object, e.g., `circ(ap_target)`, for visualization in plotly. Now, we just call the [`photometry`](http://juliaastro.org/dev/modules/Photometry/apertures/#Photometry.Aperture.photometry) function from Photometry.jl and store our results in a table:
"""

# ╔═╡ 93517d36-21b1-4fd8-bde9-c504681a6644
md"""
!!! note
	The first column is time, `x1` is the target flux, `x2` is the comparison star flux, and `xdiv` is the target flux divided by the comparison star flux.
"""

# ╔═╡ ec96a17a-34d2-41d1-a036-7977ffee3450
md"""
Below is the resulting light curve for our target. The occultation signal is quite striking:
"""

# ╔═╡ 041fd375-92a5-4204-bfdc-5409a04ba141
md"""
We now have everything we need to make a size estimate for this asteroid!
"""

# ╔═╡ 977c59a8-25ed-47c9-a929-53c5c056d959
md"""
## Size estimation 🪨

Given the following system parameters that we know about the [Sun's mass](https://en.wikipedia.org/wiki/Solar_mass) and [general location of the asteroid belt](https://en.wikipedia.org/wiki/Asteroid_belt#Orbits):
"""

# ╔═╡ 97322d18-9784-4faf-aa88-9d54b9e67d68
GMsun = (1 ± 0.00007)u"GMsun"

# ╔═╡ 00595567-ea76-4bd5-8467-4f16e86a9855
r = (2.7 ± 0.5)u"AU"

# ╔═╡ b4caa011-8492-426e-9efd-fc8fff7914d7
md"""
we can back out the asteroid's rough size ``(d_\mathrm{asteroid})`` based on our timing measurements:

```math
\begin{align}
d_\mathrm{asteroid} &= v_\mathrm{asteroid}\Delta t \\
					&= \sqrt{\frac{G M_\mathrm{sun}}{r}} \Delta t \quad .
\end{align}
```
"""

# ╔═╡ afbe8ecd-6e20-478c-96c7-603db59959c7
# Estimated from graph
Δt = (5 ± 0.5)u"s" 

# ╔═╡ 66bb240c-65a3-486f-8435-2841d2b9cc6a
v = √(GMsun / r) |> u"km/s"

# ╔═╡ 131f35b8-54f0-47e7-a19f-d3fb73f42337
d_asteroid = v * Δt |> u"km"

# ╔═╡ e03244d5-0691-431b-9f13-2d03fdb5a4ee
md"""
Alright, it looks like we have a size estimate of $(d_asteroid) for our mystery asteroid. Scroll over the box below to see how we did.
"""

# ╔═╡ 66a1bc55-a265-421b-99a0-9cfe44d2eb7e
md"""
!!! hint "Mystery asteroid"
	Name: [389 Industria](https://en.wikipedia.org/wiki/389_Industria)

	Location: Asteroid belt, central region

	Diameter: 79 km
"""

# ╔═╡ 2914603e-6b55-48a5-a269-8c44cde31237
md"""
!!! tip "Pedagogy aside"
	To get our estimates above, we used the following background information:

	* The target probably lives in the asteroid belt
	* The asteroid belt roughly spans from 2.2 AU - 3.2 AU from the Sun
	* Units and error propagation can be handled nicely for us in the following packages: [Unitful.jl](https://painterqubits.github.io/Unitful.jl/stable/), [UnitfulAstro.jl](http://juliaastro.org/UnitfulAstro.jl/stable/), [Measurements.jl](https://juliaphysics.github.io/Measurements.jl/stable/)
	* We were only sampling over a single chord, so getting different answers than the published result is to be expected
"""

# ╔═╡ 4078e4f6-3295-44b2-8fed-e6a628a74b5f
md"""
## Next steps

We have now successfuly characterized our occulting asteroid! Here are some other items to consider:

!!! note ""
	* How could these kinds of observations be combined to get a better estimate of the size and/or shape of the asteroid?
	* What other constraints might we be able to make?
	* What kinds of observations would be needed to determine other properties of the asteroid (e.g., mass, composition, reflectivity, rotation)?
"""

# ╔═╡ 99273ce1-548e-43f1-ad42-31ebd2db34e7
md"""
## Notebook setup 🔧
"""

# ╔═╡ fa066775-a63b-49c8-a368-0d033fb01a6e
md"""
### Convenience functions
"""

# ╔═╡ 70ec6ef2-836b-4d9a-86a4-4956d8dc28f3
timestamp(img) = header(img)["DATE-OBS"]

# ╔═╡ e728e458-24dd-4f5d-bdf3-be9d34e4cc14
# Make the table view a bit nicer in the browser
pretty(df) = DataFrames.PrettyTables.pretty_table(HTML, df;
	maximum_columns_width = "max-width",
	# show_subheader = false,
	header_alignment = :c,
)

# ╔═╡ ac3a9384-1b18-47ee-b6f3-e7fb4b7a0594
# Just show the first 10 rows
first(df_sci, 10) |> pretty

# ╔═╡ fc17ef61-5747-4a35-8ae7-2d7c3ba6b075
msg(x; title="Details") = details(title, x)

# ╔═╡ 922e2770-d5c8-4a1b-8d1b-1eb20b1652b0
cm"""
!!! note "Using this notebook"
	Some parts of this [Pluto notebook](https://plutojl.org/) are partially interactive online, but for full interactive control, it is recommended to download and run this notebook locally. For instructions on how to do this, click the `Edit or run this notebook` button in the top right corner of the page, or [click on this direct link](https://computationalthinking.mit.edu/Fall23/installation/) which includes a video and written instructions for getting started with Julia and Pluto 🌱.

	!!! tip "First time running"
		**Note**: This notebook will download all of the analysis packages and data needed for us, so the first time it runs may take a little while (~ a few minutes depending on your internet connection and platform). Clicking on the `Status` tab in the bottom right will bring up a progress window that we can use to monitor this process, and it also includes an option at the bottom marked `Notify when done` that can be selected to give us a notification pop-up in our browser when everything is finished.

	This is a fully hackable notebook, so exploring the [source code](https://github.com/icweaver/UCAN/blob/main/EBs/EB_lab.jl) and making your own modifications is encouraged! Unlike Jupyter notebooks, Pluto notebook are just plain Julia files. Any changes you make in the notebook are automatically saved to the source file.

	!!! tip "Advanced: bring your own editor"
		This works in the opposite direction too; any changes you make to the source file, say in your favorite editor, will automatically be reflected in the notebook in your browser! To enable this feature, just add this keyword to the function that was used to start Pluto:

		```julia-repl
		julia> using Pluto
		
		julia> Pluto.run(auto_reload_from_file=true)
		
		# This will be on by default in an upcoming release =]
		```

		The location of the file for this notebook is displayed in the bar at the very top of this page, and can also be modified there if you want to change where this notebook lives.

	Periodically throughout the notebook we will include collapsible sections like the one below to provide additional information about items outside the scope of this lab that may be of interest (e.g., plotting, working with javascript, creating widgets).

	$(msg(msg_adding_colors))

	In the local version of this notebook, an "eye" icon will appear at the top left of each cell on hover to reveal the underlying code behind it and a `Live Docs` button will also be available in the bottom right of the page to pull up documentation for any function that is currently selected. In both local and online versions of this notebook, user defined functions and variables are also underlined, and (ctrl) clicking on them will jump to where they are defined. For more examples of using these notebooks for Unistellar science, check out our recent [Spectroscopy Lab](https://icweaver.github.io/UCAN/spectroscopy/notebook.html)!
"""

# ╔═╡ 7654e284-65ac-4a12-afdb-ca318aa9fda9
md"""
!!! note ""
	`fitscollection`: Function from [CCDReductions.jl](http://juliaastro.org/CCDReduction.jl/stable/) to quickly summarize fits header info

!!! note ""
	`@transform`: Macro from [DataFramesMeta.jl](https://juliadata.org/DataFramesMeta.jl/stable/) to make changes to our data frames. In this case, converting one of the columns from string format to DateTime format so we can work with dates later

!!! note ""
	`|>`: Also known as the [pipe operator](https://docs.julialang.org/en/v1/manual/functions/#Function-composition-and-piping), this is a convenient way to pass the output of one function as input to the next. For example,

	```julia
	sqrt(sum([1, 4, 5, 6])) # 4.0
	```

	is equivalent to:

	```julia
	[1, 4, 5, 6] |> sum |> sqrt # 4.0
	```

!!! note ""
	`pretty`: Uses `pretty_table` function from [PrettyTables.jl](https://ronisbr.github.io/PrettyTables.jl/stable/) for nice HTML table formatting in the notebook
""" |> msg

# ╔═╡ 8161347d-e584-4ed2-ab80-55ae56ca8755
function align_frames(imgs)
	movs = []
	fixed = first(imgs)
	push!(movs, fixed)
	# mov_old = first(movs)
	for i in 2:length(imgs)
		arr_new, params = align_frame(fixed, imgs[i]; box_size = 9)
		mov_new = shareheader(imgs[1], arr_new)
		push!(movs, mov_new)
		# mov_old = mov_new
	end
	
	return movs
end

# ╔═╡ 37da7f88-82e1-452b-bef3-2bfc6afd3f95
imgs_sci_aligned = align_frames(imgs_sci);

# ╔═╡ 0bbb5bca-4fab-41f1-89ee-369f3dafff60
@bind frame_i_aligned Slider(1:length(imgs_sci_aligned); show_value=true)

# ╔═╡ d36ff8f2-8c11-4cec-a467-d97e19725268
df_phot = let
	# Run photometry
	phot = map(imgs_sci_aligned) do img
		photometry([ap_target, ap_comp1], img).aperture_sum
	end

	# Create table
	df = DataFrame(stack(phot; dims=1), :auto)
	insertcols!(df, 1, :t => df_sci."DATE-OBS")
	@transform! df :xdiv = :x1 ./ :x2
end

# ╔═╡ ca358bdb-83fd-4a7e-91b8-4e1a5d1d27ad
let
	sc = scatter(df_phot; x=:t, y=:xdiv, mode=:markers)
	l = Layout(;
		xaxis = attr(title="Time (UTC)"),
		yaxis = attr(title="Counts"),
		title = "Divided light curve",
	)
	plot(sc, l)
end

# ╔═╡ 8d6845a6-b543-4fe1-b9fc-487cfe34c057
function to_py(img)
	arr = np.zeros_like(img)
	PyArray(arr; copy=false) .= img
	return arr
end

# ╔═╡ 43eb7424-5861-46be-b670-dcec6125d963
md"""
### Plotly helper functions
"""

# ╔═╡ 1831c578-5ff8-4094-8f57-67c39aff80c8
# Set nice colorbar limit for visualizations
const zmin, zmax = AstroImages.PlotUtils.zscale(first(imgs_sci))

# ╔═╡ 1246d6fb-4d4f-46cb-a2e2-f2ceadf966a6
# Helpful for preventing ginormous plot objects
r2(img) = (restrict ∘ restrict)(img)

# ╔═╡ 7289692b-1a85-4a84-b7cc-fea1e46c9f31
# Plotly heatmap trace of img
function htrace(img;
	zmin = zmin,
	zmax = zmax,
	title = "ADU",
	restrict = true,
)
	# Reduce image, creates an offset array with different axis limits
	if restrict
		img_small = r2(img)
	else
		img_small = img
	end
		
	# Account for plotly orientation convention
	img_small = permutedims(img_small)
	
	# dims is used here to convert back from an offset array
	# to a simple array that JS can ingest
	heatmap(;
		x = img_small.dims[1].val,
		y = img_small.dims[2].val,
		z = Matrix{Float32}(img_small.data),
		zmin,
		zmax,
		colorbar = attr(; title),
		colorscale = :Cividis,
	)
end

# ╔═╡ 2ba90b91-5de2-44a2-954f-a73b1561e762
# Combines plotly trace and layout into a plot object
function plot_img(i, img; restrict=true)
	hm = htrace(img; restrict)
	
	width, height = size(img)

	if restrict
		width /= 2
		height /= 2
	else
		width *= 2
		height *= 2
	end

	l = Layout(;
		width,
		height,
		title = string("Frame $(i): ", timestamp(img)),
		xaxis = attr(title="X", constrain=:domain),
		yaxis = attr(title="Y", scaleanchor=:x, constrain=:domain),
		uirevision = 1,
	)

	plot(hm, l)
end

# ╔═╡ b49df71d-c470-466e-b845-8a004a3c6cd3
let
	p = plot_img(frame_i, imgs_sci[frame_i])
end

# ╔═╡ 84745bd9-c2b1-45c3-8376-7f18d600e7eb
# Julia photometry aperture object --> plotly shape object
function circ(ap; line_color=:lightgreen)
	circle(
		ap.x - ap.r, # x_min
		ap.x + ap.r, # x_max
		ap.y - ap.r, # y_min
		ap.y + ap.r; # y_max
		line_color,
	)
end

# ╔═╡ 3f243bc0-c223-475b-a05c-b89d431628d2
let
	p = plot_img(frame_i_aligned, imgs_sci_aligned[frame_i_aligned])
	shapes = [circ(ap_target), circ(ap_comp1; line_color=:orange)]
	relayout!(p; shapes)
	p
end

# ╔═╡ e9eb1a0f-553b-4477-8323-900191d469ee
md"""
### Packages
"""

# ╔═╡ c650df98-efe6-40a3-8b7f-8923f511f51f
TableOfContents()

# ╔═╡ Cell order:
# ╟─d7f0393d-e2fa-44ea-a812-8f85820e661e
# ╟─922e2770-d5c8-4a1b-8d1b-1eb20b1652b0
# ╟─0439db40-1572-4dac-af7e-d09d28631a37
# ╟─e0a51a72-9300-41d0-bc5c-44772350d6cc
# ╟─68d3d6ae-a0bd-468d-9b78-a2679b1c0be9
# ╟─d9431fb9-2713-4982-b342-988e01445fed
# ╠═5f9767e3-d46b-4f2e-9c16-52946c03ae71
# ╠═a1bd9062-65e3-494e-b3b9-aff1f4a0a1f2
# ╠═ac3a9384-1b18-47ee-b6f3-e7fb4b7a0594
# ╟─7654e284-65ac-4a12-afdb-ca318aa9fda9
# ╟─23a4ed9c-f75c-4fb3-ae34-035ca943fc94
# ╠═bb936bb4-42a4-4e8c-af2e-137bc8d23715
# ╟─0ea1caa7-8b16-47b3-a20f-3e5d02903198
# ╠═968bb800-5d85-4599-9a8a-95d9f689ee36
# ╟─5a53889d-e99d-44bf-8516-a1397867a2b2
# ╠═a4a703be-1c6e-4643-a173-1e738e667652
# ╟─355eb355-7db5-4df0-a5ee-9cbc599e1d6b
# ╠═b49df71d-c470-466e-b845-8a004a3c6cd3
# ╟─c7c9966e-d1f7-4a29-a53c-662794d06d74
# ╟─41b95ea0-0564-465f-a7b2-ba9bb3cda8cc
# ╟─67125878-7c40-4599-9555-969d05908cd7
# ╠═37da7f88-82e1-452b-bef3-2bfc6afd3f95
# ╟─60e9ac2c-728b-41ba-8863-8042daac4a16
# ╟─0bbb5bca-4fab-41f1-89ee-369f3dafff60
# ╠═3f243bc0-c223-475b-a05c-b89d431628d2
# ╠═79aed053-43f4-455a-9789-bfd615be015f
# ╠═9c8fe79d-5b58-41e9-9b65-6d075a5fb558
# ╠═ed39c72f-da61-4ee3-b459-b85977ab66a1
# ╠═5bf51644-08f2-46a4-bfeb-69118b3c1c4c
# ╠═d5c21fcc-e0d7-4c17-b9b7-628a9c36e7b6
# ╠═e28b90cf-c030-4be0-854d-1d11b709de28
# ╟─48cf49ce-26e7-424c-a2cb-59aabfba8576
# ╟─484c9b8d-339f-45c3-a52a-01c5dec1b46d
# ╠═8e7fe041-042d-4475-8c35-a14fc0c2d305
# ╠═2229f2f7-0a04-4383-b2ac-8db614b65a83
# ╟─156cda32-b464-42cc-aae0-d0a048f5cadc
# ╟─d36ff8f2-8c11-4cec-a467-d97e19725268
# ╟─93517d36-21b1-4fd8-bde9-c504681a6644
# ╟─ec96a17a-34d2-41d1-a036-7977ffee3450
# ╠═ca358bdb-83fd-4a7e-91b8-4e1a5d1d27ad
# ╟─041fd375-92a5-4204-bfdc-5409a04ba141
# ╟─977c59a8-25ed-47c9-a929-53c5c056d959
# ╠═97322d18-9784-4faf-aa88-9d54b9e67d68
# ╠═00595567-ea76-4bd5-8467-4f16e86a9855
# ╟─b4caa011-8492-426e-9efd-fc8fff7914d7
# ╠═afbe8ecd-6e20-478c-96c7-603db59959c7
# ╠═66bb240c-65a3-486f-8435-2841d2b9cc6a
# ╠═131f35b8-54f0-47e7-a19f-d3fb73f42337
# ╟─e03244d5-0691-431b-9f13-2d03fdb5a4ee
# ╟─66a1bc55-a265-421b-99a0-9cfe44d2eb7e
# ╟─2914603e-6b55-48a5-a269-8c44cde31237
# ╟─4078e4f6-3295-44b2-8fed-e6a628a74b5f
# ╟─99273ce1-548e-43f1-ad42-31ebd2db34e7
# ╟─fa066775-a63b-49c8-a368-0d033fb01a6e
# ╟─70ec6ef2-836b-4d9a-86a4-4956d8dc28f3
# ╟─e728e458-24dd-4f5d-bdf3-be9d34e4cc14
# ╟─fc17ef61-5747-4a35-8ae7-2d7c3ba6b075
# ╠═8161347d-e584-4ed2-ab80-55ae56ca8755
# ╠═8d6845a6-b543-4fe1-b9fc-487cfe34c057
# ╟─43eb7424-5861-46be-b670-dcec6125d963
# ╠═1831c578-5ff8-4094-8f57-67c39aff80c8
# ╟─1246d6fb-4d4f-46cb-a2e2-f2ceadf966a6
# ╟─7289692b-1a85-4a84-b7cc-fea1e46c9f31
# ╠═2ba90b91-5de2-44a2-954f-a73b1561e762
# ╟─84745bd9-c2b1-45c3-8376-7f18d600e7eb
# ╟─e9eb1a0f-553b-4477-8323-900191d469ee
# ╠═40272038-3af6-11ef-148a-8be0002c4bda
# ╠═c650df98-efe6-40a3-8b7f-8923f511f51f
