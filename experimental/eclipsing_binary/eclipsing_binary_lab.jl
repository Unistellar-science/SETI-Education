### A Pluto.jl notebook ###
# v0.20.17

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

# ╔═╡ 6bc5d30d-2051-4249-9f2a-c4354aa49198
begin
	import Pkg
	Pkg.activate(Base.current_project())
	
	# Notebook UI
	using PlutoUI, CommonMark
	
	# Data wrangling
	using CCDReduction, DataDeps, DataFramesMeta

	# Web
	using HTTP, JSONTables, TableScraper
	
	# Visualization and analysis
	using Astroalign
	using AstroImages, PlutoPlotly, AstroAngles, Photometry, ImageCore
	using AstroImages: restrict
	using Dates, Unitful 

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
		["https://www.dropbox.com/scl/fo/om02nzsex9ql00gcnp0r4/AA11_SrUS2GUwvuMUQm85x8?rlkey=np5upxstx4z6lhcch6tje1b0j&st=st2wzmyp&dl=1"],
		# ["1ee0a7459a5a4e5fcec433a7bfbdcdfaf04844a7b081dcb181ecf5355a38eb25"],
		post_fetch_method = unpack,
	) |> register

	Pkg.status()
end

# ╔═╡ 635efbd3-bed2-4236-9eb2-c816a713990b
using Statistics

# ╔═╡ 3d8a4c43-1a17-4a36-84e8-47a98493ca99
md"""
# ⚪ ⚫ Unistellar Eclipsing Binary Lab

In this lab we will observe an eclipsing binary in real time and explore how to produce a light curve for it.

Having some familiarity in high-level programming languages like Julia or Python will be useful, but not necessary, for following along with the topics covered. At the end of this notebook, you will hopefully have the tools to build your own analysis pipelines for processing astronomical photometry, as well as understand the principles behind other astronomical software at a broad level.
"""

# ╔═╡ f0678404-72db-4bfd-9a44-ef0b66f3a64f
md"""
With this requisite information out of the way, let's get started!
"""

# ╔═╡ 49e1559e-bb19-4e8e-a9a9-67cb2c2d6931
msg_adding_colors = md"""
##### Adding colors in Julia 🎨
This makes magenta!

```julia
using ImageCore

RGB(1, 0, 0) + RGB(0, 0, 1)
```

$(RGB(1, 0, 0) + RGB(0, 0, 1))
""";

# ╔═╡ 84d9ed94-11cb-4272-8bd3-d420c50f990d
msg(x; title="Details") = details(title, x);

# ╔═╡ 14e0627f-ada1-4689-9bc6-c877b81aa582
cm"""
!!! note "Using this notebook"
	Some parts of this [Pluto notebook](https://plutojl.org/) are partially interactive online, but for full interactive control, it is recommended to download and run this notebook locally. For instructions on how to do this, click the `Edit or run this notebook` button in the top right corner of the page, or [click on this direct link](https://computationalthinking.mit.edu/Fall23/installation/) which includes a video and written instructions for getting started with Julia and Pluto 🌱.

	!!! tip "Coffee break? ☕"
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

# ╔═╡ aa005b55-626e-41e0-8fe1-137bd7dd5599
md"""
## Background 📖

It turns out that the alien world described in the [3 Body Problem](https://www.netflix.com/tudum/articles/3-body-problem-teaser-release-date) is not too far off from what we see in reality. Star systems can be made up of just one star like in our system, three as in the tv show and book series from which the 3 Body Problem [draws its inspiration](https://en.wikipedia.org/wiki/Alpha_Centauri), or even as many as six different stars as in this [recently discovered system](https://science.nasa.gov/universe/exoplanets/discovery-alert-first-six-star-system-where-all-six-stars-undergo-eclipses/)! While these would make for some quite interesting sunsets, a system's stability decreases as more bodies are added. This is partly why the most common star systems we see are singular star systems, followed closely behind by binary systems, which have two stars and account for [nearly two-thirds of all star systems in the Milky Way](https://pweb.cfa.harvard.edu/news/most-milky-way-stars-are-single).

A sub-class of this binary star case, known as eclipsing binaries, has proved to be an invaluable tool for helping us learn more about [orbital mechanics and stellar evolution](https://www.aavso.org/introduction-why-are-eclipsing-binary-stars-important). In these types of systems, not only do these two stars orbit about their common center-of-mass, but they do so along our line of sight. In other words, eclipsing binaries are star systems where each star passes in front of the other from our vantage point. As they do so, the combined light that we receive from both objects will vary in time.
"""

# ╔═╡ 4266575e-e19f-48e4-8b21-6f296c6d3f33
md"""
$(Resource("https://upload.wikimedia.org/wikipedia/commons/transcoded/7/7e/Artist%E2%80%99s_impression_of_eclipsing_binary.ogv/Artist%E2%80%99s_impression_of_eclipsing_binary.ogv.720p.vp9.webm"))

*ESO/L. Calçada*

In this visualization, we see how the observed brightness of an eclipsing binary system changes based on how much of each star is visible at a given point in time from our perspective. When they are both unobstructed the measured brightness is maximum, and when one is partially covered by the other, the combined brightness decreases periodically over time. In this lab, we will capture this dance going on in real time in a fairly popular constellation.
"""

# ╔═╡ aaaaa4d6-737b-4e53-a3a4-fcac09789d4e
md"""
## Introduction 🤝

[W Ursae Majoris (W UMa)](https://www.aavso.org/vsots_wuma) is an eclipsing binary system located in the [Ursa Major](https://en.wikipedia.org/wiki/Ursa_Major) constellation, and can be seen being chased across the sky by the Big Dipper throughout the night:

$(Resource("https://github.com/icweaver/UCAN/blob/main/EBs/data/constellation_WUMa.png?raw=true"))

*W UMa is marked by the larger, red dot to the right of the Big Dipper*
"""

# ╔═╡ c1bbb6a2-6996-4fee-a642-a0212b473474
md"""
Discovered in the early 1900s, this system is composed of two main-sequence F-type stars orbiting so closely together that they are expected to be [contact binaries](https://en.wikipedia.org/wiki/Contact_binary), meaning they share a common gaseous envelope. Their proximity to each other also gives this system an astonishingly short orbital period of just over 8 hours. Because of how neatly this fits into an Earth day, eclipse events occur at almost the same time every night, making them the ideal target for regular follow-up study. When the fainter of the two passes in front of the brighter one, we call that a _primary eclipse_, and when the brighter companion passes in front of the fainter one, we call it a _secondary eclipse_.

According to the [AAVSO ephemeris](https://www.aavso.org/sites/default/files/AAVSO_%20EB_Ephemeris_%202024.pdf) for this system, primary and secondary eclipsed are predicted to occur around **3:00 and 7:00 UTC**, respectively. Due to the similar sizes and spectral types of each star, the eclipse depths for both are fairly similar and can vary by almost a whole apparent magnitude! With a total duration of about three hours, the entire light curve for a given eclipse can be captured in a single night.

!!! tip
	For more on reading eclipsing binary ephemerides, please see this [AAVSO resource](https://www.aavso.org/how-use-eb-ephemeris).
"""

# ╔═╡ abb9a9c8-5cac-4af3-b0a0-b7a3608dfe1a
md"""
## Data inspection 🔎

For this lab, we will be using eVscope 2 data collected for this target on the night of March 25th, 2024. Observations were taken in the [exoplanet science mode](https://science.unistellar.com/exoplanets/tutorial/) with the following observation parameters:

```
Observing mode: Exoplanets
Eclipse mid-point: 23:00 PT
Eclipse duration: 3 hrs
Ra: 09h 43m 45.47s
Dec: +55° 57' 09.07"   
Duration: 3 hrs
Exposure time (ms): 1400
Cadence (ms): 4000
Recommended Gain (dB): 0
Max Gain (dB): 1.78
```


!!! note
	The sample data for this lab can be downloaded [here](https://drive.google.com/drive/folders/1P7PTtx9LUnR-QF_SWjszTBjCwpJHZ7AN?usp=sharing).
"""

# ╔═╡ b360ad74-58b7-47b5-a8b0-437ef1119303
md"""
Let's use [`fitscollection`](https://juliaastro.org/CCDReduction.jl/stable/api/#CCDReduction.fitscollection-Tuple{String}) from [CCDReductions.jl](https://github.com/JuliaAstro/CCDReduction.jl?tab=readme-ov-file) to take a quick glance at the fits files in this folder:

!!! note

	Much like an Excel spreadsheet, dependent cells are aware of each other, so package imports can be placed anywhere in the notebook. For organizational purposes, we have placed all package imports (like CCDReductions.jl) at the bottom of this notebook.
"""

# ╔═╡ 7c078085-ff30-400d-a0ab-2680f468c415
const DATA_DIR = datadep"data";

# ╔═╡ 1356c02f-9ff2-491f-b55d-666ee76e6fae
df_sci = let
	df = fitscollection(DATA_DIR; abspath=false)
	@transform! df :"DATE-OBS" = DateTime.(:"DATE-OBS")
end;

# ╔═╡ 06d26240-81b6-401b-8eda-eab3a9a0fb20
md"""
We see that we have $(nrow(df_sci)) fits files taken over the following period in UTC:
"""

# ╔═╡ 335a1a12-379a-4e0d-a3de-788369ae3818
df_sci[:, "DATE-OBS"] |> extrema

# ╔═╡ a04886d9-471a-40ec-9f0b-65ffe89932cf
md"""
and with the following header fields:
"""

# ╔═╡ 8a78029c-ddf5-4ada-b6d3-a9a649bdbae8
df_sci |> names |> print

# ╔═╡ cdf14fe8-6b27-44eb-b789-6cf072f4d184
msg(md"""
!!! note ""
	Also known as the [pipe operator](https://docs.julialang.org/en/v1/manual/functions/#Function-composition-and-piping), this is a convenient way to pass the output of one function as input to the next. For example,

	```julia
	sqrt(sum([1, 4, 5, 6])) # 4.0
	```

	is equivalent to:

	```julia
	[1, 4, 5, 6] |> sum |> sqrt # 4.0
	```
"""; title=md"What does `|>` do?")

# ╔═╡ a38466b5-c7fb-4600-904b-b7ddd7afd272
md"""
Let's use [AstroImages.jl](https://github.com/JuliaAstro/AstroImages.jl) to take a look at the image data for one of these files:
"""

# ╔═╡ 2b8c75f6-c148-4c70-be6a-c1a4b95d5849
img_sci = load(first(df_sci).path); # The semicolon hides automatic output

# ╔═╡ dbe812e2-a795-4caa-842d-07da5eabcade
reverse(img_sci)

# ╔═╡ 9d2b2434-7bd9-42c4-b986-34969101b285
md"""
and compare it to our corresponding [finder chart](https://astro.swarthmore.edu/transits/finding_charts.cgi) for our target:
"""

# ╔═╡ 74197e45-3b80-44ad-b940-f2544f2f9b54
Resource("https://github.com/icweaver/UCAN/blob/main/EBs/data/finder_WUMa.jpg?raw=true")

# ╔═╡ a6de852c-01e6-49a2-bc78-8d1b6eb51c0c
md"""
!!! note "Why did we reverse the image?"
	For easier comparison, we flipped our science frame image over the vertical axis so that it would be in the same orientation as our finder chart.

We have a match! Here is the associated header information for our science frame:
"""

# ╔═╡ 7d7cd508-be27-4f52-bc13-91c702450167
header(img_sci)

# ╔═╡ f6197e8e-3132-4ab5-86d7-32572e337c58
img_size, img_eltype = size(img_sci), eltype(img_sci)

# ╔═╡ 5abbcbe0-3ee6-4658-9c99-e4567a23e3f6
md"""
It looks like this image is $(first(img_size)) x $(last(img_size)) pixels, with the ADU counts for each pixel stored as a $(img_eltype) to reduce memory storage. Now that we know that we are pointing at the right place in the sky, let's take a look at the quality of our images.
"""

# ╔═╡ b7d3fb2b-c113-413c-b340-9dfb0a9b78af
md"""
### A note on image calibration

A critical step in analyzing astronomical data is accounting for sources of noise that may impact our final image. This process is known as calibration, and its purpose is to increase the signal-to-noise ratio of our science images. Here is a nice summary modified from [Practical Astrophotography](https://practicalastrophotography.com/a-brief-guide-to-calibration-frames/) of three of the main sources of noise that we typically try to calibrate for:

!!! note ""
	**Bias frames:** "Your camera inherently has a base level of read-out noise as it reads the values of each pixel of the sensor, called bias. When averaged out, basically it’s an inherent gradient to the sensor. Bias Frames are meant to capture this so it can be removed."

	**Dark frames:** "When taking a long exposure, the chip will introduce "thermal" noise. Its level is magnified by three things – temperature, exposure time, and ISO. Dark frames are used to subtract this sensor noise from your image and mitigate "hot or cold" pixels. (Some modern sensors automatically calculate dark levels and don't need dark frames). Dark Frames also will calibrate the chip so all pixels give the same value when not exposed to light."

	**Flat frames:** "I've seen people say flats help with light pollution. NOT TRUE AT ALL. Flat frames allow you to calculate the correction factor for each pixel so they all give the same value when exposed to the same quantity of light for a given optical path. Things like dust motes, lens vignetting consistently reduce the light to a given pixel, flat frames allow you to mathematically remove them to give a smooth evenly illuminated image."
"""

# ╔═╡ 2b32512b-63df-4a48-8e72-bf20aa75a845
md"""
Different flat fielding techniques are being examined by our team, but in general this has not been oberserved to be a significant source of noise in science mode observations. In practice, the [sensor calibration](https://help.unistellar.com/hc/en-us/articles/360011333600-Sensor-calibration-Dark-Frame-How-and-Why) step that is required at the end of science observations are set to the same gain and exposure time as your science images. By doing this, the bias frame is automatically built into the dark frames collected during this step, so no separate bias acquisition is needed.

We find that the contribution from dark noise does not impact our observations significantly, so we have excluded this calibration step for simplicity. Stay tuned for a future calibration notebook though where we will explore these procedures in more detail!
"""

# ╔═╡ 035fcecb-f998-4644-9650-6aeaced3e41f
imgs_sci = [load(f.path) for f in eachrow(df_sci)];

# ╔═╡ a1cb55ef-a33c-4506-bea4-aa6124026b75
md"""
We turn now (pun not intended) to the matter of field rotation.
"""

# ╔═╡ 6773c197-941e-4de0-b017-ec036fb851bb
md"""
### Field rotation

Before defining this phenomenon, let's first see it in action. Drag the slider below to scroll through each of our science frames. (Note for the rest of this notebook that we will be using the default image orientation in the plotting software):
"""

# ╔═╡ 5cc14d4f-d156-420c-a404-90c541217d83
md"""
!!! note "Apertures and comparison stars"

	To better show the frame to frame differences, we also added some sample target and comparison star aperturess (in green and orange, respectively) centered on the first frame in our image series. We use comparison stars to divide out common systematics like atmospheric turbulence and other changes in seeing conditions so that ideally only the target signal will be left.
"""

# ╔═╡ 916b8558-b49c-40b6-b9d3-9915d4fe75f0
ap_radius = 24

# ╔═╡ f1ed6484-8f6a-4fbf-9a3d-0fe20360ab3b
# Aperture object that will be used for photometry
# (x_center, y_center, radius)
ap_target = CircularAperture(1029, 782, ap_radius);

# ╔═╡ 954c7918-7dd1-4967-a67b-7856f00dc498
ap_comp1 = CircularAperture(1409, 999, ap_radius);

# ╔═╡ 59fd63bd-5df1-4a45-8505-f2b8c740e488
ap_comp2 = CircularAperture(1153, 711, ap_radius);

# ╔═╡ c06e64ef-4085-4bb5-9b8b-2ed244d5dbe8
md"""
Frame number: $(frame_slider = @bind frame_i Slider(1:length(imgs_sci); show_value=true))
"""

# ╔═╡ 7d54fd96-b268-4964-929c-d62c7d89b4b2
md"""
Uh-oh, we see that our images are literally rotating out from under us! This [field rotation](https://calgary.rasc.ca/field_rotation.htm) and also some drift that needed to be manually corrected partway through the observation are normal effects of taking long duration observations on an alt-az mount. Fortunately, it is fairly manageable to handle this as we will see in the next section.
"""

# ╔═╡ 1df329a0-629a-4527-8e5d-1dbac9ed8497
md"""
## Image alignment 📐

A typical astronomical observation might use the know RA and Dec of the field to [plate solve](https://astrobackyard.com/plate-solving/) each frame against background sources (see, e.g., [astrometry.net](https://astrometry.net/)). This then gives a coordinate transformation (e.g., with the [World Coordinate System (WCS) standard](https://fits.gsfc.nasa.gov/fits_wcs.html)) that can be applied to each frame to align them to a common grid with open source tools like [AstroImageJ](https://www.astro.louisville.edu/software/astroimagej/). Unfortunately, plate solving is a computationally expensive process that can take quite a while, especially if we have a large number of frames. Fortunately, there is a nice alternative that we can use if we do not care about the WCS information: [asterisms](https://en.wikipedia.org/wiki/Asterism_(astronomy)).

In this process, one frame is aligned to another in much the same way that human brain might: by matching common shapes between each frame to each other. This works indpendently of WCS information, so it completely avoids the need to plate solve our images. We will employ the Python package [`astroalign`](https://astroalign.quatrope.org/en/latest/index.html) to perform this process.
"""

# ╔═╡ d6bba196-213e-4c90-8d8e-f2ffc8108da6
md"""
!!! tip "Future work"
	Stay tuned for an upcoming notebook where we will examine this asterism alignment process in more depth!
"""

# ╔═╡ e7ad4e24-5dc9-4713-836a-be001304e45c
md"""
Let's see how our aligned frames look below:
"""

# ╔═╡ 102ce649-e560-470e-afa5-699db577e148
md"""
Nice! The rotation looks to have been successfuly transformed out. We turn next to computing the photometry for our aligned series of frames.
"""

# ╔═╡ bdc24b15-d14a-422c-a7aa-5335547fa53c
function align_frames(imgs)
	fixed = first(imgs)
	frames_aligned = map(imgs[begin+1:end]) do img
		img_aligned, params = align_frame(fixed, img; box_size = 19)
		shareheader(img, img_aligned)
	end
	return [fixed, frames_aligned...]
end

# ╔═╡ 1fe59945-8bce-44f3-b548-9646c2ce6bda
imgs_sci_aligned = align_frames(imgs_sci);

# ╔═╡ 73e16c0e-873c-46a3-a0fd-d7ed5405ed7b
md"""
Frame number: $(frame_slider_aligned = @bind frame_i_aligned Slider(1:length(imgs_sci_aligned); show_value=true))
"""

# ╔═╡ d6d19588-9fa5-4b3e-987a-082345357fe7
md"""
## Aperture photometry 🔾

Now that we have some science frames to work with, the next step is to begin counting the flux coming from our target system so that we can measure it over time. We will use the [Photomtery.jl](https://github.com/JuliaAstro/Photometry.jl) package which is inspired by other tools like astropy's [`photutils`](https://github.com/astropy/photutils) and C's [`SEP`](https://github.com/kbarbary/sep) library to perform the photometry. 

!!! note
	More at <https://juliaastro.org/dev/modules/AstroImages/guide/photometry/>
"""

# ╔═╡ 381d0147-264b-46f6-82ab-8c840c50c7d1
aps = [ap_target, ap_comp1, ap_comp2]

# ╔═╡ 79c924a7-f915-483d-aee6-94e749d3b004
aperture_sums = map(imgs_sci_aligned) do img
	# Returns (x_center, y_center, aperture_sum)
	# for each aperture
	p = photometry(aps, img)
	
	# Just store the aperture sum for each frame
	p.aperture_sum
end;

# ╔═╡ 0d07e670-4ddb-41ce-ac2c-60991a52ded4
md"""
We now have a vector of aperture sums, one row per frame, one set of aperture sums per frame in the order of our aperture list `aps`. This lends itself naturally to a matrix where each row is a given frame, and each column is an aperture (target, comp1, etc.), so let's convert it to one and view it with its corresponding observation times in a DataFrame:
"""

# ╔═╡ 96dc5bbe-3284-43a0-8c04-c1bb51ad618b
df_phot = let
	# `stack` converts to a Matrix
	# `:auto` names the columns for us
	# `copycols` sets whether we want a view or copy of the source matrix 
	data = stack(aperture_sums; dims=1)
	data ./ median(data; dims=1)
	
	df = DataFrame(data, :auto; copycols=false)

	@transform! df begin
		:x1 = :x1 / median(:x1)
		:x2 = :x2 / median(:x2)
		:x3 = :x3 / median(:x3)
	end
	
	# Place the observation time in the first column
	insertcols!(df, 1, :t => df_sci.:"DATE-OBS")
end

# ╔═╡ 15ad7461-9c40-4755-8f00-14aa3be53e0f
md"""
By convention, `t` is our observation time, `x1` is for our target star, and `x2` and up are our comparison stars. We can now visualize the light curve of our target from our photometry table:
"""

# ╔═╡ 6470b357-4dc6-4b2b-9760-93d64bab13e9
let
	# Switch to long "tidy" format to use convenient plotting syntax
	p = plot(stack(df_phot);
		x = :t,
		y = :value,
		color = :variable,
		mode = :markers,
	)

	layout = Layout(
		xaxis = attr(title="Date (UTC)"),
		yaxis = attr(title="Relative aperture sum"),
		title = "Source light curves",
		legend_title_text = "Source",
	)
	
	relayout!(p, layout)

	p
end

# ╔═╡ 17eb5723-71f4-4344-b1b1-41b894e7582b
md"""
And divide by a sample comparison star  (the first one):
"""

# ╔═╡ 59392770-f59e-4188-a675-89c2f2fc67d9
let
	sc = scatter(x=df_phot.t, y=df_phot.x1 ./ df_phot.x2, mode = :markers,)

	layout = Layout(
		xaxis = attr(title="Date (UTC)"),
		yaxis = attr(title="Relative aperture sum"),
		title = "W UMa divided light curve",
		legend_title_text = "Source",
	)
	
	plot(sc, layout)
end

# ╔═╡ e34ceb7c-1584-41ce-a5b5-3532fac3c03d
md"""
### Wrapping up

We now have a light curve of an eclipsing binary captured at the predicted time! By eye, totality looks to have lasted for about half an hour, and the total eclipse duration looks to be close to the three hours estimated by the ephemeris. Not too bad for a quick observation taken from a backyard in the middle of a light polluted city.

Since the total period for this system is about 8 hours, we only caught one of the eclipses, in this case the secondary eclipse. With a more careful treatment of the calibration and data reduction procedures, we might also be able to measure the eclipse depth as well as get a more precise estimate on the "time of minimum" (ToM). The former allows us to determine the size of the eclipsing object relative to its companion, and the latter is the precise time that the two objects are exactly aligned. Measuring the ToM over time create so-called "[O-C curves](https://www.aavso.org/analysis-times-minima-o-c-diagram)", or observed minus calculated (predicted) times over time, which allow us to not only measure the periods of binary systems, but also characterize the stellar and orbital evolution of these dynamic systems.
"""

# ╔═╡ 276ff16f-95f1-44eb-971d-db65e8821e59
md"""
## Extensions 🌱
"""

# ╔═╡ 934b1888-0e5c-4dcb-a637-5c2f813161d4
md"""
### Other systematics

Although this was a fairly bright target with a relatively large [signal-to-noise ratio](http://spiff.rit.edu/classes/ast613/lectures/signal/signal_illus.html), its resulting light curve still contains systematics that can be addressed.
"""

# ╔═╡ c5286692-2610-414d-97b7-ffab0bd485a7
md"""
### Observing other eclipsing binary systems

The AAVSO has a great [web interface](https://targettool.aavso.org/) for finding other potential eclipsing binary targets. Below, we briefly show how this could be accessed in a programmatic fashion using [their API](https://targettool.aavso.org/TargetTool/api). If there is interest, we may publish a separate lab on just this topic.
"""

# ╔═╡ 4a6a8956-f6e5-433a-a87b-056a5123ffbc
md"""
We start by [creating an account](https://targettool.aavso.org/init/default/user/register?_next=/init/default/index) on AAVSO. This will allow us to access their API and set our observing location. Once we are logged in, our API key will be displayed as a string of numbers and letters across the top of the [API webpage](https://targettool.aavso.org/TargetTool/api). Copy this key into a text file in your `data` folder, and name it `.aavso_key`. Select the `Query` button below to submit your query to AAVSO.
"""

# ╔═╡ 502fe5dd-d55a-450e-9209-60dc05f395dc
@bind submit_query Button("Submit Query")

# ╔═╡ 14998fe7-8e22-4cd4-87c6-9a5334d218ed
begin
	submit_query
	username = if isfile("data/.aavso_key")
		@debug "API key found"
		readline("data/.aavso_key")
	else
		@debug "No API key found"
		""
	end
end;

# ╔═╡ 4a779bd1-bcf3-41e1-af23-ed00d29db46f
md"""
!!! note
	This is your personal key. Do not share this with others.
"""

# ╔═╡ 7f9c4c42-26fc-4d02-805f-97732032b272
if !isempty(username)
	md"""
	We are now ready to query AAVSO for eclipsing binaries observable from our location. Using the [HTTP.jl](https://juliaweb.github.io/HTTP.jl/stable/) package, we send our query using the following format:

	```julia
	HTTP.get(url; query)
	```
	
	where `url` is entry point into the API (essentially what we would manually type into our browser window):
	
	```julia
	url = "https://{your api key here}:api_token@targettool.aavso.org/TargetTool/api/v1/targets"
	```
	
	and `query` is a key, value map (dictionary) of settings that we would like to pass to the API:

	```julia
	query = (
		# :latitude => 37.76329102360394,
		# :longitude => -122.41190624779506,
		:obs_section => "eb",
		:observable => true,
		:orderby => "period",
	)
	```
	
	Below is a list from the API page of what each of the inputs mean:

	!!! tip ""
		`obs_section` An array with observing sections of interest. You may use one or more of: ac,ep,cv,eb,spp,lpv,yso,het,misc,all. Default is \['ac'\] (Alerts & Campaigns).
		
		`observable` If true, filters out targets which are visible at the telescope location during the following nighttime period. Default is false.
		
		`orderby` Order by any of the output fields below, except for observability\_times and solar\_conjunction.
		
		`reverse` If true, reverses the order. Default is false.
		
		`latitude` Latitude of telescope. South is negative, North is positive. If not provided, the user's settings are assumed.
		
		`longitude` Longitude of telescope. West is negative, East is positive. If not provided, the user's settings are assumed.
		
		`targetaltitude` Minimum altitude that the telescope can observe in degrees relative to the horizon. If not provided, the user's settings are assumed.
		
		`sunaltitude` Altitude of sun at dusk and dawn in degrees. If not provided, the user's settings are assumed.
	"""
end

# ╔═╡ e927297b-9d63-4448-8245-4d73d1fbff27
md"""
Feel free to uncomment the lat/long fields below to override the default location set in your profile, or add any additional settings. We store our query in a [DataFrame](https://dataframes.juliadata.org/stable/) to view the first 10 results:
"""

# ╔═╡ 399f53c5-b654-4330-9ead-4d795917b03b
if !isempty(username)
	df_all = let
		api = "targettool.aavso.org/TargetTool/api/v1/targets"
		url = "https://$(username):api_token@$(api)"
		query = (
			# :latitude => 37.76329102360394,
			# :longitude => -122.41190624779506,
			:obs_section => "eb",
			# :observable => true,
			:orderby => "period",
		)
		r = HTTP.get(url; query)
		
		# The table under the `target` field of the JSONTable does not
		# seem to convert nulls to missings, so using the raw string directly instead
		DataFrame(jsontable(chop(String(r.body); head=12)))
	end
end;

# ╔═╡ c5e95837-fd89-4da2-b480-13f5ed788fb6
msg(md"""
!!! tip ""

	This is Julia's way of interpolating strings. For example:
	
	```julia
	animal = "dogs"
	"I like $(animal)!" # I like dogs!
	```
"""; title=md"What is `$()`?")

# ╔═╡ 29197489-441c-440d-9ce2-3dbd17fa53fc
msg(md"""
!!! tip ""
	We are using the [PrettyTables.jl](https://ronisbr.github.io/PrettyTables.jl/stable/) package to make the output of our DataFrames look a bit nicer in the browser. Try right clicking on the function to see where it is defined.
"""; title=md"What is `pretty`?")

# ╔═╡ f2c89a20-09d5-47f4-8f83-e59477723d95
!isempty(username) && nrow(df_all) # Total number of targets in our list

# ╔═╡ a00cbbfc-56ce-413a-a7b8-13de8541fa6f
if !isempty(username)
	md"""
	It looks like we have $(nrow(df_all)) hits, great! Let's filter these using some convenience syntax from [DataFramesMeta.jl](https://juliadata.org/DataFramesMeta.jl/stable/) to subset for targets that are easily observable, i.e., with our following criteria:

	1. Large change in brightness (at least half a mag)
	2. Fairly short period (period < 3 days)
	3. Includes an ephemeris (the `other_info` column must include this link)

	!!! note
		We also prioritize dimmer targets (V > 9.0). The reason for this is that we are taking a timeseries over the course of hours, which would lead to an unfeasable number of total science frames taken if the exposure time for each one needed to be dialed down for bright targets. Instead, we fix our exposure time to the maximum on eVscopes (4 seconds), and select targets that would not be overexposed at this level.
	
	Lastly, we select the columns that we care about and make some visual transforms for convenience (e.g., including units, converting decimal RA and Dec to `[h m s]`, and `[° ' "]` format, respectively, for easy copy-pasting into the Unistellar app):
	"""
end

# ╔═╡ fd7a53d1-2c6d-4d6a-b546-5c766c9a39d7
md"""
#### Convenience functions
"""

# ╔═╡ 46e6bba9-0c83-47b7-be17-f41301efa18e
function to_hms(ra_deci)
	hms = round.(deg2hms(ra_deci); digits=2)
	format_angle(hms; delim=["h ", "m ", "s"])
end

# ╔═╡ 77544f9e-6053-4ed6-aa9a-4e7a54ca41d9
function to_dms(ra_deci)
	dms = round.(deg2dms(ra_deci); digits=2)
	format_angle(dms; delim=["° ", "' ", "\""])
end

# ╔═╡ 3242f19a-83f7-4db6-b2ea-6ca3403e1039
function get_url(s)
	url = @chain s begin
		split("Ephemeris info ")
		last
		split("]]")
		first
	end
end

# ╔═╡ 1e5596fb-7dca-408b-afbd-6ca2e2487d75
get_shapes(aps; line_color=:lightgreen) = [
	circle(ap.x - ap.r/2, ap.x + ap.r/2, ap.y - ap.r/2, ap.y + ap.r/2;
		line_color,
	)
	for ap in aps
]

# ╔═╡ 2ea12676-7b5e-444e-8025-5bf9c05d0e2d
function ephem(url)
	st = scrape_tables(url)
	ephem_blob = st[3].rows
	if length(ephem_blob[2]) != 4
		error("Expected ephemeris to have Epoch, Start, Mid, and End. Received: ", ephem_blob[2])
	end
	ephem_title, ephem_data... = filter(x -> length(x) == 4, ephem_blob)
	return ephem_title, ephem_data
end

# ╔═╡ d359625e-5a95-49aa-86e4-bc65299dd92a
function deep_link(;
	mission = "transit",
	ra = 0.0,
	dec = 0.0,
	c = 4_000,
	et = 4_000,
	g = 0.0,
	d = 0.0,
	t = 0.0,
	scitag = "scitag",
)
	link = join([
		"unistellar://science/$(mission)?ra=$(ra)",
		"dec=$(dec)",
		"c=$(c)",
		"et=$(et)",
		"g=$(g)",
		"d=$(d)",
		"t=$(t)",
		"scitag=$(scitag)",
	], '&')

	Markdown.parse("[link]($(link))")
end

# ╔═╡ 829cde81-be03-4a9f-a853-28f84923d493
# Make the table view a bit nicer in the browser
pretty(df) = DataFrames.PrettyTables.pretty_table(HTML, df;
	maximum_columns_width = "max-width",
	show_subheader = false,
	header_alignment = :c,
)

# ╔═╡ edda8d09-ec46-4a0b-b1b2-b1289ee5456e
!isempty(username) && first(df_all, 10) |> pretty

# ╔═╡ 1d2bedb1-509d-4956-8e5a-ad1c0f1ffe26
md"""
### Determining observation parameters

Once a target has been found, here's how we might estimate an observing setup for it based on the [Unistellar Exposure Time and Gain Calculator](https://docs.google.com/spreadsheets/d/1niBg5LOkWyR8lCCOOcIo6OHt5kwlc3vnsBsazo7YfXQ/edit#gid=0).
"""

# ╔═╡ 9c482134-6336-4e72-9d30-87080ebae671
@bind target PlutoUI.combine() do Child
	cm"""
	!!! tip "Observation inputs"
		Enter your target's visual magnitude and desired exposure time (in milliseconds) below:
	
		
		|``V_\mathrm{mag}``|``t_\mathrm{exp}``|
		|------------------|------------------|
		|$(Child(:v_mag, NumberField(1:0.1:20; default=11.7)))|$(Child(:t_exp, NumberField(100:100:4_000; default=3_200))) (ms)
	"""
end

# ╔═╡ f290d98e-5a8a-44f2-bee5-b93738abe9af
# Keep these values untouched
const baseline = (
	v_mag = 11.7, # V (mag)
	t_exp = 3200.0, # Exptime (ms)
	gain = 25.0, # Gain (dB)
	peak_px = 3000, # Peak Pixel ADU
)

# ╔═╡ 3c601844-3bb9-422c-ab1e-b40f7e7cb0df
function flux_factor(target, baseline)
	f_mag = (target.v_mag - baseline.v_mag) / -2.5 |> exp10
	f_exp = target.t_exp / baseline.t_exp
	return f_mag * f_exp 
end

# ╔═╡ f26f890b-5924-497c-85a3-eff924d0470b
# Maximum gain
max_gain(baseline, f) = baseline.gain - log10(f) / log10(1.122)

# ╔═╡ 95a67d04-0a32-4e55-ac2f-d004ecc9ca84
# Recommended gain
rec_gain(g) = Int(round(g, RoundDown) - 1.0)

# ╔═╡ 6cec1700-f2de-4e80-b26d-b23b5f7f1823
if !isempty(username)
	df_candidates = @chain df_all begin
		dropmissing
		@rsubset begin
			:min_mag > 9.0 &&
			:min_mag - :max_mag ≥ 0.5 &&
			:min_mag_band == "V" && :max_mag_band == "V" &&
			:period ≤ 3.0 &&
			startswith(:other_info, "[[Ephemeris")
		end
		
		@rtransform :ephem_url = get_url(:other_info)
		
		@rtransform begin
			:star_name
			:period = round(Minute, :period * u"d") |> canonicalize
			:ra = to_hms(:ra)
			:ra_deci = :ra
			:dec = to_dms(:dec)
			:dec_deci = :dec
			:min_mag
			# :min_mag_band
			:max_mag
			:V_mag = (:min_mag + :max_mag) / 2.0
			# :max_mag_band
			# :var_type
			# :min_mag
			# :max_mag
			:ephem_link = Markdown.parse("[link]($(:ephem_url))")
			:ephem_url
			# :unix_timestamp = (last ∘ first)(:observability_times)
		end
		@rtransform begin
			:gain = let
				target = (v_mag=:V_mag, t_exp=4_000) # Default to max exp
				f_factor = flux_factor(target, baseline) 
				gain_max = max_gain(baseline, f_factor)
				rec_gain(gain_max)
			end
		end
	
		sort(:period)

		@select begin
			:star_name
			:period
			:ra
			:ra_deci
			:dec
			:dec_deci
			:V_mag
			:gain
			:ephem_link
			:ephem_url
		end
	end
end

# ╔═╡ 4042bc32-1a14-4408-974d-7405fd8c8ccc
!isempty(username) && df_candidates |> pretty

# ╔═╡ 95f9803a-86df-4517-adc8-0bcbb0ff6fbc
if !isempty(username)
	md"""
	We now have $(nrow(df_candidates)) prime candidates that we can plan our observations for. Clicking on the `ephem_link` in the last column should take us to a table on AAVSO with the predicted eclipse times for the next month. For convenience, we can also select one of the targets below to generate a table of deep links:

	!!! note
		This will only work for targets that have a complete ephemeris. All times are in UTC.
	"""
end

# ╔═╡ a5f3915c-6eed-480d-9aed-8fdd052a324a
!isempty(username) && @bind star_name Select(df_candidates.star_name)

# ╔═╡ 3f548bb1-37b0-48b7-a35c-d7701405a64e
if !isempty(username)
	df_selected = @rsubset df_candidates :star_name == star_name
end

# ╔═╡ 8a39fbbb-6b5b-4744-a875-469c289242fb
if !isempty(username)
	df_ephem = let
		ephem_title, ephem_data = ephem(only(df_selected.ephem_url))
		df = DataFrame(
			stack(ephem_data; dims=1),
			ephem_title,
		)
	
		fmt = dateformat"dd u YYYY HH:MM"
		@chain df begin
			@rtransform begin
				# :Epoch = parse(Float64, :Epoch)
				:star_name = only(df_selected.star_name)
				:Start = DateTime(:Start, fmt)
				:Mid = DateTime(:Mid, fmt)
				:End = DateTime(:End, fmt)
				
			end
			
			@rtransform begin
				:Duration = canonicalize(:End - :Start)
				:Duration_s = Second(:End - :Start).value
				:unix_timestamp_ms = 1_000 * datetime2unix(:Mid)
			end
		end
	end
end

# ╔═╡ 31c23e2b-1a2d-41aa-81c1-22868e241f7e
if !isempty(username)
	df_obs = let
		df = leftjoin(df_selected, df_ephem; on=:star_name)
		fmt = dateformat"yymmdd"
		@rselect df begin
			:star_name
			:Start
			:Mid
			:End
			:Duration
			:deep_link = deep_link(;
				ra = :ra_deci,
				dec = :dec_deci,
				g = :gain,
				d = round(Int, 1.5 * :Duration_s),
				t = round(Int, :unix_timestamp_ms),
				scitag = join([
					"e",
					Dates.format(:Mid, fmt),
					replace(:star_name, " " => ""),
				]),
			)
		end
	end

	df_obs |> pretty
end

# ╔═╡ 90b6ef16-7853-46e1-bbd6-cd1a904c442a
let
	f_factor = flux_factor(target, baseline)
	gain_max = max_gain(baseline, f_factor)
	gain_recommended = rec_gain(gain_max)

	@debug "Observing params" f_factor gain_max gain_recommended
end

# ╔═╡ 7d99f9b9-f4ea-4d4b-99b2-608bc491f05c
md"""
---
## Notebook setup 🔧
"""

# ╔═╡ 2baf0cba-7ef9-4dd5-bc68-bcdac7753b30
md"""
### Convenience functions and settings
"""

# ╔═╡ ab2bac2b-b2ba-4eaa-8444-439485627bad
# const width = round(Int, size(img_sci, 1) / 4) + 100

# ╔═╡ 48f4cdf3-b3d7-4cd6-8071-78292fec0db9
# const height = round(Int, width * size(img_sci, 2) / size(img_sci, 1))

# ╔═╡ 285a56b7-bb3e-4929-a853-2fc69c77bdcb
const clims = (150, 700);

# ╔═╡ a984c96d-273e-4d6d-bab8-896f14a79103
TableOfContents(; depth=4)

# ╔═╡ 21e828e5-00e4-40ce-bff5-60a17439bf44
# Helpful for not having ginormous plot objects
r2(img) = (restrict ∘ restrict)(img)

# ╔═╡ e35d4be7-366d-4ca5-a89a-5de24e4c6677
function htrace(img;
	zmin = 2_400,
	zmax = 3_200,
	title = "ADU",
	restrict = true,
)
	if restrict
		img_small = r2(img)
	else
		img_small = img
	end

	img_small = permutedims(img_small)
	
	heatmap(;
		x = img_small.dims[1].val,
		y = img_small.dims[2].val,
		z = img_small.data,
		zmin,
		zmax,
		colorbar = attr(; title),
		colorscale = :Cividis,
	)
end

# ╔═╡ a3bcad72-0e6c-43f8-a08d-777a154190d8
function circ(ap; line_color=:lightgreen)
	circle(
		ap.x - ap.r, # x_min
		ap.x + ap.r, # x_max
		ap.y - ap.r, # y_min
		ap.y + ap.r; # y_max
		line_color,
	)
end

# ╔═╡ 2e59cc0d-e477-4826-b8b6-d2d68c8592a9
# Convert to plotly objects for plotting
shapes = [
	circ(ap_target),
	circ(ap_comp1; line_color=:orange),
	circ(ap_comp2; line_color=:orange),
];

# ╔═╡ 8da80446-84d7-44bb-8122-874b4c9514f4
timestamp(img) = header(img)["DATE-OBS"]

# ╔═╡ 24256769-2274-4b78-8445-88ec4536c407
function plot_img(i, img; restrict=true)
	hm = htrace(img; restrict)
	
	l = Layout(;
		#width,
		#height,
		title = string("Frame $(i): ", timestamp(img)),
		xaxis = attr(title="X", constrain=:domain),
		yaxis = attr(title="Y", scaleanchor=:x, constrain=:domain),
		uirevision = 1,
	)

	plot(hm, l)
end

# ╔═╡ 86e53a41-ab0d-4d9f-8a80-855949847ba2
let
	p = plot_img(frame_i, imgs_sci[frame_i])
	relayout!(p; shapes)
	p
end

# ╔═╡ f3683998-543c-4bc4-8b73-fc1de6a6a955
let
	p = plot_img(frame_i_aligned, imgs_sci_aligned[frame_i_aligned])
	relayout!(p; shapes)
	p
end

# ╔═╡ 5b079ce8-3b28-4fe7-8df2-f576c2c948f5
md"""
### Packages
"""

# ╔═╡ Cell order:
# ╟─3d8a4c43-1a17-4a36-84e8-47a98493ca99
# ╟─14e0627f-ada1-4689-9bc6-c877b81aa582
# ╟─f0678404-72db-4bfd-9a44-ef0b66f3a64f
# ╟─49e1559e-bb19-4e8e-a9a9-67cb2c2d6931
# ╟─84d9ed94-11cb-4272-8bd3-d420c50f990d
# ╟─aa005b55-626e-41e0-8fe1-137bd7dd5599
# ╟─4266575e-e19f-48e4-8b21-6f296c6d3f33
# ╟─aaaaa4d6-737b-4e53-a3a4-fcac09789d4e
# ╟─c1bbb6a2-6996-4fee-a642-a0212b473474
# ╟─abb9a9c8-5cac-4af3-b0a0-b7a3608dfe1a
# ╟─b360ad74-58b7-47b5-a8b0-437ef1119303
# ╠═7c078085-ff30-400d-a0ab-2680f468c415
# ╠═1356c02f-9ff2-491f-b55d-666ee76e6fae
# ╟─06d26240-81b6-401b-8eda-eab3a9a0fb20
# ╠═335a1a12-379a-4e0d-a3de-788369ae3818
# ╟─a04886d9-471a-40ec-9f0b-65ffe89932cf
# ╠═8a78029c-ddf5-4ada-b6d3-a9a649bdbae8
# ╟─cdf14fe8-6b27-44eb-b789-6cf072f4d184
# ╟─a38466b5-c7fb-4600-904b-b7ddd7afd272
# ╠═2b8c75f6-c148-4c70-be6a-c1a4b95d5849
# ╠═dbe812e2-a795-4caa-842d-07da5eabcade
# ╟─9d2b2434-7bd9-42c4-b986-34969101b285
# ╟─74197e45-3b80-44ad-b940-f2544f2f9b54
# ╟─a6de852c-01e6-49a2-bc78-8d1b6eb51c0c
# ╠═7d7cd508-be27-4f52-bc13-91c702450167
# ╟─5abbcbe0-3ee6-4658-9c99-e4567a23e3f6
# ╠═f6197e8e-3132-4ab5-86d7-32572e337c58
# ╟─b7d3fb2b-c113-413c-b340-9dfb0a9b78af
# ╟─2b32512b-63df-4a48-8e72-bf20aa75a845
# ╠═035fcecb-f998-4644-9650-6aeaced3e41f
# ╟─a1cb55ef-a33c-4506-bea4-aa6124026b75
# ╟─6773c197-941e-4de0-b017-ec036fb851bb
# ╟─5cc14d4f-d156-420c-a404-90c541217d83
# ╠═916b8558-b49c-40b6-b9d3-9915d4fe75f0
# ╠═f1ed6484-8f6a-4fbf-9a3d-0fe20360ab3b
# ╠═954c7918-7dd1-4967-a67b-7856f00dc498
# ╠═59fd63bd-5df1-4a45-8505-f2b8c740e488
# ╠═2e59cc0d-e477-4826-b8b6-d2d68c8592a9
# ╟─c06e64ef-4085-4bb5-9b8b-2ed244d5dbe8
# ╟─86e53a41-ab0d-4d9f-8a80-855949847ba2
# ╟─7d54fd96-b268-4964-929c-d62c7d89b4b2
# ╟─1df329a0-629a-4527-8e5d-1dbac9ed8497
# ╠═1fe59945-8bce-44f3-b548-9646c2ce6bda
# ╟─d6bba196-213e-4c90-8d8e-f2ffc8108da6
# ╟─e7ad4e24-5dc9-4713-836a-be001304e45c
# ╟─73e16c0e-873c-46a3-a0fd-d7ed5405ed7b
# ╟─f3683998-543c-4bc4-8b73-fc1de6a6a955
# ╟─102ce649-e560-470e-afa5-699db577e148
# ╠═bdc24b15-d14a-422c-a7aa-5335547fa53c
# ╟─d6d19588-9fa5-4b3e-987a-082345357fe7
# ╠═381d0147-264b-46f6-82ab-8c840c50c7d1
# ╠═79c924a7-f915-483d-aee6-94e749d3b004
# ╟─0d07e670-4ddb-41ce-ac2c-60991a52ded4
# ╠═96dc5bbe-3284-43a0-8c04-c1bb51ad618b
# ╠═635efbd3-bed2-4236-9eb2-c816a713990b
# ╟─15ad7461-9c40-4755-8f00-14aa3be53e0f
# ╟─6470b357-4dc6-4b2b-9760-93d64bab13e9
# ╟─17eb5723-71f4-4344-b1b1-41b894e7582b
# ╟─59392770-f59e-4188-a675-89c2f2fc67d9
# ╟─e34ceb7c-1584-41ce-a5b5-3532fac3c03d
# ╟─276ff16f-95f1-44eb-971d-db65e8821e59
# ╟─934b1888-0e5c-4dcb-a637-5c2f813161d4
# ╟─c5286692-2610-414d-97b7-ffab0bd485a7
# ╟─4a6a8956-f6e5-433a-a87b-056a5123ffbc
# ╟─502fe5dd-d55a-450e-9209-60dc05f395dc
# ╟─14998fe7-8e22-4cd4-87c6-9a5334d218ed
# ╟─4a779bd1-bcf3-41e1-af23-ed00d29db46f
# ╟─7f9c4c42-26fc-4d02-805f-97732032b272
# ╟─e927297b-9d63-4448-8245-4d73d1fbff27
# ╠═399f53c5-b654-4330-9ead-4d795917b03b
# ╟─c5e95837-fd89-4da2-b480-13f5ed788fb6
# ╠═edda8d09-ec46-4a0b-b1b2-b1289ee5456e
# ╟─29197489-441c-440d-9ce2-3dbd17fa53fc
# ╠═f2c89a20-09d5-47f4-8f83-e59477723d95
# ╟─a00cbbfc-56ce-413a-a7b8-13de8541fa6f
# ╠═4042bc32-1a14-4408-974d-7405fd8c8ccc
# ╟─95f9803a-86df-4517-adc8-0bcbb0ff6fbc
# ╟─a5f3915c-6eed-480d-9aed-8fdd052a324a
# ╟─31c23e2b-1a2d-41aa-81c1-22868e241f7e
# ╟─6cec1700-f2de-4e80-b26d-b23b5f7f1823
# ╟─8a39fbbb-6b5b-4744-a875-469c289242fb
# ╟─3f548bb1-37b0-48b7-a35c-d7701405a64e
# ╟─fd7a53d1-2c6d-4d6a-b546-5c766c9a39d7
# ╟─46e6bba9-0c83-47b7-be17-f41301efa18e
# ╟─77544f9e-6053-4ed6-aa9a-4e7a54ca41d9
# ╟─3242f19a-83f7-4db6-b2ea-6ca3403e1039
# ╟─1e5596fb-7dca-408b-afbd-6ca2e2487d75
# ╟─2ea12676-7b5e-444e-8025-5bf9c05d0e2d
# ╟─d359625e-5a95-49aa-86e4-bc65299dd92a
# ╟─829cde81-be03-4a9f-a853-28f84923d493
# ╟─1d2bedb1-509d-4956-8e5a-ad1c0f1ffe26
# ╟─9c482134-6336-4e72-9d30-87080ebae671
# ╟─90b6ef16-7853-46e1-bbd6-cd1a904c442a
# ╟─f290d98e-5a8a-44f2-bee5-b93738abe9af
# ╟─3c601844-3bb9-422c-ab1e-b40f7e7cb0df
# ╟─f26f890b-5924-497c-85a3-eff924d0470b
# ╟─95a67d04-0a32-4e55-ac2f-d004ecc9ca84
# ╟─7d99f9b9-f4ea-4d4b-99b2-608bc491f05c
# ╟─2baf0cba-7ef9-4dd5-bc68-bcdac7753b30
# ╠═ab2bac2b-b2ba-4eaa-8444-439485627bad
# ╠═48f4cdf3-b3d7-4cd6-8071-78292fec0db9
# ╠═285a56b7-bb3e-4929-a853-2fc69c77bdcb
# ╠═a984c96d-273e-4d6d-bab8-896f14a79103
# ╟─21e828e5-00e4-40ce-bff5-60a17439bf44
# ╟─e35d4be7-366d-4ca5-a89a-5de24e4c6677
# ╟─a3bcad72-0e6c-43f8-a08d-777a154190d8
# ╟─8da80446-84d7-44bb-8122-874b4c9514f4
# ╟─24256769-2274-4b78-8445-88ec4536c407
# ╟─5b079ce8-3b28-4fe7-8df2-f576c2c948f5
# ╠═6bc5d30d-2051-4249-9f2a-c4354aa49198
