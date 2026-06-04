### A Pluto.jl notebook ###
# v0.20.28

#> [frontmatter]
#> title = "Eclipsing Binaries Lab"
#> date = "2025-10-03"
#> tags = ["time series", "eclipsing binaries"]
#> description = "Measure light curves from your data. Example eclipsing binary use case included."
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

# ╔═╡ 6bc5d30d-2051-4249-9f2a-c4354aa49198
begin
	# Notebook UI
	using PlutoUI, CommonMark
	
	# Data wrangling
	using CCDReduction, DataDeps, DataFramesMeta

	# Web
	using HTTP, JSONTables, TableScraper
	
	# Visualization and analysis
	using AstroImages, PlutoPlotly, AstroAngles, Photometry
	using AstroImages: restrict
	using Astroalign
	using Dates, Unitful, Statistics 
	using ImageFiltering

	AstroImages.set_cmap!(:cividis)

	# Use DataDeps.jl for dataset management
	# Auto-download data to current directory by default
	ENV["DATADEPS_ALWAYS_ACCEPT"] = "true"
	ENV["DATADEPS_LOAD_PATH"] = @__DIR__
	DataDep(
		"sample_data",
		"""
		UCAN Data Files
		Website: https://www.seti.org/education/ucan/unistellar-education-materials/
		""",
		["https://www.dropbox.com/scl/fo/om02nzsex9ql00gcnp0r4/AA11_SrUS2GUwvuMUQm85x8?rlkey=np5upxstx4z6lhcch6tje1b0j&st=st2wzmyp&dl=1"],
		["f5692a2382a035b892600e962ac950d70176c7137ae5e2d716816fc9c43aab7c"],
		post_fetch_method = unpack,
	) |> register
end;

# ╔═╡ ac2acb87-8515-41cf-a762-ca48d8cd269a
md"""
# Eclipsing Binaries Lab

Using the photometric analysis tools developed in the previous notebook, we will now turn to the technique of generalizing this for images taken at multiple times to build a time series science product, aka a light curve. We will use sample eVscope data of an eclipsing binary system as a real life test case, and show how we can find additional targets to study from the American Association of Variable Star Observers ([AAVSO](https://www.aavso.org/)).
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

$(Resource("https://github.com/Unistellar-science/SETI-Education/blob/main/src/ucan/eclipsing_binary/assets/constellation_WUMa.png?raw=true"))

*W UMa is marked by the larger, red dot to the right of the Big Dipper*
"""

# ╔═╡ c1bbb6a2-6996-4fee-a642-a0212b473474
md"""
Discovered in the early 1900s, this system is composed of two main-sequence F-type stars orbiting so closely together that they are expected to be [contact binaries](https://en.wikipedia.org/wiki/Contact_binary), meaning they share a common gaseous envelope. Their proximity to each other also gives this system an astonishingly short orbital period of just over 8 hours. Because of how neatly this fits into an Earth day, eclipse events occur at almost the same time every night, making them the ideal target for regular follow-up study. When the fainter of the two passes in front of the brighter one, we call that a _primary eclipse_, and when the brighter companion passes in front of the fainter one, we call it a _secondary eclipse_.

According to the [AAVSO ephemeris](https://milwaukeeastro.org/EB/MAS_EB_2025_10.pdf) for this system, primary eclipse is predicted to occur around **6:00 -- 7:00 UTC**, depending on what part of the month we are in. Due to the similar sizes and spectral types of each star, the eclipse depths for both are fairly similar and can vary by almost a whole apparent magnitude! With a total duration of about three hours, the entire light curve for a given eclipse can be captured in a single night.

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
Here is a summary of the header information for each science frame taken:
"""

# ╔═╡ 74197e45-3b80-44ad-b940-f2544f2f9b54
Resource("https://raw.githubusercontent.com/Unistellar-science/SETI-Education/refs/heads/main/data/timeseries/ebs/finder_WUMa.jpg")

# ╔═╡ a6de852c-01e6-49a2-bc78-8d1b6eb51c0c
md"""
Here is the associated header information for our science frame:
"""

# ╔═╡ 009f2c3f-bc8f-4874-9545-f18d6722284b
@bind reset Button("Reset")

# ╔═╡ 7d54fd96-b268-4964-929c-d62c7d89b4b2
md"""
Uh-oh, we see that our images are literally rotating out from under us! This [field rotation](https://calgary.rasc.ca/field_rotation.htm) and also some drift that needed to be manually corrected partway through the observation are normal effects of taking long duration observations on an alt-az mount. Fortunately, it is fairly manageable to handle this as we will see in the next section.
"""

# ╔═╡ 1d14c32a-c0b5-4b3e-8a70-c50f539f6e69
md"""
### A note on image calibration

A critical step in analyzing astronomical data is accounting for sources of noise that may impact our final image. This process is known as calibration, and its purpose is to increase the signal-to-noise ratio of our science images. Here is a nice summary modified from [Practical Astrophotography](https://practicalastrophotography.com/a-brief-guide-to-calibration-frames/) of three of the main sources of noise that we typically try to calibrate for:

!!! note ""
	**Bias frames:** "Your camera inherently has a base level of read-out noise as it reads the values of each pixel of the sensor, called bias. When averaged out, basically it’s an inherent gradient to the sensor. Bias Frames are meant to capture this so it can be removed."

	**Dark frames:** "When taking a long exposure, the chip will introduce "thermal" noise. Its level is magnified by three things – temperature, exposure time, and ISO. Dark frames are used to subtract this sensor noise from your image and mitigate "hot or cold" pixels. (Some modern sensors automatically calculate dark levels and don't need dark frames). Dark Frames also will calibrate the chip so all pixels give the same value when not exposed to light."

	**Flat frames:** "I've seen people say flats help with light pollution. NOT TRUE AT ALL. Flat frames allow you to calculate the correction factor for each pixel so they all give the same value when exposed to the same quantity of light for a given optical path. Things like dust motes, lens vignetting consistently reduce the light to a given pixel, flat frames allow you to mathematically remove them to give a smooth evenly illuminated image."
"""

# ╔═╡ e94b7436-462b-4d34-b721-990c8682ee6e
md"""
Different flat fielding techniques are being examined by our team, but in general this has not been oberserved to be a significant source of noise in science mode observations. In practice, the [sensor calibration](https://help.unistellar.com/hc/en-us/articles/360011333600-Sensor-calibration-Dark-Frame-How-and-Why) step that is required at the end of science observations are set to the same gain and exposure time as your science images. By doing this, the bias frame is automatically built into the dark frames collected during this step, so no separate bias acquisition is needed.

We find that the contribution from dark noise does not impact our observations significantly, so we have excluded this calibration step for simplicity. Stay tuned for a future calibration notebook though where we will explore these procedures in more detail!
"""

# ╔═╡ 1df329a0-629a-4527-8e5d-1dbac9ed8497
md"""
## Image alignment 📐

A typical astronomical observation might use the know RA and Dec of the field to [plate solve](https://astrobackyard.com/plate-solving/) each frame against background sources (see, e.g., [astrometry.net](https://astrometry.net/)). This then gives a coordinate transformation (e.g., with the [World Coordinate System (WCS) standard](https://fits.gsfc.nasa.gov/fits_wcs.html)) that can be applied to each frame to align them to a common grid with open source tools like [AstroImageJ](https://www.astro.louisville.edu/software/astroimagej/). Unfortunately, plate solving is a computationally expensive process that can take quite a while, especially if we have a large number of frames. Fortunately, there is a nice alternative that we can use if we do not care about the WCS information: [asterisms](https://en.wikipedia.org/wiki/Asterism_(astronomy)).

In this process, one frame is aligned to another in much the same way that the human brain might try to: by matching common shapes between each frame to each other. This works indpendently of WCS information, so it completely avoids the need to plate solve our images. We will use this method to align our science frames.
"""

# ╔═╡ e7ad4e24-5dc9-4713-836a-be001304e45c
md"""
Let's see how our aligned frames look below:
"""

# ╔═╡ 102ce649-e560-470e-afa5-699db577e148
md"""
Nice! The rotation looks to have been successfuly transformed out. We turn next to computing the photometry for our aligned series of frames.
"""

# ╔═╡ d6d19588-9fa5-4b3e-987a-082345357fe7
md"""
## Aperture photometry 🔾

This process is very similar to what was shown in our previous notebook. Only now, instead of computing the photometry for a single image, we will compute it for a series of images and store the results:
"""

# ╔═╡ 15ad7461-9c40-4755-8f00-14aa3be53e0f
md"""
By convention, `t` is our observation time, `x1` is for our target star, and `x2` is for our comparison star. We also scaled the flux of each star by its median observed flux to make the numbers more comfortable to work with. We can now visualize the light curve of our target from our photometry table above:
"""

# ╔═╡ 17eb5723-71f4-4344-b1b1-41b894e7582b
md"""
And divide by our comparison star:
"""

# ╔═╡ 9d88c884-3187-452d-8453-7f095dac4b03
md"""
To try this analysis on you own data:

1. Place your data folder into the same folder as this notebook
1. Type the name of your data folder below (e.g., `my_data`)
1. Click `Enter`
"""

# ╔═╡ 1b71497f-636a-45c8-8f51-728bee091696
begin
	reset
	@bind DATA_DIR_local confirm(TextField(); label = "Enter")
end

# ╔═╡ 7c078085-ff30-400d-a0ab-2680f468c415
DATA_DIR = if isempty(DATA_DIR_local)
	datadep"sample_data"
else
	joinpath(@__DIR__, DATA_DIR_local)
end;

# ╔═╡ 1356c02f-9ff2-491f-b55d-666ee76e6fae
df_sci_all = let
	df = fitscollection(DATA_DIR; abspath=false)
	@transform! df :"DATE-OBS" = DateTime.(:"DATE-OBS")
end

# ╔═╡ 5321f774-67fc-4355-9411-2e624a00e724
begin
	N_max = 200
	N_sci_all = nrow(df_sci_all)
md"""
!!! note
	This can be a pretty large number of data files depending on the observation, so for simplicity we will just use a subset for our lab, which we can specify.
"""
end

# ╔═╡ 1f3610da-f81e-4cdb-bad6-b2475497dc5f
cm"""
!!! note "File selection"
	Move the slider below, then click `Select` to specify the total number of equally spaced observations in time to use:

	$(@bind nrows_max confirm(
		Slider(2:N_sci_all;
			show_value = true,
			default = min(N_sci_all, 200),
			# Heads up, as max_steps goes up, performance goes down
			max_steps = 4_000,
		);
		label = "Select",
	))

	For safety, this will default to $(N_max) if you have more than this number of files to process, but you can of course raise this limit with the slider if your computer can handle it.
"""

# ╔═╡ 777dcd30-70ba-4091-9075-4f1be4e309c0
df_sci = let
	rows_to_use = round.(Int, range(1, N_sci_all; length = nrows_max))
	df_sci_all[rows_to_use, :]
end

# ╔═╡ 035fcecb-f998-4644-9650-6aeaced3e41f
imgs_sci = map(eachrow(df_sci)) do f
	img = load(f.path)
	mapwindow!(median!, similar(img), img, (3, 3)) # Good for catching hot pixels
end;

# ╔═╡ 1fe59945-8bce-44f3-b548-9646c2ce6bda
arrs_aligned = align_frames(imgs_sci; box_size = (3, 3));

# ╔═╡ 81f6a02b-e6c6-4e38-a18c-4aa368fcd0aa
imgs_sci_aligned = let
    imgs_aligned = map(imgs_sci, arrs_aligned) do img0, img
        shareheader(img0, img)
    end
    [imgs_sci[1], imgs_aligned...]
end;

# ╔═╡ 06d26240-81b6-401b-8eda-eab3a9a0fb20
let
	obs_start, obs_end = df_sci[:, "DATE-OBS"] |> extrema .|> string
md"""
We see that we have $(nrow(df_sci)) fits files taken from $(obs_start) -- $(obs_end) UTC. Here's what that first image looks like compared to its [finder chart](https://astro.swarthmore.edu/transits/finding_charts.cgi):
"""
end

# ╔═╡ 2b8c75f6-c148-4c70-be6a-c1a4b95d5849
img_sci = load(first(df_sci).path); # The semicolon hides automatic output

# ╔═╡ f6197e8e-3132-4ab5-86d7-32572e337c58
img_size, img_eltype = size(img_sci), eltype(img_sci);

# ╔═╡ 5abbcbe0-3ee6-4658-9c99-e4567a23e3f6
md"""
It looks like this image is $(first(img_size)) x $(last(img_size)) pixels, with the ADU counts for each pixel stored as a $(img_eltype) to reduce memory storage. Now that we know that we are pointing at the right place in the sky, let's take at look at how these images change over time. Use the display below to scroll through each of our science frames. (Note for the rest of this notebook that we will be using the default image orientation in the plotting software):
"""

# ╔═╡ 8f0e6529-bd67-47aa-9ddf-4032a5483a98
begin
	X_max, Y_max = img_size
	X_mid, Y_mid = img_size .÷ 2
	@bind coords PlutoUI.combine() do Child
		md"""
		| | X (pixels) | Y (pixels) | radius (pixels)
		| :-: | :-: | :-: | :-: |
		| target |$(Child("x", NumberField(1:X_max; default = 1029))) | $(Child("y", NumberField(1:Y_max; default = 779))) | $(Child("r", NumberField(1:1000; default = 50))) | ----
		| comparison |$(Child("x_comp", NumberField(1:X_max; default = 1153))) | $(Child("y_comp", NumberField(1:Y_max; default = 711))) | $(Child("r_comp", NumberField(1:1000; default = 50)))

		!!! note "Apertures and comparison stars"

			To better show the frame to frame differences, we also added some sample target and comparison star aperturess (in green and orange, respectively) centered on the first frame in our image series. We use comparison stars to divide out common systematics like atmospheric turbulence and other changes in seeing conditions so that ideally only the target signal will be left.
		"""
	end
end

# ╔═╡ dbe812e2-a795-4caa-842d-07da5eabcade
img_sci[reverse(begin:end), begin:end]

# ╔═╡ 7d7cd508-be27-4f52-bc13-91c702450167
header(img_sci)

# ╔═╡ edf5f093-19cc-4802-a777-95d8492996a8
h = header(img_sci);

# ╔═╡ 1ede8642-1f36-4aad-bcad-383fd211d31a
md"""
!!! note
	To reload the original sample data, clear the field above and click `Enter` again.
"""

# ╔═╡ f1ed6484-8f6a-4fbf-9a3d-0fe20360ab3b
# Aperture object that will be used for photometry
# (x_center, y_center, radius)
ap_target = CircularAperture(coords.x, coords.y, coords.r);

# ╔═╡ 954c7918-7dd1-4967-a67b-7856f00dc498
ap_comp1 = CircularAperture(coords.x_comp, coords.y_comp, coords.r_comp);

# ╔═╡ 381d0147-264b-46f6-82ab-8c840c50c7d1
aps = [ap_target, ap_comp1];

# ╔═╡ 79c924a7-f915-483d-aee6-94e749d3b004
aperture_sums = map(imgs_sci_aligned) do img
	# Returns (x_center, y_center, aperture_sum)
	# for each aperture
	p = photometry(aps, img)
	
	# Just store the aperture sum for each frame
	p.aperture_sum
end;

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
	end
	
	# Place the observation time in the first column
	insertcols!(df, 1, :t => df_sci.:"DATE-OBS")
end

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
		title = "Raw light curves",
		legend_title_text = "Source",
	)
	
	relayout!(p, layout)

	p
end

# ╔═╡ 59392770-f59e-4188-a675-89c2f2fc67d9
let
	sc = scatter(x=df_phot.t, y=df_phot.x1 ./ df_phot.x2, mode = :markers,)

	layout = Layout(
		xaxis = attr(title="Date (UTC)"),
		yaxis = attr(title="Relative aperture sum"),
		title = string("Divided light curve<br>", h["PURPOSE"], " observation: ",  h["DATE-OBS"]),
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
We start by [creating an account](https://targettool.aavso.org/init/default/user/register?_next=/init/default/index) on AAVSO. This will allow us to access their API and set our observing location. Once we are logged in, our API key will be displayed as a string of numbers and letters across the top of the [API webpage](https://targettool.aavso.org/TargetTool/api). Copy this key into a text file in your data folder, and name it `.aavso_key`. Select the `Query` button below to submit your query to AAVSO.
"""

# ╔═╡ 502fe5dd-d55a-450e-9209-60dc05f395dc
@bind submit_query Button("Submit Query")

# ╔═╡ 14998fe7-8e22-4cd4-87c6-9a5334d218ed
begin
	submit_query
	username = if isfile(".aavso_key")
		@debug "API key found"
		readline(".aavso_key")
	else
		@debug "Please load your API key using the instructions above."
		""
	end
end;

# ╔═╡ 4a779bd1-bcf3-41e1-af23-ed00d29db46f
md"""
!!! note
	This is your personal key. Do not share this with others.
"""

# ╔═╡ 7f9c4c42-26fc-4d02-805f-97732032b272
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

# ╔═╡ e927297b-9d63-4448-8245-4d73d1fbff27
md"""
Feel free to uncomment the lat/long fields below to override the default location set in your profile, or add any additional settings. We store our query in a [DataFrame](https://dataframes.juliadata.org/stable/) to view the first 10 results:
"""

# ╔═╡ 399f53c5-b654-4330-9ead-4d795917b03b
df_all = if isempty(username)
		DataFrame()
	else
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

# ╔═╡ a00cbbfc-56ce-413a-a7b8-13de8541fa6f
md"""
It looks like we have $(nrow(df_all)) hits. Let's filter these for targets that are easily observable, i.e., with our following criteria:

1. Large change in brightness (at least half a mag)
2. Fairly short period (period < 3 days)
3. Includes an ephemeris (the `other_info` column must include this link)

!!! note
	We also prioritize dimmer targets (V > 9.0). The reason for this is that we are taking a time series over the course of hours, which would lead to an unfeasable number of total science frames taken if the exposure time for each one needed to be dialed down for bright targets. Instead, we fix our exposure time to the maximum on eVscopes (4 seconds), and select targets that would not be overexposed at this level.

Lastly, we select the columns that we care about and make some visual transforms for convenience (e.g., including units, converting decimal RA and Dec to `[h m s]`, and `[° ' "]` format, respectively, for easy copy-pasting into the Unistellar app):
"""

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

# ╔═╡ f2c89a20-09d5-47f4-8f83-e59477723d95
nrow(df_all) # Total number of targets in our list

# ╔═╡ 6c2a385c-5116-4aa9-9745-bea2326af593
md"""
# Notebook setup 🔧
"""

# ╔═╡ a984c96d-273e-4d6d-bab8-896f14a79103
TableOfContents(; depth=4)

# ╔═╡ f290d98e-5a8a-44f2-bee5-b93738abe9af
# Keep these values untouched
const baseline = (
	v_mag = 11.7, # V (mag)
	t_exp = 3200.0, # Exptime (ms)
	gain = 25.0, # Gain (dB)
	peak_px = 3000, # Peak Pixel ADU
)

# ╔═╡ e7f88515-305b-4899-8fa0-326e9e2097b5
md"""
## Helper functions
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
	maximum_column_width = "max-width",
	nosubheader = true,
	alignment = :c,
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
df_candidates = if isempty(username)
		DataFrame(star_name = "Sol")
	else
		@chain df_all begin
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

# ╔═╡ 95f9803a-86df-4517-adc8-0bcbb0ff6fbc
md"""
We now have $(nrow(df_candidates)) prime candidates that we can plan our observations for. Clicking on the `ephem_link` in the last column should take us to a table on AAVSO with the predicted eclipse times for the next month. For convenience, we can also select one of the targets below to generate a table of deep links:

!!! note
	This will only work for targets that have a complete ephemeris. All times are in UTC.
"""

# ╔═╡ a5f3915c-6eed-480d-9aed-8fdd052a324a
@bind star_name Select(df_candidates.star_name)

# ╔═╡ 3f548bb1-37b0-48b7-a35c-d7701405a64e
df_selected = @rsubset df_candidates :star_name == star_name

# ╔═╡ 8a39fbbb-6b5b-4744-a875-469c289242fb
df_ephem = if isempty(username)
		DataFrame()
	else
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

# ╔═╡ 31c23e2b-1a2d-41aa-81c1-22868e241f7e
df_obs = if isempty(username)
		DataFrame()
	else 
		@rselect leftjoin(df_selected, df_ephem; on=:star_name) begin
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
					Dates.format(:Mid, dateformat"yymmdd"),
					replace(:star_name, " " => ""),
				]),
			)
		end
end

# ╔═╡ 90b6ef16-7853-46e1-bbd6-cd1a904c442a
let
	f_factor = flux_factor(target, baseline)
	gain_max = max_gain(baseline, f_factor)
	gain_recommended = rec_gain(gain_max)

	@debug "Observing params" gain_max gain_recommended
end

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
	# circ(ap_comp2; line_color=:orange),
];

# ╔═╡ 8da80446-84d7-44bb-8122-874b4c9514f4
timestamp(img) = header(img)["DATE-OBS"]

# ╔═╡ 24256769-2274-4b78-8445-88ec4536c407
function plot_img(i, img; zmin=2400, zmax=3200, restrict=true)
	hm = htrace(img; zmin, zmax, restrict)
	
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

# ╔═╡ f41df561-85ff-484b-8188-883c1fea21c9
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

# ╔═╡ 86e53a41-ab0d-4d9f-8a80-855949847ba2
plot_anim(imgs_sci)

# ╔═╡ 5b34ed05-4181-4fca-a80e-161fa99bc26e
plot_anim(imgs_sci_aligned)

# ╔═╡ 637d7f71-e884-43df-be10-2a490486d0dd
md"""
## Packages
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AstroAngles = "5c4adb95-c1fc-4c53-b4ea-2a94080c53d2"
AstroImages = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
Astroalign = "7f4629bd-323a-4fad-ad42-4ee56350f27f"
CCDReduction = "b790e538-3052-4cb9-9f1f-e05859a455f5"
CommonMark = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
DataDeps = "124859b0-ceae-595e-8997-d05f6a7a8dfe"
DataFramesMeta = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
ImageFiltering = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
JSONTables = "b9914132-a727-11e9-1322-f18e41205b0b"
Photometry = "af68cb61-81ac-52ed-8703-edc140936be4"
PlutoPlotly = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
TableScraper = "3d876f86-fca9-45cb-9864-7207416dc431"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[compat]
AstroAngles = "~0.2.0"
AstroImages = "~0.5.1"
Astroalign = "~0.2.0"
CCDReduction = "~0.2.3"
CommonMark = "~1.0.2"
DataDeps = "~0.7.14"
DataFramesMeta = "~0.15.6"
HTTP = "~1.11.0"
ImageFiltering = "~0.7.12"
JSONTables = "~1.0.3"
Photometry = "~0.9.8"
PlutoPlotly = "~0.6.6"
PlutoUI = "~0.7.83"
TableScraper = "~0.1.4"
Unitful = "~1.28.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "e68b01657a7f137a1d54aeb67d1723319b40049b"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d92ad398961a3ed262d8bf04a1a2b8340f915fef"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.5.0"
weakdeps = ["ChainRulesCore", "Test"]

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"
    AbstractFFTsTestExt = "Test"

[[deps.AbstractPlutoDingetjes]]
git-tree-sha1 = "6c3913f4e9bdf6ba3c08041a446fb1332716cbc2"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.4.0"

[[deps.AbstractTrees]]
git-tree-sha1 = "2d9c9a55f9c93e8887ad391fbae72f8ef55e1177"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.4.5"

[[deps.Accessors]]
deps = ["CompositionsBase", "ConstructionBase", "Dates", "InverseFunctions", "MacroTools"]
git-tree-sha1 = "2eeb2c9bef11013efc6f8f97f32ee59b146b09fb"
uuid = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
version = "0.1.44"

    [deps.Accessors.extensions]
    AxisKeysExt = "AxisKeys"
    IntervalSetsExt = "IntervalSets"
    LinearAlgebraExt = "LinearAlgebra"
    StaticArraysExt = "StaticArrays"
    StructArraysExt = "StructArrays"
    TestExt = "Test"
    UnitfulExt = "Unitful"

    [deps.Accessors.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "28e1637322d4019ed2577cbec9268fab9b7da117"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.6.0"
weakdeps = ["SparseArrays", "StaticArrays"]

    [deps.Adapt.extensions]
    AdaptSparseArraysExt = "SparseArrays"
    AdaptStaticArraysExt = "StaticArrays"

[[deps.AliasTables]]
deps = ["PtrArrays", "Random"]
git-tree-sha1 = "9876e1e164b144ca45e9e3198d0b689cadfed9ff"
uuid = "66dad0bd-aa9a-41b7-9441-69ab47430ed8"
version = "1.1.3"

[[deps.ArgCheck]]
git-tree-sha1 = "f9e9a66c9b7be1ad7372bbd9b062d9230c30c5ce"
uuid = "dce04be8-c92d-5529-be00-80e4d2c0e197"
version = "2.5.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "3d0cabd25fab32390e3bcb82cd67e700aebd9816"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.25.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceAMDGPUExt = "AMDGPU"
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceCUDSSExt = ["CUDSS", "CUDA"]
    ArrayInterfaceChainRulesCoreExt = "ChainRulesCore"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceMetalExt = "Metal"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceSparseArraysExt = "SparseArrays"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    AMDGPU = "21141c5a-9bdb-4563-92ae-f87d6854732e"
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    Metal = "dde4c033-4e86-420c-a63e-0dd931031962"
    ReverseDiff = "37e2e3b7-166d-5795-8a7a-e32c996b4267"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tracker = "9f7883ad-71c0-57eb-9f7f-b5c9e6d3789c"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"
version = "1.11.0"

[[deps.AstroAngles]]
git-tree-sha1 = "bc188d9a6507511e7360444d54ed57d0a9d6cf91"
uuid = "5c4adb95-c1fc-4c53-b4ea-2a94080c53d2"
version = "0.2.0"

[[deps.AstroImages]]
deps = ["AbstractFFTs", "AstroAngles", "ColorSchemes", "DimensionalData", "FITSIO", "FileIO", "ImageAxes", "ImageBase", "ImageIO", "ImageShow", "MappedArrays", "PlotUtils", "PrecompileTools", "Printf", "RecipesBase", "Statistics", "Tables", "UUIDs", "WCS"]
git-tree-sha1 = "b036ab0541311fee6f278e1469b7839cc3af8f19"
uuid = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
version = "0.5.1"

[[deps.Astroalign]]
deps = ["ConsensusFitting", "CoordinateTransformations", "ImageTransformations", "NearestNeighbors", "Photometry", "TypedTables"]
git-tree-sha1 = "4123427518b5bdb3a5bb64198aadfac9bdce9bc0"
uuid = "7f4629bd-323a-4fad-ad42-4ee56350f27f"
version = "0.2.0"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "01b8ccb13d68535d73d2b0c23e39bd23155fb712"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.1.0"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "4126b08903b777c88edf1754288144a0492c05ad"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.8"

[[deps.BackgroundMeshes]]
deps = ["BiweightStats", "ConcreteStructs", "ImageFiltering", "ImageTransformations", "Interpolations", "NearestNeighbors", "Statistics", "StatsBase"]
git-tree-sha1 = "c1312dfc95f9a18498a3d3cc79df0ca737aca37d"
uuid = "b200be5e-c4c1-4b3d-840b-d423a53b46f3"
version = "0.1.0"

[[deps.BangBang]]
deps = ["Accessors", "ConstructionBase", "InitialValues", "LinearAlgebra"]
git-tree-sha1 = "cceb62468025be98d42a5dc581b163c20896b040"
uuid = "198e06fe-97b7-11e9-32a5-e1d131e6ad66"
version = "0.4.9"

    [deps.BangBang.extensions]
    BangBangChainRulesCoreExt = "ChainRulesCore"
    BangBangDataFramesExt = "DataFrames"
    BangBangStaticArraysExt = "StaticArrays"
    BangBangStructArraysExt = "StructArrays"
    BangBangTablesExt = "Tables"
    BangBangTypedTablesExt = "TypedTables"

    [deps.BangBang.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
    TypedTables = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.Baselet]]
git-tree-sha1 = "aebf55e6d7795e02ca500a689d326ac979aaf89e"
uuid = "9718e550-a3fa-408a-8086-8db961cd8217"
version = "0.1.1"

[[deps.BitFlags]]
git-tree-sha1 = "bbe1079eecf9c9fbb52765193ad2bae27ae09bc8"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.10"

[[deps.BiweightStats]]
deps = ["Statistics"]
git-tree-sha1 = "da45acf1b8adb5c4becf8ea67fb361addf039f90"
uuid = "5bf8a1e9-d5f8-4697-9608-80edd97af0ad"
version = "1.0.1"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

[[deps.CCDReduction]]
deps = ["DataFrames", "FITSIO", "LazyStack", "ResumableFunctions", "Statistics"]
git-tree-sha1 = "4b3eb62b3a20d36ce1cb4b633c51b34627a0ced3"
uuid = "b790e538-3052-4cb9-9f1f-e05859a455f5"
version = "0.2.3"

[[deps.CEnum]]
git-tree-sha1 = "389ad5c84de1ae7cf0e28e381131c98ea87d54fc"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.5.0"

[[deps.CFITSIO]]
deps = ["CFITSIO_jll"]
git-tree-sha1 = "8c6b984c3928736d455eb53a6adf881457825269"
uuid = "3b1b4be9-1499-4b22-8d78-7db3344d1961"
version = "1.7.2"

[[deps.CFITSIO_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "LibCURL_jll", "Libdl", "Zlib_jll"]
git-tree-sha1 = "d846411d1d7eb34739105f3d6fbba7c93beded3d"
uuid = "b3e40c51-02ae-5482-8a39-3ace5868dcf4"
version = "4.6.4+0"

[[deps.CRlibm]]
deps = ["CRlibm_jll"]
git-tree-sha1 = "66188d9d103b92b6cd705214242e27f5737a1e5e"
uuid = "96374032-68de-5a5b-8d9e-752f78720389"
version = "1.0.2"

[[deps.CRlibm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e329286945d0cfc04456972ea732551869af1cfc"
uuid = "4e9b3aee-d8a1-5a3d-ad8b-7d824db253f0"
version = "1.0.1+0"

[[deps.Cascadia]]
deps = ["AbstractTrees", "Gumbo"]
git-tree-sha1 = "c0769cbd930aea932c0912c4d2749c619a263fc1"
uuid = "54eefc05-d75b-58de-a785-1a3403f0919f"
version = "1.0.2"

[[deps.CatIndices]]
deps = ["CustomUnitRanges", "OffsetArrays"]
git-tree-sha1 = "a0f80a09780eed9b1d106a1bf62041c2efc995bc"
uuid = "aafaddc9-749c-510e-ac4f-586e18779b91"
version = "0.2.2"

[[deps.Chain]]
git-tree-sha1 = "765487f32aeece2cf28aa7038e29c31060cb5a69"
uuid = "8be319e6-bccf-4806-a6f7-6fae938471bc"
version = "1.0.0"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra"]
git-tree-sha1 = "12177ad6b3cad7fd50c8b3825ce24a99ad61c18f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.26.1"
weakdeps = ["SparseArrays"]

    [deps.ChainRulesCore.extensions]
    ChainRulesCoreSparseArraysExt = "SparseArrays"

[[deps.CodecBzip2]]
deps = ["Bzip2_jll", "TranscodingStreams"]
git-tree-sha1 = "84990fa864b7f2b4901901ca12736e45ee79068c"
uuid = "523fee87-0ab8-5b00-afb7-3ecf72e48cfd"
version = "0.8.5"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "962834c22b66e32aa10f7611c08c8ca4e20749a9"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.8"

[[deps.CodecZstd]]
deps = ["TranscodingStreams", "Zstd_jll"]
git-tree-sha1 = "da54a6cd93c54950c15adf1d336cfd7d71f51a56"
uuid = "6b39b394-51ab-5f42-8807-6242bab2b4c2"
version = "0.8.7"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "b0fd3f56fa442f81e0a47815c92245acfaaa4e34"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.31.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "67e11ee83a43eb71ddc950302c53bf33f0690dfe"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.12.1"
weakdeps = ["StyledStrings"]

    [deps.ColorTypes.extensions]
    StyledStringsExt = "StyledStrings"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "Requires", "Statistics", "TensorCore"]
git-tree-sha1 = "8b3b6f87ce8f65a2b4f857528fd8d70086cd72b1"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.11.0"
weakdeps = ["SpecialFunctions"]

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "37ea44092930b1811e666c3bc38065d7d87fcc74"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.1"

[[deps.CommonMark]]
deps = ["PrecompileTools"]
git-tree-sha1 = "731edf630eb23140a3c7a2e74d4186f562996d76"
uuid = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
version = "1.0.2"

    [deps.CommonMark.extensions]
    CommonMarkMarkdownASTExt = "MarkdownAST"
    CommonMarkMarkdownExt = "Markdown"

    [deps.CommonMark.weakdeps]
    Markdown = "d6f4376e-aef5-505a-96c1-9c027394607a"
    MarkdownAST = "d0879d2d-cac2-40c8-9cee-1863dc0c7391"

[[deps.CommonSubexpressions]]
deps = ["MacroTools"]
git-tree-sha1 = "cda2cfaebb4be89c9084adaca7dd7333369715c5"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.1"

[[deps.CommonWorldInvalidations]]
git-tree-sha1 = "ae52d1c52048455e85a387fbee9be553ec2b68d0"
uuid = "f70d9fcc-98c5-4d4a-abd7-e4cdeebd8ca8"
version = "1.0.0"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "9d8a54ce4b17aa5bdce0ea5c34bc5e7c340d16ad"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.18.1"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.3.0+1"

[[deps.CompositionsBase]]
git-tree-sha1 = "802bb88cd69dfd1509f6670416bd4434015693ad"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.2"
weakdeps = ["InverseFunctions"]

    [deps.CompositionsBase.extensions]
    CompositionsBaseInverseFunctionsExt = "InverseFunctions"

[[deps.ComputationalResources]]
git-tree-sha1 = "52cb3ec90e8a8bea0e62e275ba577ad0f74821f7"
uuid = "ed09eef8-17a6-5b46-8889-db040fac31e3"
version = "0.3.2"

[[deps.ConcreteStructs]]
git-tree-sha1 = "ed1da4eac5ba9b3f6d061c90f3ca6ba190dd6595"
uuid = "2569d6c7-a4a2-43d3-a901-331e8e4be471"
version = "0.2.4"

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "21d088c496ea22914fe80906eb5bce65755e5ec8"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.5.1"

[[deps.ConsensusFitting]]
deps = ["Random"]
git-tree-sha1 = "441fabda4a17f31af66e3259768450d1912ab9a1"
uuid = "463569c3-d6e9-43b4-bb3a-bd02a13deb89"
version = "1.0.0"

[[deps.ConstructionBase]]
git-tree-sha1 = "b4b092499347b18a015186eae3042f72267106cb"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.6.0"
weakdeps = ["IntervalSets", "LinearAlgebra", "StaticArrays"]

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

[[deps.CoordinateTransformations]]
deps = ["LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "a692f5e257d332de1e554e4566a4e5a8a72de2b2"
uuid = "150eb455-5306-5404-9cee-2592286d6298"
version = "0.6.4"

[[deps.CoreMath]]
deps = ["CoreMath_jll"]
git-tree-sha1 = "8c0480f92b1b1796239156a1b9b1bfb1b39499b4"
uuid = "b7a15901-be09-4a0e-87d2-2e66b0e09b5a"
version = "0.1.0"

[[deps.CoreMath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a692a4c1dc59a4b8bc0b6403876eb3250fde2bc3"
uuid = "a38c48d9-6df1-5ac9-9223-b6ada3b5572b"
version = "0.1.0+0"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.CustomUnitRanges]]
git-tree-sha1 = "1a3f97f907e6dd8983b744d2642651bb162a3f7a"
uuid = "dc8bdbbb-1ca9-579f-8c36-e416f6a65cce"
version = "1.0.2"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataDeps]]
deps = ["HTTP", "Libdl", "Reexport", "SHA", "Scratch", "p7zip_jll"]
git-tree-sha1 = "75226661988f5b66a4c52358933eaa43b9278bb2"
uuid = "124859b0-ceae-595e-8997-d05f6a7a8dfe"
version = "0.7.14"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "DataStructures", "Future", "InlineStrings", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrecompileTools", "PrettyTables", "Printf", "Random", "Reexport", "SentinelArrays", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "5fab31e2e01e70ad66e3e24c968c264d1cf166d6"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.8.2"

[[deps.DataFramesMeta]]
deps = ["Chain", "DataFrames", "MacroTools", "OrderedCollections", "PrettyTables", "Reexport", "TableMetadataTools"]
git-tree-sha1 = "b0652fb7f3c094cf453bf22e699712a0bed9fc83"
uuid = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
version = "0.15.6"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "6fb53a69613a0b2b68a0d12671717d307ab8b24e"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.5"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DefineSingletons]]
git-tree-sha1 = "0fba8b706d0178b4dc7fd44a96a92382c9065c2c"
uuid = "244e2a9f-e319-4986-a169-4d1fe445cd52"
version = "0.1.2"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
git-tree-sha1 = "9e2f36d3c96a820c678f2f1f1782582fcf685bae"
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"
version = "1.9.1"

[[deps.Dictionaries]]
deps = ["Indexing", "Random", "Serialization"]
git-tree-sha1 = "a55766a9c8f66cf19ffcdbdb1444e249bb4ace33"
uuid = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
version = "0.4.6"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "79a2aca180a85c690c58a020d47b426954b590f8"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.16.0"

[[deps.DimensionalData]]
deps = ["ConstructionBase", "DataAPI", "Dates", "Extents", "Interfaces", "IntervalSets", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "PrecompileTools", "Random", "Statistics", "TableTraits", "Tables"]
git-tree-sha1 = "7ad5fa0affdbdb7c0db39ff6d437c724934ea459"
uuid = "0703355e-b756-11e9-17c0-8b28908087d0"
version = "0.29.27"

    [deps.DimensionalData.extensions]
    DimensionalDataAbstractFFTsExt = "AbstractFFTs"
    DimensionalDataAdaptExt = "Adapt"
    DimensionalDataAlgebraOfGraphicsExt = "AlgebraOfGraphics"
    DimensionalDataArrayInterfaceExt = "ArrayInterface"
    DimensionalDataCategoricalArraysExt = "CategoricalArrays"
    DimensionalDataChainRulesCoreExt = "ChainRulesCore"
    DimensionalDataDiskArraysExt = "DiskArrays"
    DimensionalDataMakieExt = "Makie"
    DimensionalDataNearestNeighborsExt = "NearestNeighbors"
    DimensionalDataPythonCallExt = "PythonCall"
    DimensionalDataRecipesBaseExt = "RecipesBase"
    DimensionalDataSparseArraysExt = "SparseArrays"
    DimensionalDataStatsBaseExt = "StatsBase"

    [deps.DimensionalData.weakdeps]
    AbstractFFTs = "621f4979-c628-5d54-868e-fcf4e3e8185c"
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    AlgebraOfGraphics = "cbdf2221-f076-402e-a563-3d30da359d67"
    ArrayInterface = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
    CategoricalArrays = "324d7699-5711-5eae-9e2f-1d82baa6b597"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    DiskArrays = "3c3547ce-8d99-4f5e-a174-61eb10b00ae3"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    NearestNeighbors = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
    PythonCall = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

[[deps.Distances]]
deps = ["LinearAlgebra", "Statistics", "StatsAPI"]
git-tree-sha1 = "c7e3a542b999843086e2f29dac96a618c105be1d"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.12"
weakdeps = ["ChainRulesCore", "SparseArrays"]

    [deps.Distances.extensions]
    DistancesChainRulesCoreExt = "ChainRulesCore"
    DistancesSparseArraysExt = "SparseArrays"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"
version = "1.11.0"

[[deps.DocStringExtensions]]
git-tree-sha1 = "7442a5dfe1ebb773c29cc2962a8980f47221d76c"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.5"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.7.0"

[[deps.ExceptionUnwrapping]]
deps = ["Test"]
git-tree-sha1 = "d36f682e590a83d63d1c7dbd287573764682d12a"
uuid = "460bff9d-24e4-43bc-9d9f-a8973cb893f4"
version = "0.1.11"

[[deps.ExprTools]]
git-tree-sha1 = "27415f162e6028e81c72b82ef756bf321213b6ec"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.10"

[[deps.Extents]]
git-tree-sha1 = "b309b36a9e02fe7be71270dd8c0fd873625332b4"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.6"

[[deps.FFTViews]]
deps = ["CustomUnitRanges", "FFTW"]
git-tree-sha1 = "cbdf14d1e8c7c8aacbe8b19862e0179fd08321c2"
uuid = "4f61f5a4-77b1-5117-aa51-3ab5ef4ef0cd"
version = "0.3.2"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "Libdl", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "97f08406df914023af55ade2f843c39e99c5d969"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.10.0"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6866aec60ef98e3164cd8d6855225684207e9dff"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.12+0"

[[deps.FITSIO]]
deps = ["CFITSIO", "Printf", "Reexport", "Tables"]
git-tree-sha1 = "f57de3f533590c785210893030736dc11c4a4afb"
uuid = "525bcba6-941b-5504-bd06-fd0dc1a4d2eb"
version = "0.17.5"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "8e9c059d6857607253e837730dbf780b6b151acd"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.19.0"
weakdeps = ["HTTP"]

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FillArrays]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "2f979084d1e13948a3352cf64a25df6bd3b4dca3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "1.16.0"

    [deps.FillArrays.extensions]
    FillArraysPDMatsExt = "PDMats"
    FillArraysSparseArraysExt = "SparseArrays"
    FillArraysStaticArraysExt = "StaticArrays"
    FillArraysStatisticsExt = "Statistics"

    [deps.FillArrays.weakdeps]
    PDMats = "90014a1f-27ba-587c-ab20-58faa44d9150"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.FixedPointNumbers]]
deps = ["Random", "Statistics"]
git-tree-sha1 = "59af96b98217c6ef4ae0dfe065ac7c20831d1a84"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.6"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "cddeab6487248a39dae1a960fff0ac17b2a28888"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "1.3.3"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"
version = "1.11.0"

[[deps.GLPK]]
deps = ["GLPK_jll", "MathOptInterface"]
git-tree-sha1 = "1d706bd23e5d2d407bfd369499ee6f96afb0c3ad"
uuid = "60bf3e95-4087-53dc-ae20-288a0d20c6a6"
version = "1.2.1"

[[deps.GLPK_jll]]
deps = ["Artifacts", "GMP_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6aa6294ba949ccfc380463bf50ff988b46de5bc7"
uuid = "e8aa6df9-e6ca-548a-97ff-1f85fc5b8b98"
version = "5.0.1+1"

[[deps.GMP_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "781609d7-10c4-51f6-84f2-b8444358ff6d"
version = "6.3.0+2"

[[deps.Giflib_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6570366d757b50fabae9f4315ad74d2e40c0560a"
uuid = "59f7168a-df46-5410-90c8-f2779963d0ec"
version = "5.2.3+0"

[[deps.Gumbo]]
deps = ["AbstractTrees", "Gumbo_jll", "Libdl"]
git-tree-sha1 = "eab9e02310eb2c3e618343c859a12b51e7577f5e"
uuid = "708ec375-b3d6-5a57-a7ce-8257bf98657a"
version = "0.8.3"

[[deps.Gumbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "29070dee9df18d9565276d68a596854b1764aa38"
uuid = "528830af-5a63-567c-a44a-034ed33b8444"
version = "0.10.2+0"

[[deps.HTTP]]
deps = ["Base64", "CodecZlib", "ConcurrentUtilities", "Dates", "ExceptionUnwrapping", "Logging", "LoggingExtras", "MbedTLS", "NetworkOptions", "OpenSSL", "PrecompileTools", "Random", "SimpleBufferStream", "Sockets", "URIs", "UUIDs"]
git-tree-sha1 = "51059d23c8bb67911a2e6fd5130229113735fc7e"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "1.11.0"

[[deps.HashArrayMappedTries]]
git-tree-sha1 = "2eaa69a7cab70a52b9687c8bf950a5a93ec895ae"
uuid = "076d061b-32b6-4027-95e0-9a2c6f6d7e74"
version = "0.2.0"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "179267cfa5e712760cd43dcae385d7ea90cc25a4"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.5"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "d1a86724f81bcd184a38fd284ce183ec067d71a0"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "1.0.0"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "0ee181ec08df7d7c911901ea38baf16f755114dc"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "1.0.0"

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "e12629406c6c4442539436581041d372d69c55ba"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.12"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "eb49b82c172811fd2c86759fa0553a2221feb909"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.7"

[[deps.ImageCore]]
deps = ["ColorVectorSpace", "Colors", "FixedPointNumbers", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "PrecompileTools", "Reexport"]
git-tree-sha1 = "8c193230235bbcee22c8066b0374f63b5683c2d3"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.10.5"

[[deps.ImageFiltering]]
deps = ["CatIndices", "ComputationalResources", "DataStructures", "FFTViews", "FFTW", "ImageBase", "ImageCore", "LinearAlgebra", "OffsetArrays", "PrecompileTools", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "TiledIteration"]
git-tree-sha1 = "52116260a234af5f69969c5286e6a5f8dc3feab8"
uuid = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
version = "0.7.12"

[[deps.ImageIO]]
deps = ["FileIO", "IndirectArrays", "JpegTurbo", "LazyModules", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs", "WebP"]
git-tree-sha1 = "696144904b76e1ca433b886b4e7edd067d76cbf7"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.9"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "2a81c3897be6fbcde0802a0ebe6796d0562f63ec"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.10"

[[deps.ImageShow]]
deps = ["Base64", "ColorSchemes", "FileIO", "ImageBase", "ImageCore", "OffsetArrays", "StackViews"]
git-tree-sha1 = "3b5344bcdbdc11ad58f3b1956709b5b9345355de"
uuid = "4e3cecfd-b093-5904-9786-8bbb286a6a31"
version = "0.3.8"

[[deps.ImageTransformations]]
deps = ["AxisAlgorithms", "CoordinateTransformations", "ImageBase", "ImageCore", "Interpolations", "OffsetArrays", "Rotations", "StaticArrays"]
git-tree-sha1 = "dfde81fafbe5d6516fb864dc79362c5c6b973c82"
uuid = "02fcd773-0e25-5acc-982a-7f6622650795"
version = "0.10.2"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "dcc8d0cd653e55213df9b75ebc6fe4a8d3254c65"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.2.2+0"

[[deps.Indexing]]
git-tree-sha1 = "ce1566720fd6b19ff3411404d4b977acd4814f9f"
uuid = "313cdc1a-70c2-5d6a-ae34-0150d3930a38"
version = "1.1.1"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InitialValues]]
git-tree-sha1 = "4da0f88e9a39111c2fa3add390ab15f3a44f3ca3"
uuid = "22cec73e-a1b8-11e9-2c92-598750a2cf9c"
version = "0.3.1"

[[deps.InlineStrings]]
git-tree-sha1 = "8f3d257792a522b4601c24a577954b0a8cd7334d"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.4.5"

    [deps.InlineStrings.extensions]
    ArrowTypesExt = "ArrowTypes"
    ParsersExt = "Parsers"

    [deps.InlineStrings.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
    Parsers = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "ec1debd61c300961f98064cfb21287613ad7f303"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2025.2.0+0"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interfaces]]
git-tree-sha1 = "331ff37738aea1a3cf841ddf085442f31b84324f"
uuid = "85a1e053-f937-4924-92a5-1367d23b7b87"
version = "0.3.2"

[[deps.Interpolations]]
deps = ["Adapt", "AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "65d505fa4c0d7072990d659ef3fc086eb6da8208"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.16.2"
weakdeps = ["ForwardDiff", "Unitful"]

    [deps.Interpolations.extensions]
    InterpolationsForwardDiffExt = "ForwardDiff"
    InterpolationsUnitfulExt = "Unitful"

[[deps.IntervalArithmetic]]
deps = ["CRlibm", "CoreMath", "MacroTools", "OpenBLASConsistentFPCSR_jll", "Printf", "Random", "RoundingEmulator"]
git-tree-sha1 = "921d7e91687e15a2c7c269c226960491fc041832"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "1.0.9"

    [deps.IntervalArithmetic.extensions]
    IntervalArithmeticArblibExt = "Arblib"
    IntervalArithmeticDiffRulesExt = "DiffRules"
    IntervalArithmeticForwardDiffExt = "ForwardDiff"
    IntervalArithmeticIntervalSetsExt = "IntervalSets"
    IntervalArithmeticIrrationalConstantsExt = "IrrationalConstants"
    IntervalArithmeticLinearAlgebraExt = "LinearAlgebra"
    IntervalArithmeticRecipesBaseExt = "RecipesBase"
    IntervalArithmeticSparseArraysExt = "SparseArrays"

    [deps.IntervalArithmetic.weakdeps]
    Arblib = "fb37089c-8514-4489-9461-98f9c8763369"
    DiffRules = "b552c78f-8df3-52c6-915a-8e097449b14b"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    IrrationalConstants = "92d709cd-6900-40b7-9082-c6be49f344b6"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    RecipesBase = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.IntervalSets]]
git-tree-sha1 = "79d6bd28c8d9bccc2229784f1bd637689b256377"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.14"
weakdeps = ["Random", "RecipesBase", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

[[deps.InverseFunctions]]
git-tree-sha1 = "a779299d77cd080bf77b97535acecd73e1c5e5cb"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.17"
weakdeps = ["Dates", "Test"]

    [deps.InverseFunctions.extensions]
    InverseFunctionsDatesExt = "Dates"
    InverseFunctionsTestExt = "Test"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

[[deps.IrrationalConstants]]
git-tree-sha1 = "b2d91fe939cae05960e760110b328288867b5758"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.2.6"

[[deps.IterTools]]
git-tree-sha1 = "42d5f897009e7ff2cf88db414a389e5ed1bdd023"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.10.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Artifacts", "Preferences"]
git-tree-sha1 = "7204148362dafe5fe6a273f855b8ccbe4df8173e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.8.0"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "c89d196f5ffb64bfbf80985b699ea913b0d2c211"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.6.1"

    [deps.JSON.extensions]
    JSONArrowExt = ["ArrowTypes"]

    [deps.JSON.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JSON3]]
deps = ["Dates", "Mmap", "Parsers", "PrecompileTools", "StructTypes", "UUIDs"]
git-tree-sha1 = "411eccfe8aba0814ffa0fdf4860913ed09c34975"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.14.3"

    [deps.JSON3.extensions]
    JSON3ArrowExt = ["ArrowTypes"]

    [deps.JSON3.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

[[deps.JSONTables]]
deps = ["JSON3", "StructTypes", "Tables"]
git-tree-sha1 = "13f7485bb0b4438bb5e83e62fcadc65c5de1d1bb"
uuid = "b9914132-a727-11e9-1322-f18e41205b0b"
version = "1.0.3"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "9496de8fb52c224a2e3f9ff403947674517317d9"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.6"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "c0c9b76f3520863909825cbecdef58cd63de705a"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.5+0"

[[deps.JuMP]]
deps = ["LinearAlgebra", "MacroTools", "MathOptInterface", "MutableArithmetics", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays"]
git-tree-sha1 = "6941586d9cf3c0af718bc6e6250dcf24057d412e"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "1.30.1"
weakdeps = ["DimensionalData"]

    [deps.JuMP.extensions]
    JuMPDimensionalDataExt = "DimensionalData"

[[deps.JuliaSyntaxHighlighting]]
deps = ["StyledStrings"]
uuid = "ac6e5ff7-fb65-4e79-a425-ec3bc9c03011"
version = "1.12.0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "17b94ecafcfa45e8360a4fc9ca6b583b049e4e37"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.1.0+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "dda21b8cbd6a6c40d9d02a73230f9d70fed6918c"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.4.0"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"
version = "1.11.0"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LazySets]]
deps = ["Distributed", "ExprTools", "GLPK", "IntervalArithmetic", "JuMP", "LinearAlgebra", "Random", "ReachabilityBase", "RecipesBase", "Reexport", "Requires", "SharedArrays", "SparseArrays"]
git-tree-sha1 = "24b8470ba3712942e07b1645ee2ddfd102a90b1f"
uuid = "b4f0291d-fe17-52bc-9479-3d1a343d9043"
version = "6.0.3"

[[deps.LazyStack]]
deps = ["ChainRulesCore", "Compat", "LinearAlgebra"]
git-tree-sha1 = "aff621f1f49e9262a34aaf0d57d02ea3b35aec60"
uuid = "1fad7336-0346-5a1a-a56f-a06ba010965b"
version = "0.1.3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.15.0+0"

[[deps.LibGit2]]
deps = ["LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "OpenSSL_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.9.0+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "OpenSSL_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.3+1"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"
version = "1.11.0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "d36c21b9e7c172a44a10484125024495e2625ac0"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.7.1+1"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "XZ_jll", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "f04133fe05eff1667d2054c53d59f9122383fe05"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.2+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.12.0"

[[deps.LogExpFunctions]]
deps = ["DocStringExtensions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "13ca9e2586b89836fd20cccf56e57e2b9ae7f38f"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.29"

    [deps.LogExpFunctions.extensions]
    LogExpFunctionsChainRulesCoreExt = "ChainRulesCore"
    LogExpFunctionsChangesOfVariablesExt = "ChangesOfVariables"
    LogExpFunctionsInverseFunctionsExt = "InverseFunctions"

    [deps.LogExpFunctions.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    ChangesOfVariables = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "f00544d95982ea270145636c181ceda21c4e2575"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.2.0"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "oneTBB_jll"]
git-tree-sha1 = "282cadc186e7b2ae0eeadbd7a4dffed4196ae2aa"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2025.2.0+0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.MappedArrays]]
git-tree-sha1 = "0ee4497a4e80dbd29c058fcee6493f5219556f40"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.3"

[[deps.Markdown]]
deps = ["Base64", "JuliaSyntaxHighlighting", "StyledStrings"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MathOptInterface]]
deps = ["CodecBzip2", "CodecZlib", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test"]
git-tree-sha1 = "9f23c8c1667bd0b0e611110aaf80aa91c1bdf274"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.51.1"

    [deps.MathOptInterface.extensions]
    MathOptInterfaceBenchmarkToolsExt = "BenchmarkTools"
    MathOptInterfaceCliqueTreesExt = "CliqueTrees"

    [deps.MathOptInterface.weakdeps]
    BenchmarkTools = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
    CliqueTrees = "60701a23-6482-424a-84db-faee86b9b1f8"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "NetworkOptions", "Random", "Sockets"]
git-tree-sha1 = "8785729fa736197687541f7053f6d8ab7fc44f92"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.10"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "ff69a2b1330bcb730b9ac1ab7dd680176f5896b8"
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.1010+0"

[[deps.MicroCollections]]
deps = ["Accessors", "BangBang", "InitialValues"]
git-tree-sha1 = "44d32db644e84c75dab479f1bc15ee76a1a3618f"
uuid = "128add7d-3638-4c79-886c-908ea0c25c34"
version = "0.2.0"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "ec4f7fbeab05d7747bdf98eb74d130a2a2ed298d"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.2.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"
version = "1.11.0"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "7b86a5d4d70a9f5cdf2dacb3cbe6d251d1a61dbe"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.4"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2025.11.4"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "dc5b2c4c111c46bc79ac4405eeb563523b39c004"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.8.0"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "9b8215b1ee9e78a293f99797cd31375471b2bcae"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.1.3"

[[deps.NearestNeighbors]]
deps = ["AbstractTrees", "Distances", "StaticArrays"]
git-tree-sha1 = "e2c3bba08dd6dedfe17a17889131b885b8c082f0"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.27"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.3.0"

[[deps.OffsetArrays]]
git-tree-sha1 = "117432e406b5c023f665fa73dc26e79ec3630151"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.17.0"
weakdeps = ["Adapt"]

    [deps.OffsetArrays.extensions]
    OffsetArraysAdaptExt = "Adapt"

[[deps.OpenBLASConsistentFPCSR_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "3287ec88df50429a934ebc6cf14606215e27b987"
uuid = "6cdc7f73-28fd-5e50-80fb-958a8875b1af"
version = "0.3.33+0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.29+0"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "97db9e07fe2091882c765380ef58ec553074e9c7"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.3"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "4a33fd64a77949468187339d8b10c44a422082f1"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.4.12+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"
version = "0.8.7+0"

[[deps.OpenSSL]]
deps = ["BitFlags", "Dates", "MozillaCACerts_jll", "NetworkOptions", "OpenSSL_jll", "Sockets"]
git-tree-sha1 = "1d1aaa7d449b58415f97d2839c318b70ffb525a0"
uuid = "4d8831e6-92b7-49fb-bdf8-b643e874388c"
version = "1.6.1"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "3.5.4+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1346c9208249809840c91b26703912dff463d335"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.6+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "94ba93778373a53bfd5a0caaf7d809c445292ff4"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.2"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "32b657a0d57c310a1a172bfc8c8cf68c5e674323"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.5"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "0fac6313486baae819364c52b4f483450a9d793f"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.12"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "468dbe2b510c876dc091b2c74ed52c7c34f48b9b"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.5"

[[deps.Photometry]]
deps = ["BackgroundMeshes", "FillArrays", "ImageFiltering", "ImageTransformations", "Interpolations", "LazySets", "NearestNeighbors", "Parameters", "RecipesBase", "Reexport", "Rotations", "StaticArrays", "Statistics", "StatsBase", "Transducers", "TypedTables"]
git-tree-sha1 = "75d4ddce863d0cfd5968eb6f3459956eefbfa56e"
uuid = "af68cb61-81ac-52ed-8703-edc140936be4"
version = "0.9.8"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.12.1"
weakdeps = ["REPL"]

    [deps.Pkg.extensions]
    REPLExt = "REPL"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "f9501cc0430a26bc3d156ae1b5b0c1b47af4d6da"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.3.3"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "PrecompileTools", "Printf", "Random", "Reexport", "StableRNGs", "Statistics"]
git-tree-sha1 = "26ca162858917496748aad52bb5d3be4d26a228a"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.4"

[[deps.PlotlyBase]]
deps = ["ColorSchemes", "Colors", "Dates", "DelimitedFiles", "DocStringExtensions", "JSON", "LaTeXStrings", "Logging", "Parameters", "Pkg", "REPL", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "6256ab3ee24ef079b3afa310593817e069925eeb"
uuid = "a03496cd-edff-5a9b-9e67-9cda94a718b5"
version = "0.8.23"

    [deps.PlotlyBase.extensions]
    DataFramesExt = "DataFrames"
    DistributionsExt = "Distributions"
    IJuliaExt = "IJulia"
    JSON3Ext = "JSON3"

    [deps.PlotlyBase.weakdeps]
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    IJulia = "7073ff75-c697-5162-941a-fcdaad2a7d2a"
    JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"

[[deps.PlutoPlotly]]
deps = ["AbstractPlutoDingetjes", "Artifacts", "ColorSchemes", "Colors", "Dates", "Downloads", "HypertextLiteral", "InteractiveUtils", "LaTeXStrings", "Markdown", "Pkg", "PlotlyBase", "PrecompileTools", "Reexport", "ScopedValues", "Scratch", "TOML"]
git-tree-sha1 = "2b9e3d771adfe535a4fdda855f4741fdaacd3f7f"
uuid = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
version = "0.6.6"

    [deps.PlutoPlotly.extensions]
    PlotlyKaleidoExt = "PlotlyKaleido"
    UnitfulExt = "Unitful"

    [deps.PlutoPlotly.weakdeps]
    PlotlyKaleido = "f2990250-8cf9-495f-b13a-cce12b45703c"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "e189d0623e7ce9c37389bac17e80aac3b0302e75"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.83"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "edbeefc7a4889f528644251bdb5fc9ab5348bc2c"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.3.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "8b770b60760d4451834fe79dd483e318eee709c4"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.2"

[[deps.PrettyTables]]
deps = ["Crayons", "LaTeXStrings", "Markdown", "PrecompileTools", "Printf", "REPL", "Reexport", "StringManipulation", "Tables"]
git-tree-sha1 = "624de6279ab7d94fc9f672f0068107eb6619732c"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "3.3.2"

    [deps.PrettyTables.extensions]
    PrettyTablesTypstryExt = "Typstry"

    [deps.PrettyTables.weakdeps]
    Typstry = "f0ed7684-a786-439e-b1e3-3b82803b501e"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "fbb92c6c56b34e1a2c4c36058f68f332bec840e7"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.11.0"

[[deps.PtrArrays]]
git-tree-sha1 = "4fbbafbc6251b883f4d2705356f3641f3652a7fe"
uuid = "43287f4e-b6f4-7ad1-bb20-aadabca52c3d"
version = "1.4.0"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "472daaa816895cb7aee81658d4e7aec901fa1106"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.2"

[[deps.Quaternions]]
deps = ["LinearAlgebra", "Random", "RealDot"]
git-tree-sha1 = "4d8c1b7c3329c1885b857abb50d08fa3f4d9e3c8"
uuid = "94ee1d12-ae83-5a48-8b1c-48b8ff168ae0"
version = "0.7.7"

[[deps.REPL]]
deps = ["InteractiveUtils", "JuliaSyntaxHighlighting", "Markdown", "Sockets", "StyledStrings", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"
version = "1.11.0"

[[deps.Random]]
deps = ["SHA"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
version = "1.11.0"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "1342a47bf3260ee108163042310d26f2be5ec90b"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.5"
weakdeps = ["FixedPointNumbers"]

    [deps.Ratios.extensions]
    RatiosFixedPointNumbersExt = "FixedPointNumbers"

[[deps.ReachabilityBase]]
deps = ["ExprTools", "InteractiveUtils", "LinearAlgebra", "Random", "Requires", "SparseArrays"]
git-tree-sha1 = "8c4ee9dd72d7ba962d5d4a0974f7e8f98fe275f6"
uuid = "379f33d0-9447-4353-bd03-d664070e549f"
version = "0.3.6"

[[deps.RealDot]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9f0a1b71baaf7650f4fa8a1d168c7fb6ee41f0c9"
uuid = "c1ae055f-0cd5-4b69-90a6-9a35b1a98df9"
version = "0.1.0"

[[deps.RecipesBase]]
deps = ["PrecompileTools"]
git-tree-sha1 = "5c3d09cc4f31f5fc6af001c250bf1278733100ff"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.4"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "62389eeff14780bfe55195b7204c0d8738436d64"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.1"

[[deps.ResumableFunctions]]
deps = ["Logging", "MacroTools"]
git-tree-sha1 = "6758ba57a8e3de8c73ba3ec8c40f8bef80699d53"
uuid = "c5292f4c-5179-55e1-98c5-05642aab7184"
version = "1.0.6"

[[deps.Rotations]]
deps = ["LinearAlgebra", "Quaternions", "Random", "StaticArrays"]
git-tree-sha1 = "5680a9276685d392c87407df00d57c9924d9f11e"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.7.1"
weakdeps = ["RecipesBase"]

    [deps.Rotations.extensions]
    RotationsRecipesBaseExt = "RecipesBase"

[[deps.RoundingEmulator]]
git-tree-sha1 = "40b9edad2e5287e05bd413a38f61a8ff55b9557b"
uuid = "5eaf0fd0-dfba-4ccb-bf02-d820a40db705"
version = "0.2.1"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "e24dc23107d426a096d3eae6c165b921e74c18e4"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.2"

[[deps.SciMLPublic]]
git-tree-sha1 = "0ba076dbdce87ba230fff48ca9bca62e1f345c9b"
uuid = "431bcebd-1456-4ced-9d72-93c2757fff0b"
version = "1.0.1"

[[deps.ScopedValues]]
deps = ["HashArrayMappedTries", "Logging"]
git-tree-sha1 = "67a144433c4ce877ee6d1ada69a124d6b1ecf7be"
uuid = "7e506255-f358-4e82-b7e4-beb19740aa63"
version = "1.6.2"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "084c47c7c5ce5cfecefa0a98dff69eb3646b5a80"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.10"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "c5391c6ace3bc430ca630251d02ea9687169ca68"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.2"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"
version = "1.11.0"

[[deps.SimpleBufferStream]]
git-tree-sha1 = "f305871d2f381d21527c770d4788c06c097c9bc1"
uuid = "777ac1f9-54b0-4bf8-805c-2214025038e7"
version = "1.2.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "7ddb0b49c109481b046972c0e4ab02b2127d6a75"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.6"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "0494aed9501e7fb65daba895fb7fd57cc38bc743"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.5"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "64d974c2e6fdf07f8155b5b2ca2ffa9069b608d9"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.2.2"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.12.0"

[[deps.SpecialFunctions]]
deps = ["IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "6547cbdd8ce32efba0d21c5a40fa96d1a3548f9f"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.8.0"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.SplitApplyCombine]]
deps = ["Dictionaries", "Indexing"]
git-tree-sha1 = "55db78e829cf726162fc4fc1b30d05f92092f3f6"
uuid = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"
version = "1.3.0"

[[deps.SplittablesBase]]
deps = ["Setfield", "Test"]
git-tree-sha1 = "e08a62abc517eb79667d0a29dc08a3b589516bb5"
uuid = "171d559e-b47b-412a-8079-5efa626c420e"
version = "0.1.15"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "4f96c596b8c8258cc7d3b19797854d368f243ddc"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.4"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "be1cf4eb0ac528d96f5115b4ed80c26a8d8ae621"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.2"

[[deps.Static]]
deps = ["CommonWorldInvalidations", "IfElse", "PrecompileTools", "SciMLPublic"]
git-tree-sha1 = "bb072715f158b59ad8819ff80da5ffa90cce6ceb"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "1.4.0"

[[deps.StaticArrayInterface]]
deps = ["ArrayInterface", "Compat", "IfElse", "LinearAlgebra", "PrecompileTools", "SciMLPublic", "Static"]
git-tree-sha1 = "2a635e15d5035c53b345077c947f31ff91744078"
uuid = "0d7ed370-da01-4f52-bd93-41d350b8b718"
version = "1.10.0"
weakdeps = ["OffsetArrays", "StaticArrays"]

    [deps.StaticArrayInterface.extensions]
    StaticArrayInterfaceOffsetArraysExt = "OffsetArrays"
    StaticArrayInterfaceStaticArraysExt = "StaticArrays"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "PrecompileTools", "Random", "StaticArraysCore"]
git-tree-sha1 = "246a8bb2e6667f832eea063c3a56aef96429a3db"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.9.18"
weakdeps = ["ChainRulesCore", "Statistics"]

    [deps.StaticArrays.extensions]
    StaticArraysChainRulesCoreExt = "ChainRulesCore"
    StaticArraysStatisticsExt = "Statistics"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6ab403037779dae8c514bad259f32a447262455a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.4"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "178ed29fd5b2a2cfc3bd31c13375ae925623ff36"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.8.0"

[[deps.StatsBase]]
deps = ["AliasTables", "DataAPI", "DataStructures", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "c6f18e5a52a176a383f6f6c635e0f81feed1d6d4"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.11"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "d05693d339e37d6ab134c5ab53c29fce5ee5d7d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.4"

[[deps.StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "159331b30e94d7b11379037feeb9b690950cace8"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.11.0"

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "82bee338d650aa515f31866c460cb7e3bcef90b8"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.8.2"

    [deps.StructUtils.extensions]
    StructUtilsMeasurementsExt = ["Measurements"]
    StructUtilsStaticArraysCoreExt = ["StaticArraysCore"]
    StructUtilsTablesExt = ["Tables"]

    [deps.StructUtils.weakdeps]
    Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
    StaticArraysCore = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.8.3+2"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.TableMetadataTools]]
deps = ["DataAPI", "Dates", "TOML", "Tables", "Unitful"]
git-tree-sha1 = "c0405d3f8189bb9a9755e429c6ea2138fca7e31f"
uuid = "9ce81f87-eacc-4366-bf80-b621a3098ee2"
version = "0.1.0"

[[deps.TableScraper]]
deps = ["Cascadia", "Gumbo", "HTTP", "Tables"]
git-tree-sha1 = "73e600bad3a9b6c04c8a055e316fd60dd2ab372c"
uuid = "3d876f86-fca9-45cb-9864-7207416dc431"
version = "0.1.4"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "OrderedCollections", "TableTraits"]
git-tree-sha1 = "f2c1efbc8f3a609aadf318094f8fc5204bdaf344"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.12.1"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
version = "1.11.0"

[[deps.TiffImages]]
deps = ["CodecZstd", "ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "PrecompileTools", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "9ca5f1f2d42f80df4b8c9f6ab5a64f438bbd9976"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.9"

[[deps.TiledIteration]]
deps = ["OffsetArrays", "StaticArrayInterface"]
git-tree-sha1 = "1176cc31e867217b06928e2f140c90bd1bc88283"
uuid = "06e1c1a7-607b-532d-9fad-de7d9aa2abac"
version = "0.5.0"

[[deps.TranscodingStreams]]
git-tree-sha1 = "0c45878dcfdcfa8480052b6ab162cdd138781742"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.11.3"

[[deps.Transducers]]
deps = ["Accessors", "ArgCheck", "BangBang", "Baselet", "CompositionsBase", "ConstructionBase", "DefineSingletons", "Distributed", "InitialValues", "Logging", "Markdown", "MicroCollections", "SplittablesBase", "Tables"]
git-tree-sha1 = "4aa1fdf6c1da74661f6f5d3edfd96648321dade9"
uuid = "28d57a85-8fef-5791-bfe6-a80928e7c999"
version = "0.4.85"

    [deps.Transducers.extensions]
    TransducersAdaptExt = "Adapt"
    TransducersBlockArraysExt = "BlockArrays"
    TransducersDataFramesExt = "DataFrames"
    TransducersLazyArraysExt = "LazyArrays"
    TransducersOnlineStatsBaseExt = "OnlineStatsBase"
    TransducersReferenceablesExt = "Referenceables"

    [deps.Transducers.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    BlockArrays = "8e7c35d0-a365-5155-bbbb-fb81a777f24e"
    DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
    LazyArrays = "5078a376-72f3-5289-bfd5-ec5146d43c02"
    OnlineStatsBase = "925886fa-5bf2-5e8e-b522-a9147a512338"
    Referenceables = "42d2dcc6-99eb-4e98-b66c-637b7d73030e"

[[deps.Tricks]]
git-tree-sha1 = "311349fd1c93a31f783f977a71e8b062a57d4101"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.13"

[[deps.TypedTables]]
deps = ["Adapt", "Dictionaries", "Indexing", "SplitApplyCombine", "Tables", "Unicode"]
git-tree-sha1 = "84fd7dadde577e01eb4323b7e7b9cb51c62c60d4"
uuid = "9d95f2ec-7b3d-5a63-8d20-e2491e220bb9"
version = "1.4.6"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.Unitful]]
deps = ["Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "57e1b2c9de4bd6f40ecb9de4ac1797b81970d008"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.28.0"

    [deps.Unitful.extensions]
    ConstructionBaseUnitfulExt = "ConstructionBase"
    ForwardDiffExt = "ForwardDiff"
    InverseFunctionsUnitfulExt = "InverseFunctions"
    LatexifyExt = ["Latexify", "LaTeXStrings"]
    NaNMathExt = "NaNMath"
    PrintfExt = "Printf"

    [deps.Unitful.weakdeps]
    ConstructionBase = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
    ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"
    LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
    Latexify = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
    NaNMath = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
    Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.WCS]]
deps = ["ConstructionBase", "WCS_jll"]
git-tree-sha1 = "c12065744b66adfed32d24c2a13a3053cc235ea7"
uuid = "15f3aee2-9e10-537f-b834-a6fb8bdb944d"
version = "0.6.3"

[[deps.WCS_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "947bfa11fcd65dac9e9b2e963504fba6b4971d31"
uuid = "550c8279-ae0e-5d1b-948f-937f2608a23e"
version = "7.7.0+0"

[[deps.WebP]]
deps = ["CEnum", "ColorTypes", "FileIO", "FixedPointNumbers", "ImageCore", "libwebp_jll"]
git-tree-sha1 = "aa1ca3c47f119fbdae8770c29820e5e6119b83f2"
uuid = "e3aaa7dc-3e4b-44e0-be63-ffb868ccd7c1"
version = "0.1.3"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "248a7031b3da79a127f14e5dc5f417e26f9f6db7"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "1.1.0"

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "b29c22e245d092b8b4e8d3c09ad7baa586d9f573"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.3+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "808090ede1d41644447dd5cbafced4731c56bd2f"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.13+0"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aa1261ebbac3ccc8d16558ae6799524c450ed16b"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.13+0"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "52858d64353db33a56e13c341d7bf44cd0d7b309"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.6+0"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libX11_jll"]
git-tree-sha1 = "1a4a26870bf1e5d26cd585e38038d399d7e65706"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.8+0"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libXau_jll", "Xorg_libXdmcp_jll"]
git-tree-sha1 = "bfcaf7ec088eaba362093393fe11aa141fa15422"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.17.1+0"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "a63799ff68005991f9d9491b6e95bd3478d783cb"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.6.0+0"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.3.1+2"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "446b23e73536f84e8037f5dce465e92275f6a308"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.15.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "e51150d5ab85cee6fc36726850f0e627ad2e4aba"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.58+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "libpng_jll"]
git-tree-sha1 = "c1733e347283df07689d71d61e14be986e49e47a"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.5+0"

[[deps.libwebp_jll]]
deps = ["Artifacts", "Giflib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libglvnd_jll", "Libtiff_jll", "libpng_jll"]
git-tree-sha1 = "4e4282c4d846e11dce56d74fa8040130b7a95cb3"
uuid = "c5f90fcd-3b7e-5836-afba-fc50a0988cb2"
version = "1.6.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.64.0+1"

[[deps.oneTBB_jll]]
deps = ["Artifacts", "JLLWrappers", "LazyArtifacts", "Libdl"]
git-tree-sha1 = "da8c1f6eee04831f14edcfa5dae611d309807e57"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2022.3.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.7.0+0"
"""

# ╔═╡ Cell order:
# ╟─ac2acb87-8515-41cf-a762-ca48d8cd269a
# ╟─aa005b55-626e-41e0-8fe1-137bd7dd5599
# ╟─4266575e-e19f-48e4-8b21-6f296c6d3f33
# ╟─aaaaa4d6-737b-4e53-a3a4-fcac09789d4e
# ╟─c1bbb6a2-6996-4fee-a642-a0212b473474
# ╟─abb9a9c8-5cac-4af3-b0a0-b7a3608dfe1a
# ╠═f6197e8e-3132-4ab5-86d7-32572e337c58
# ╠═7c078085-ff30-400d-a0ab-2680f468c415
# ╠═035fcecb-f998-4644-9650-6aeaced3e41f
# ╟─b360ad74-58b7-47b5-a8b0-437ef1119303
# ╟─1356c02f-9ff2-491f-b55d-666ee76e6fae
# ╟─5321f774-67fc-4355-9411-2e624a00e724
# ╟─777dcd30-70ba-4091-9075-4f1be4e309c0
# ╟─1f3610da-f81e-4cdb-bad6-b2475497dc5f
# ╟─06d26240-81b6-401b-8eda-eab3a9a0fb20
# ╟─dbe812e2-a795-4caa-842d-07da5eabcade
# ╟─74197e45-3b80-44ad-b940-f2544f2f9b54
# ╠═2b8c75f6-c148-4c70-be6a-c1a4b95d5849
# ╟─a6de852c-01e6-49a2-bc78-8d1b6eb51c0c
# ╟─7d7cd508-be27-4f52-bc13-91c702450167
# ╟─5abbcbe0-3ee6-4658-9c99-e4567a23e3f6
# ╠═86e53a41-ab0d-4d9f-8a80-855949847ba2
# ╟─009f2c3f-bc8f-4874-9545-f18d6722284b
# ╟─8f0e6529-bd67-47aa-9ddf-4032a5483a98
# ╟─7d54fd96-b268-4964-929c-d62c7d89b4b2
# ╟─1d14c32a-c0b5-4b3e-8a70-c50f539f6e69
# ╟─e94b7436-462b-4d34-b721-990c8682ee6e
# ╟─1df329a0-629a-4527-8e5d-1dbac9ed8497
# ╠═1fe59945-8bce-44f3-b548-9646c2ce6bda
# ╠═81f6a02b-e6c6-4e38-a18c-4aa368fcd0aa
# ╟─e7ad4e24-5dc9-4713-836a-be001304e45c
# ╠═5b34ed05-4181-4fca-a80e-161fa99bc26e
# ╟─102ce649-e560-470e-afa5-699db577e148
# ╟─d6d19588-9fa5-4b3e-987a-082345357fe7
# ╟─96dc5bbe-3284-43a0-8c04-c1bb51ad618b
# ╟─15ad7461-9c40-4755-8f00-14aa3be53e0f
# ╟─6470b357-4dc6-4b2b-9760-93d64bab13e9
# ╟─17eb5723-71f4-4344-b1b1-41b894e7582b
# ╟─59392770-f59e-4188-a675-89c2f2fc67d9
# ╠═edf5f093-19cc-4802-a777-95d8492996a8
# ╟─9d88c884-3187-452d-8453-7f095dac4b03
# ╟─1b71497f-636a-45c8-8f51-728bee091696
# ╟─1ede8642-1f36-4aad-bcad-383fd211d31a
# ╠═381d0147-264b-46f6-82ab-8c840c50c7d1
# ╠═79c924a7-f915-483d-aee6-94e749d3b004
# ╠═f1ed6484-8f6a-4fbf-9a3d-0fe20360ab3b
# ╠═954c7918-7dd1-4967-a67b-7856f00dc498
# ╠═2e59cc0d-e477-4826-b8b6-d2d68c8592a9
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
# ╟─399f53c5-b654-4330-9ead-4d795917b03b
# ╟─a00cbbfc-56ce-413a-a7b8-13de8541fa6f
# ╟─6cec1700-f2de-4e80-b26d-b23b5f7f1823
# ╟─95f9803a-86df-4517-adc8-0bcbb0ff6fbc
# ╟─a5f3915c-6eed-480d-9aed-8fdd052a324a
# ╟─31c23e2b-1a2d-41aa-81c1-22868e241f7e
# ╟─1d2bedb1-509d-4956-8e5a-ad1c0f1ffe26
# ╟─9c482134-6336-4e72-9d30-87080ebae671
# ╟─90b6ef16-7853-46e1-bbd6-cd1a904c442a
# ╠═f2c89a20-09d5-47f4-8f83-e59477723d95
# ╟─8a39fbbb-6b5b-4744-a875-469c289242fb
# ╠═3f548bb1-37b0-48b7-a35c-d7701405a64e
# ╟─6c2a385c-5116-4aa9-9745-bea2326af593
# ╠═a984c96d-273e-4d6d-bab8-896f14a79103
# ╟─f290d98e-5a8a-44f2-bee5-b93738abe9af
# ╟─e7f88515-305b-4899-8fa0-326e9e2097b5
# ╟─46e6bba9-0c83-47b7-be17-f41301efa18e
# ╟─77544f9e-6053-4ed6-aa9a-4e7a54ca41d9
# ╟─3242f19a-83f7-4db6-b2ea-6ca3403e1039
# ╟─1e5596fb-7dca-408b-afbd-6ca2e2487d75
# ╟─2ea12676-7b5e-444e-8025-5bf9c05d0e2d
# ╟─d359625e-5a95-49aa-86e4-bc65299dd92a
# ╟─829cde81-be03-4a9f-a853-28f84923d493
# ╟─3c601844-3bb9-422c-ab1e-b40f7e7cb0df
# ╟─f26f890b-5924-497c-85a3-eff924d0470b
# ╟─95a67d04-0a32-4e55-ac2f-d004ecc9ca84
# ╟─21e828e5-00e4-40ce-bff5-60a17439bf44
# ╟─e35d4be7-366d-4ca5-a89a-5de24e4c6677
# ╟─a3bcad72-0e6c-43f8-a08d-777a154190d8
# ╟─8da80446-84d7-44bb-8122-874b4c9514f4
# ╟─24256769-2274-4b78-8445-88ec4536c407
# ╟─f41df561-85ff-484b-8188-883c1fea21c9
# ╟─637d7f71-e884-43df-be10-2a490486d0dd
# ╠═6bc5d30d-2051-4249-9f2a-c4354aa49198
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
