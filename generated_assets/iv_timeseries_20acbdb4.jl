### A Pluto.jl notebook ###
# v0.20.24

#> [frontmatter]
#> title = "IV - Time Series"
#> date = "2025-10-03"
#> tags = ["asp", "time series"]
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
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.add(["PlutoUI", "CommonMark", "CCDReduction", "DataDeps", "DataFramesMeta", "HTTP", "JSONTables", "TableScraper", "AstroImages", "PlutoPlotly", "AstroAngles", "Photometry", "Dates", "Unitful", "Statistics", "ImageFiltering"])
	
	Pkg.add([		 
	Pkg.PackageSpec(; rev = "main", url = "https://github.com/JuliaAstro/Astroalign.jl"),
	Pkg.PackageSpec(; rev = "main", url = "https://github.com/JuliaAstro/ConsensusFitting.jl")
	])
	
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
# IV - Introduction to Time Series

Using the photometric analysis tools developed in the previous notebook, we will now turn to the technique of generalizing this for images taken at multiple times to build a time series science product, aka a light curve. We will use sample eVscope data of an eclipsing binary system as a real life test case, and show how we can find additional targets to study from the American Association of Variable Star Observers ([AAVSO](https://www.aavso.org/)).
"""

# ╔═╡ aa005b55-626e-41e0-8fe1-137bd7dd5599
md"""
## 1. Background 📖

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
## 2. Introduction 🤝

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
## 3. Data inspection 🔎

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
Resource("https://github.com/Unistellar-science/SETI-Education/blob/main/src/ucan/eclipsing_binary/assets/finder_WUMa.jpg?raw=true")

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

# ╔═╡ 1df329a0-629a-4527-8e5d-1dbac9ed8497
md"""
## 4. Image alignment 📐

A typical astronomical observation might use the know RA and Dec of the field to [plate solve](https://astrobackyard.com/plate-solving/) each frame against background sources (see, e.g., [astrometry.net](https://astrometry.net/)). This then gives a coordinate transformation (e.g., with the [World Coordinate System (WCS) standard](https://fits.gsfc.nasa.gov/fits_wcs.html)) that can be applied to each frame to align them to a common grid with open source tools like [AstroImageJ](https://www.astro.louisville.edu/software/astroimagej/). Unfortunately, plate solving is a computationally expensive process that can take quite a while, especially if we have a large number of frames. Fortunately, there is a nice alternative that we can use if we do not care about the WCS information: [asterisms](https://en.wikipedia.org/wiki/Asterism_(astronomy)).

In this process, one frame is aligned to another in much the same way that the human brain might try to: by matching common shapes between each frame to each other. This works indpendently of WCS information, so it completely avoids the need to plate solve our images. We will use this method to align our science frames.
"""

# ╔═╡ bdfc0804-b83a-470f-a6e0-1e030eac63d8
cm"""
!!! note
	If the frame alignment fails, try passing one of the [options listed here](https://juliaastro.org/Astroalign.jl/dev/#Astroalign.align_frame) to `align_frames` above (it will automatically forward to the `align_frame` function from [Astroalign.jl](https://juliaastro.org/Astroalign.jl/dev/)).

	If this still fails, phone your local astronomer, i.e., Ian or Shanil 📞.
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
## 5. Aperture photometry 🔾

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

# ╔═╡ 1ede8642-1f36-4aad-bcad-383fd211d31a
md"""
!!! note
	To reload the original sample data, clear the field above and click `Enter` again.
"""

# ╔═╡ e34ceb7c-1584-41ce-a5b5-3532fac3c03d
md"""
### Wrapping up

We now have a light curve of an eclipsing binary captured at the predicted time! By eye, totality looks to have lasted for about half an hour, and the total eclipse duration looks to be close to the three hours estimated by the ephemeris. Not too bad for a quick observation taken from a backyard in the middle of a light polluted city.

Since the total period for this system is about 8 hours, we only caught one of the eclipses, in this case the secondary eclipse. With a more careful treatment of the calibration and data reduction procedures, we might also be able to measure the eclipse depth as well as get a more precise estimate on the "time of minimum" (ToM). The former allows us to determine the size of the eclipsing object relative to its companion, and the latter is the precise time that the two objects are exactly aligned. Measuring the ToM over time create so-called "[O-C curves](https://www.aavso.org/analysis-times-minima-o-c-diagram)", or observed minus calculated (predicted) times over time, which allow us to not only measure the periods of binary systems, but also characterize the stellar and orbital evolution of these dynamic systems.
"""

# ╔═╡ 276ff16f-95f1-44eb-971d-db65e8821e59
md"""
## 6. Extensions 🌱
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

# ╔═╡ e7f88515-305b-4899-8fa0-326e9e2097b5
md"""
## Convenience functions
"""

# ╔═╡ bdc24b15-d14a-422c-a7aa-5335547fa53c
function align_frames(imgs; kwargs...)
	fixed = first(imgs)
	frames_aligned = map(imgs[begin+1:end]) do img
		img_aligned, _ = align_frame(img, fixed; kwargs...)
		shareheader(img, img_aligned)
	end
	return [fixed, frames_aligned...]
end

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

# ╔═╡ 06d26240-81b6-401b-8eda-eab3a9a0fb20
let
	obs_start, obs_end = df_sci[:, "DATE-OBS"] |> extrema .|> string
md"""
We see that we have $(nrow(df_sci)) fits files taken from $(obs_start) -- $(obs_end) UTC. Here's what that first image looks like compared to its [finder chart](https://astro.swarthmore.edu/transits/finding_charts.cgi):
"""
end

# ╔═╡ 2b8c75f6-c148-4c70-be6a-c1a4b95d5849
img_sci = load(first(df_sci).path); # The semicolon hides automatic output

# ╔═╡ dbe812e2-a795-4caa-842d-07da5eabcade
img_sci[reverse(begin:end), begin:end]

# ╔═╡ 7d7cd508-be27-4f52-bc13-91c702450167
header(img_sci)

# ╔═╡ edf5f093-19cc-4802-a777-95d8492996a8
h = header(img_sci);

# ╔═╡ f6197e8e-3132-4ab5-86d7-32572e337c58
img_size, img_eltype = size(img_sci), eltype(img_sci);

# ╔═╡ 5abbcbe0-3ee6-4658-9c99-e4567a23e3f6
md"""
It looks like this image is $(first(img_size)) x $(last(img_size)) pixels, with the ADU counts for each pixel stored as a $(img_eltype) to reduce memory storage. Now that we know that we are pointing at the right place in the sky, let's take at look at how these images change over time. Drag the slider below to scroll through each of our science frames. (Note for the rest of this notebook that we will be using the default image orientation in the plotting software):
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

# ╔═╡ f1ed6484-8f6a-4fbf-9a3d-0fe20360ab3b
# Aperture object that will be used for photometry
# (x_center, y_center, radius)
ap_target = CircularAperture(coords.x, coords.y, coords.r);

# ╔═╡ 954c7918-7dd1-4967-a67b-7856f00dc498
ap_comp1 = CircularAperture(coords.x_comp, coords.y_comp, coords.r_comp);

# ╔═╡ 381d0147-264b-46f6-82ab-8c840c50c7d1
aps = [ap_target, ap_comp1];

# ╔═╡ 035fcecb-f998-4644-9650-6aeaced3e41f
imgs_sci = map(eachrow(df_sci)) do f
	img = load(f.path)
	mapwindow!(median!, similar(img), img, (3, 3))
end;
#[load(f.path) for f in eachrow(df_sci)];

# ╔═╡ c06e64ef-4085-4bb5-9b8b-2ed244d5dbe8
md"""
Frame number: $(frame_slider = @bind frame_i Slider(1:length(imgs_sci); show_value=true))
"""

# ╔═╡ 1fe59945-8bce-44f3-b548-9646c2ce6bda
imgs_sci_aligned = align_frames(imgs_sci);

# ╔═╡ 73e16c0e-873c-46a3-a0fd-d7ed5405ed7b
md"""
Frame number: $(frame_slider_aligned = @bind frame_i_aligned Slider(1:length(imgs_sci_aligned); show_value=true))
"""

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

# ╔═╡ 86e53a41-ab0d-4d9f-8a80-855949847ba2
let
	zmin, zmax = AstroImages.PlotUtils.zscale(first(imgs_sci))
	p = plot_img(frame_i, imgs_sci[frame_i]; zmin, zmax)
	relayout!(p; shapes)
	p
end

# ╔═╡ f3683998-543c-4bc4-8b73-fc1de6a6a955
let
	zmin, zmax = AstroImages.PlotUtils.zscale(first(imgs_sci))
	p = plot_img(frame_i_aligned, imgs_sci_aligned[frame_i_aligned]; zmin, zmax)
	relayout!(p; shapes)
	p
end

# ╔═╡ Cell order:
# ╟─ac2acb87-8515-41cf-a762-ca48d8cd269a
# ╟─aa005b55-626e-41e0-8fe1-137bd7dd5599
# ╟─4266575e-e19f-48e4-8b21-6f296c6d3f33
# ╟─aaaaa4d6-737b-4e53-a3a4-fcac09789d4e
# ╟─c1bbb6a2-6996-4fee-a642-a0212b473474
# ╟─abb9a9c8-5cac-4af3-b0a0-b7a3608dfe1a
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
# ╟─c06e64ef-4085-4bb5-9b8b-2ed244d5dbe8
# ╟─86e53a41-ab0d-4d9f-8a80-855949847ba2
# ╟─009f2c3f-bc8f-4874-9545-f18d6722284b
# ╟─8f0e6529-bd67-47aa-9ddf-4032a5483a98
# ╟─7d54fd96-b268-4964-929c-d62c7d89b4b2
# ╟─1df329a0-629a-4527-8e5d-1dbac9ed8497
# ╠═1fe59945-8bce-44f3-b548-9646c2ce6bda
# ╟─bdfc0804-b83a-470f-a6e0-1e030eac63d8
# ╟─e7ad4e24-5dc9-4713-836a-be001304e45c
# ╟─73e16c0e-873c-46a3-a0fd-d7ed5405ed7b
# ╟─f3683998-543c-4bc4-8b73-fc1de6a6a955
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
# ╟─381d0147-264b-46f6-82ab-8c840c50c7d1
# ╟─79c924a7-f915-483d-aee6-94e749d3b004
# ╟─f1ed6484-8f6a-4fbf-9a3d-0fe20360ab3b
# ╟─954c7918-7dd1-4967-a67b-7856f00dc498
# ╟─2e59cc0d-e477-4826-b8b6-d2d68c8592a9
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
# ╟─e7f88515-305b-4899-8fa0-326e9e2097b5
# ╟─bdc24b15-d14a-422c-a7aa-5335547fa53c
# ╟─46e6bba9-0c83-47b7-be17-f41301efa18e
# ╟─77544f9e-6053-4ed6-aa9a-4e7a54ca41d9
# ╟─3242f19a-83f7-4db6-b2ea-6ca3403e1039
# ╟─1e5596fb-7dca-408b-afbd-6ca2e2487d75
# ╟─2ea12676-7b5e-444e-8025-5bf9c05d0e2d
# ╟─d359625e-5a95-49aa-86e4-bc65299dd92a
# ╟─829cde81-be03-4a9f-a853-28f84923d493
# ╟─f290d98e-5a8a-44f2-bee5-b93738abe9af
# ╟─3c601844-3bb9-422c-ab1e-b40f7e7cb0df
# ╟─f26f890b-5924-497c-85a3-eff924d0470b
# ╟─95a67d04-0a32-4e55-ac2f-d004ecc9ca84
# ╠═f6197e8e-3132-4ab5-86d7-32572e337c58
# ╠═7c078085-ff30-400d-a0ab-2680f468c415
# ╠═035fcecb-f998-4644-9650-6aeaced3e41f
# ╠═a984c96d-273e-4d6d-bab8-896f14a79103
# ╟─21e828e5-00e4-40ce-bff5-60a17439bf44
# ╟─e35d4be7-366d-4ca5-a89a-5de24e4c6677
# ╟─a3bcad72-0e6c-43f8-a08d-777a154190d8
# ╟─8da80446-84d7-44bb-8122-874b4c9514f4
# ╟─24256769-2274-4b78-8445-88ec4536c407
# ╠═6bc5d30d-2051-4249-9f2a-c4354aa49198
