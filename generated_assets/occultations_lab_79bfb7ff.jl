### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> image = "https://www.seti.org/media/h3ejkrf3/image_0.png"
#> title = "Asteroid Occultations Lab"
#> date = "2025-08-01"
#> tags = ["time series", "asteroids"]
#> description = "Observe a nearby asteroid occulting a background source."
#> layout = "layout.jlhtml"

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
	Pkg.activate(mktempdir())
	Pkg.add(["PlutoUI", "CommonMark", "CCDReduction", "DataDeps", "DataFramesMeta", "AstroImages", "PlutoPlotly", "Photometry", "Dates", "Unitful", "UnitfulAstro", "Statistics", "ImageFiltering", "ImageCore", "Measurements"])
	
	Pkg.add([		 
	Pkg.PackageSpec(; rev = "main", url = "https://github.com/JuliaAstro/Astroalign.jl"),
	])
	
	# Notebook UI
	using PlutoUI, CommonMark
	
	# Data wrangling
	using CCDReduction, DataDeps, DataFramesMeta

	# Visualization and analysis
	using AstroImages, PlutoPlotly, Photometry, ImageCore, ImageFiltering, Statistics
	using AstroImages: restrict
	using Astroalign
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
		["https://www.dropbox.com/scl/fo/go5ensqkpuumkhimuzy2p/ANQJTr6oGTsyz1y0hLbPHIc?rlkey=bqcvalmv9mxptpp5duirj1auv&st=u59r839k&dl=1"],
		["9ad9e40401024482672a79dcb59da2a11d4ec4ebd4d185b35abb79eb9adef334"],
		post_fetch_method = unpack,
	) |> register
end;

# ╔═╡ d7f0393d-e2fa-44ea-a812-8f85820e661e
md"""
# 🪨 Asteroid Occultations Lab

In this lab we will observe an asteroid passing in front of a star in real time and explore how to produce and analyze its resulting light curve. For more on taking these types of observations, see our [Unistellar Science page here](https://science.unistellar.com/asteroid-occultations/).
"""

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

We start by loading in the raw sample data:
"""

# ╔═╡ 0773bdbd-ecd1-49c9-9516-f58e3096e7b7
const DATA_DIR = datadep"data";

# ╔═╡ a1bd9062-65e3-494e-b3b9-aff1f4a0a1f2
df_sci = let
	df = fitscollection("data/"; abspath=false)
	@transform! df :"DATE-OBS" = DateTime.(:"DATE-OBS")
end; # Semicolon hides automatic output

# ╔═╡ ac3a9384-1b18-47ee-b6f3-e7fb4b7a0594
# Just show the first 10 rows
first(df_sci, 10)

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
# imgs_sci = [load(f) for f in df_sci.path];

# ╔═╡ 6daddc3d-9e14-4e90-9515-00f25f56e3c9
imgs_sci = map(eachrow(df_sci)) do f
	img = load(f.path)
	# mapwindow!(median!, similar(img), img, (3, 3)) # Good for catching hot pixels
end;

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

To accomplish this, we will just align on asterisms instead. We will use [Astroalign.jl](https://juliaastro.org/Astroalign/stable/) to accomplish this:
"""

# ╔═╡ c1520903-9d12-471b-be03-ac8009a79431
arrs_aligned = align_frames(imgs_sci; box_size = (3, 3));

# ╔═╡ 3a4c38b4-0aaa-45ea-855d-acbc8bc5a265
imgs_sci_aligned = let
    imgs_aligned = map(imgs_sci, arrs_aligned) do img0, img
        shareheader(img0, img)
    end
    [imgs_sci[begin], imgs_aligned...]
end;

# ╔═╡ 60e9ac2c-728b-41ba-8863-8042daac4a16
md"""
With these aligned images, we can now pop some static apertures onto our frames to perform our photometry more reliably. The target is in the green aperture near the center of the frame, and for fun a sample comparison star is in the orange aperture. We went for a fairly tight aperture size to boost the signal-to-noise ratio of our final light curve.
"""

# ╔═╡ 0bbb5bca-4fab-41f1-89ee-369f3dafff60
@bind frame_i_aligned Slider(1:length(imgs_sci_aligned); show_value=true)

# ╔═╡ fc8c9cd5-166a-42f5-ac2c-7bcd259a772a
df_sci

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

# ╔═╡ 93517d36-21b1-4fd8-bde9-c504681a6644
md"""
!!! note
	The first column is time, `x1` is the target flux, `x2` is the comparison star flux, and `xdiv` is the target flux divided by the comparison star flux.
"""

# ╔═╡ ec96a17a-34d2-41d1-a036-7977ffee3450
md"""
Below is the resulting light curve for our target. The occultation signal is quite striking:
"""

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

# ╔═╡ c650df98-efe6-40a3-8b7f-8923f511f51f
TableOfContents()

# ╔═╡ fa066775-a63b-49c8-a368-0d033fb01a6e
md"""
### Convenience functions
"""

# ╔═╡ 1831c578-5ff8-4094-8f57-67c39aff80c8
# Set nice colorbar limit for visualizations
const zmin, zmax = AstroImages.PlotUtils.zscale(first(imgs_sci))

# ╔═╡ 70ec6ef2-836b-4d9a-86a4-4956d8dc28f3
timestamp(img) = header(img)["DATE-OBS"]

# ╔═╡ fc17ef61-5747-4a35-8ae7-2d7c3ba6b075
msg(x; title="Details") = details(title, x)

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
""" |> msg

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
	img = AstroImage(img)
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

# ╔═╡ 649ebb55-5952-457a-97c4-128893d66b73
function plot_anim(imgs)
    N = length(imgs)
    zmin, zmax = AstroImages.PlotUtils.zscale(first(imgs))

    frames = map(1:N) do i
		p = plot_img(i, imgs[i]; zmin, zmax)
		
		frame(;
			data = collect(p.data),
			name = "frame_$(i)",
			layout = attr(title_text = p.layout.title),
			traces = [0],
		)
	end

    layout = Layout(;
		title = first(frames).layout.title,
		shapes,
        width = 500,
		height = 500,
		margin_b = 90,
        updatemenus = [
			attr(
            	type = "buttons",
				direction = "left",
				x = 0.5,
				y = 0,
				xanchor = "center",
				yanchor = "top",
            	pad_t = 90,
	            buttons = [
	                attr(
						label = "▶ Play",
						method = "animate",
	                    args = [
							nothing,
							attr(
								fromcurrent = true,
								transition_duration = 0,
								frame = attr(duration = 200, redraw = true)
							),
						],
					),
	                attr(
						label = "⏸ Pause",
						method = "animate",
	                    args = [
							[nothing],
							attr(
								mode = "immediate",
	                         	frame = attr(duration = 0, redraw = true)
							),
						],
					),
	            ],
        	),
		],
        sliders = [
			attr(
				active = 0,
				pad_t = 10,
	            steps = [
	                attr(
						method = "animate",
						label = "$(i)",
	                    args = [
							["frame_$(i)"],
							attr(
								mode = "immediate",
								transition_duration = 0,
								frame = attr(duration = 5, redraw = true))
						],
					)
	                for i in 1:N
	            ],
        	),
		],
    )

    plot(first(frames).data, layout, frames)
end

# ╔═╡ 5997416a-266e-48d8-87ca-80fec3fe0e0a
md"""
### Data handling
"""

# ╔═╡ e9eb1a0f-553b-4477-8323-900191d469ee
md"""
### Packages
"""

# ╔═╡ Cell order:
# ╟─d7f0393d-e2fa-44ea-a812-8f85820e661e
# ╟─68d3d6ae-a0bd-468d-9b78-a2679b1c0be9
# ╟─d9431fb9-2713-4982-b342-988e01445fed
# ╠═0773bdbd-ecd1-49c9-9516-f58e3096e7b7
# ╠═a1bd9062-65e3-494e-b3b9-aff1f4a0a1f2
# ╟─ac3a9384-1b18-47ee-b6f3-e7fb4b7a0594
# ╟─7654e284-65ac-4a12-afdb-ca318aa9fda9
# ╟─23a4ed9c-f75c-4fb3-ae34-035ca943fc94
# ╠═bb936bb4-42a4-4e8c-af2e-137bc8d23715
# ╟─0ea1caa7-8b16-47b3-a20f-3e5d02903198
# ╠═968bb800-5d85-4599-9a8a-95d9f689ee36
# ╟─5a53889d-e99d-44bf-8516-a1397867a2b2
# ╠═a4a703be-1c6e-4643-a173-1e738e667652
# ╠═6daddc3d-9e14-4e90-9515-00f25f56e3c9
# ╟─355eb355-7db5-4df0-a5ee-9cbc599e1d6b
# ╠═b49df71d-c470-466e-b845-8a004a3c6cd3
# ╟─c7c9966e-d1f7-4a29-a53c-662794d06d74
# ╟─41b95ea0-0564-465f-a7b2-ba9bb3cda8cc
# ╟─67125878-7c40-4599-9555-969d05908cd7
# ╠═c1520903-9d12-471b-be03-ac8009a79431
# ╠═3a4c38b4-0aaa-45ea-855d-acbc8bc5a265
# ╟─60e9ac2c-728b-41ba-8863-8042daac4a16
# ╟─0bbb5bca-4fab-41f1-89ee-369f3dafff60
# ╠═3f243bc0-c223-475b-a05c-b89d431628d2
# ╠═fc8c9cd5-166a-42f5-ac2c-7bcd259a772a
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
# ╠═c650df98-efe6-40a3-8b7f-8923f511f51f
# ╟─fa066775-a63b-49c8-a368-0d033fb01a6e
# ╠═1831c578-5ff8-4094-8f57-67c39aff80c8
# ╟─70ec6ef2-836b-4d9a-86a4-4956d8dc28f3
# ╟─fc17ef61-5747-4a35-8ae7-2d7c3ba6b075
# ╟─1246d6fb-4d4f-46cb-a2e2-f2ceadf966a6
# ╠═7289692b-1a85-4a84-b7cc-fea1e46c9f31
# ╟─2ba90b91-5de2-44a2-954f-a73b1561e762
# ╟─84745bd9-c2b1-45c3-8376-7f18d600e7eb
# ╟─649ebb55-5952-457a-97c4-128893d66b73
# ╟─5997416a-266e-48d8-87ca-80fec3fe0e0a
# ╟─e9eb1a0f-553b-4477-8323-900191d469ee
# ╠═40272038-3af6-11ef-148a-8be0002c4bda
