### A Pluto.jl notebook ###
# v0.20.24

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

# ╔═╡ 760e3f79-d623-4544-af77-5250d61f4854
begin
	# Notebook widgets
	using PlutoUI, CommonMark

	# Analysis tools
	using AstroImages, ColorTypes, Photometry, DataFramesMeta, CSV, PlutoPlotly, FlexiJoins, SkyCoords, VirtualObservatory, Unitful, UnitfulAstro
	
	# Colormap default settings
	AstroImages.set_cmap!(nothing)
end;

# ╔═╡ 8616ef80-e4f2-4121-8463-f83e3594ac91
md"""
# Color Magnitude Diagram Lab

In this lab, we will explore how astronomers take photometric measurements to estimate different properties of star (e.g., age, distance, and temperature) via so called [color magnitude diagrams](https://apod.nasa.gov/apod/ap010223.html) (CMD)s. Here is an example of one below:

![](https://apod.nasa.gov/apod/image/0102/m55cmd_mochejska.jpg)

For a given star, measuring the difference in observed flux measured between different filters (e.g., B and V, x-axis) give an estimate of the star's temperature, while the flux measurement in a single filter gives an estimate of the star's luminosity (y-axis). Plotting these together reveals an underlying relationship that [ties all stars together](https://science.nasa.gov/asset/hubble/constructing-the-hertzsprung-russell-diagram-for-globular-star-cluster/).

$(Resource("https://assets.science.nasa.gov/content/dam/science/missions/hubble/releases/2010/10/STScI-01EVSKXA7JN0AR357P4TZ25FA5.mp4"))

We will recreate these measurements for the famous M67 star cluster.
"""

# ╔═╡ 9963a6fc-e38f-4654-a664-2b47398a3b44
md"""
## 1. Observe M67

Observe M67 either in Science Mode or Enhanced vision mode and load the corresponding FITS file into this notebook. This target should be available in the catalog within the app. Below is a sample EV observation taken by an eVscope 2:
"""

# ╔═╡ 784cd02d-cd07-409a-a6be-738ab091cea5
@bind reset_M67 Button("Reset")

# ╔═╡ 0a38efe9-c833-49b3-885d-d406d47cdf3b
begin
reset_M67
md"""
!!! note "Load your own data"
	Select "Browse" below you would like to visualize your own data before moving on with the rest of this notebook:
	
	$(@bind img_M67_local FilePicker([MIME("image/fits")]))
"""
end

# ╔═╡ c7b42a87-c84c-4c88-aa8f-c8f4d688c23a
md"""
## 2. Upload FITS file to Astrometry.net

Next, we upload our FITS file to [Astrometry.net](https://nova.astrometry.net/upload). This is a handy service for performing plate solving (converting from pixel space to RA and Dec) and photometry routines on our image.

After clicking on the link above, you should see an upload page like this:

![](https://github.com/Unistellar-science/SETI-Education/blob/main/src/asp_workshop/assets/M67/astrometry-net_upload_page.png?raw=true)

About 30 seconds - 1 minute after uploading our data following the instruction above, we should see a success page like the following:

![](https://github.com/Unistellar-science/SETI-Education/blob/main/src/asp_workshop/assets/M67/astrometry-net_success_page.png?raw=true)

Clicking "Go to results page" should then show the following:

![](https://github.com/Unistellar-science/SETI-Education/blob/main/src/asp_workshop/assets/M67/astrometry-net_results_page.png?raw=true)

There are a variety of different calibration products that we can download. For our purposes, we will just need the `image-radec.fits` file shown in the box above. We click on this link to save the file into the same directory as this notebook. Once complete, we load this new file, which should look similar to the table below:
"""

# ╔═╡ b3d75f94-55f3-44fa-b3a2-d0fb84d4e6da
md"""
This FITS file is a table of photometric measurements made by Astrometry.net, including the RA (`ra`), Dec (`dec`), and aperture flux (`flux`) of each source identified in our image. We will next combine this information with data from the [Gaia mission](https://www.esa.int/Science_Exploration/Space_Science/Gaia) to produce our CMD.
"""

# ╔═╡ a6c8a4d9-6104-4631-95a3-2a5652fae604
@bind reset_M67_phot_local Button("Reset")

# ╔═╡ 35be24e5-8d6c-418f-8144-eb8c0db2b19a
begin
reset_M67_phot_local
md"""
!!! note "Load your own data"
	Select "Browse" below you would like to visualize your own data before moving on with the rest of this notebook:
	
	$(@bind img_M67_phot_local FilePicker([MIME("image/fits")]))
"""
end

# ╔═╡ 93de8b0b-416f-440d-842a-811e488ed2a7
md"""
## 3. Load Gaia data

Since its launch in 2013, this flagship satellite from the ESA observed nearly two billion celestial objects over its 11 year mission duration. This has lead to a vast catalog of stellar flux measurements that we can then use to supply the x-axis of our CMD (the "red" and "blue" measurements that provide stellar color/temperature information). We start by loading in up to 2500 Gaia observation in a 30 arcminute radius (our rough field of view) around M67:
"""

# ╔═╡ 3ca7cfef-c070-4c6f-92e1-bd4176ee9562
md"""
!!! note
	To query Gaia data for your own target, change the name supplied in the quotes above. If no results are returned, try double checking the name [on Simbad](https://simbad.u-strasbg.fr/simbad/sim-id?Ident=M67&NbIdent=1&Radius=2&Radius.unit=arcmin&submit=submit+id).
"""

# ╔═╡ 9781946b-259b-4d75-8aee-47537ce2c569
coords_simbad(name) = let
    coords = execute(TAPService(:simbad), """
	SELECT basic.ra, basic.dec
	FROM ident JOIN basic ON ident.oidref = basic.oid
	WHERE id = '$(name)';
	""")
	return first.((coords.ra, coords.dec))
end

# ╔═╡ fe74d128-cb80-4a0f-8af2-b3e60d21ef51
query_gaia(name) = let
	ra, dec = coords_simbad(name)
	df = execute(TAPService(:gaia), """
	    SELECT TOP 2500
	        gs.source_id,
	        gs.ra,
	        gs.dec,
	        gs.phot_g_mean_mag,
	        gs.bp_rp,
	        gs.parallax,
	        gs.pmra,
	        gs.pmdec,
	        gs.ruwe,
	        DISTANCE(POINT(gs.ra, gs.dec), POINT($(ra), $(dec))) * 60 AS sep_arcmin
	    FROM
	        gaiadr3.gaia_source AS gs
	    WHERE
	        CONTAINS(
	            POINT(gs.ra, gs.dec),
	            CIRCLE($(ra), $(dec), 0.5)
	        ) = 1
	""") |> DataFrame

	@rtransform! df :coords = ICRSCoords(deg2rad(:ra), deg2rad(:dec))
end

# df_gaia = let
# 	df = CSV.read(download("https://raw.githubusercontent.com/Unistellar-science/SETI-Education/refs/heads/main/src/asp_workshop/assets/M67/gaia_dr3.csv"), DataFrame)
# 	@rtransform! df :coords = ICRSCoords(deg2rad(:ra), deg2rad(:dec))
# end

# ╔═╡ f8127edf-adf1-4305-8cdc-267fc746b874
df_gaia = query_gaia("M 67")

# ╔═╡ 58659a40-d37f-46ee-87ce-25bb3a8acca7
md"""
## 4. Cross-match

Next, we match all entries in the table above to our table from Astrometry.net, where a match is considered to be any object within 2 arcseconds of each other. For various reasons, the coordinates estimated in our image will not always satifsy this constraint, so the total number of cross-matched sources will be fewer:
"""

# ╔═╡ 00413909-645e-4207-8f29-d1caa278ccc4
md"""
## 5. Filter membership
"""

# ╔═╡ a6db9de8-1ee3-4b4e-9034-09aa43e3d972
cm"""
Finally, we only select for sources with similar parallax and proper motion to each other. Plotting our measured eVscope fluxes against the difference in the associated flux between Gaia's "blue" and "red" filters (G<sub>BP</sub> and G<sub>RP</sub>, respectively) then forms the CMD for our cluster.

Use the sliders below to explore how different cut-offs for the parallax and proper motion affect the plot:
"""

# ╔═╡ ccbb091b-19c2-4bfb-9e04-4f77f395fdba
@bind reset_cmd Button("Reset")

# ╔═╡ ecec680f-5536-4798-861f-6f0945e6c175
begin
reset_cmd

@bind cmd_cuts PlutoUI.combine() do Child
	cm"""
	| Parallax <br> (mas) | RA proper motion <br> (mas/yr) | Dec proper motion <br> (mas/yr) |
	| :-: | :-: | :-: |
	| $(Child("plx", RangeSlider(-5:10))) | $(Child("pmra", RangeSlider(-36:24))) | $(Child("pmdec", RangeSlider(-60:12))) |
	"""
	end
end

# ╔═╡ 73335835-def4-4a1c-a6fa-61158f445dcb
md"""
Scroll over the reference image below to see how close your guesses were to the reported values for this cluster.
"""

# ╔═╡ 72ddeeae-4cb0-4268-bbe8-c60f5be6bdb2
md"""
Try this with your own data following the steps above!
"""

# ╔═╡ d5ac78a4-70c3-4a35-95c1-1d58f403facd
md"""
# Notebook setup
"""

# ╔═╡ e4b279ba-bbe5-4c1c-a346-ab70a1b61cc6
PlutoUI.TableOfContents()

# ╔═╡ 0468013d-5283-4b48-8729-e833b3d2f8f8
md"""
## Helper functions
"""

# ╔═╡ 2b52be49-eb95-4d11-adc4-c0b64a818872
function tiny(img)
	imgv = copy(img)
	
	while length(eachindex(imgv)) > 10^6
		imgv = AstroImages.restrict(imgv)
	end

	return imgv
end;

# ╔═╡ 1d81674b-67f5-4c9c-a351-b2fda419aba3
# Julia photometry aperture object --> plotly shape object
function circ(ap, r=ap.r; line_color=:lightgreen)
	circle(
		ap.x - r, # x_min
		ap.x + r, # x_max
		ap.y - r, # y_min
		ap.y + r; # y_max
		line_color,
	)
end;

# ╔═╡ 4a2e1f66-d637-476f-8f80-e5c46798e4bd
# Plotly heatmap trace of img
function htrace(img;
	zlims,
	title = "ADU",
	restrict = true,
)
		
	# Account for plotly orientation convention
	img = permutedims(img)
	
	# dims is used here to convert back from an offset array
	# to a simple array that JS can ingest
	zmin, zmax = zlims
	
	heatmap(;
		x = dims(img, X).val,
		y = dims(img, Y).val,
		z = Matrix{Float32}(img.data),
		zmin,
		zmax,
		colorbar = attr(; title),
		colorscale = "Cividis",
	)
end;

# ╔═╡ f70883db-74cb-485e-a426-f334dce178b2
# Combines plotly trace and layout into a plot object
function plot_img(img; zlims=Percent(99.5)(img), restrict = true)
	imgv = (tiny ∘ AstroImage)(img)
	# imgv = img
	
	hm = htrace(imgv; zlims, restrict)
	
	l = Layout(;
		# width,
		# height,
		# title = timestamp(img),
		xaxis = attr(title = "X", constrain = "domain"),
		yaxis = attr(title = "Y", scaleanchor = "x", constrain = "domain"),
		uirevision = 1,
	)

	plot(hm, l)
end;

# ╔═╡ e24420c8-2c85-468a-92df-814ba619e575
# Default from FilePicker
load_img(data::Nothing) = (load ∘ download)("https://github.com/Unistellar-science/SETI-Education/raw/refs/heads/main/src/asp_workshop/assets/M67/20260303T060902_911_StackInput.fits")

# ╔═╡ db733129-28e0-49e0-811f-f38f670fda38
function load_img(data)
	path = tempname() * data["name"]
	write(path, data["data"])
	load(path)
end

# ╔═╡ e15a8d41-41b8-4f55-b364-9586dc729bc3
img_M67 = load_img(img_M67_local);

# ╔═╡ ea3dd7a0-7ecc-4063-8a3e-0e46a470f80c
plot_img(img_M67)

# ╔═╡ fa0d3f2f-3ce2-4e19-bb8e-874bdd7028bc
# Default from FilePicker
function load_phot(data::Nothing)
	df = load(
		download(
			"https://github.com/Unistellar-science/SETI-Education/raw/refs/heads/main/src/asp_workshop/assets/M67/image-radec_stacked.fits"
		),
	2) |> DataFrame
	@transform! df :coords = ICRSCoords.(deg2rad.(:ra), deg2rad.(:dec))
end

# ╔═╡ a877a885-d771-407d-9a29-d13f384c4ae5
function load_phot(data)
	path = tempname() * data["name"]
	write(path, data["data"])
	df = load(path, 2) |> DataFrame
	@transform! df :coords = ICRSCoords.(deg2rad.(:ra), deg2rad.(:dec))
end

# ╔═╡ 2a2e0c2e-7397-4255-98c1-267b93ed4e55
df_phot = load_phot(img_M67_phot_local);

# ╔═╡ 0c7649a7-da58-4d40-8b4b-bc724c56407c
df_phot

# ╔═╡ b1c2555a-39aa-4ba1-8203-da85b6221c96
df_matched = let
	df = innerjoin((df_phot, df_gaia), by_distance(
		:coords,
		SkyCoords.separation,
		≤(2u"arcsecond"))
	)
	dropmissing!(df, [:parallax, :pmra, :pmdec, :ruwe])
end

# df_matched = let
# 	ids, sep = SkyCoords.match(df_gaia.coords, df_phot.coords)
# 	df = hcat(df_phot, df_gaia[ids, :]; makeunique = true)
# 	df.arcsec_diff_coords = @. rad2deg(sep) * 3600.0
# 	@rsubset! df :arcsec_diff_coords < 2.0
# 	dropmissing!(df, [:parallax, :pmra, :pmdec, :ruwe])
# 	df
# end

# ╔═╡ f3d465f2-1b09-4c24-985a-9696d13699b2
df_ans = @chain df_matched begin
	@rsubset begin
		0.5 ≤ :parallax
		:parallax ≤ 1.7
		
		-12 ≤ :pmra
		:pmra ≤ -10
		
		-4 ≤ :pmdec
		:pmdec ≤ -2
	
		:ruwe ≤ 1.4 # Hard-coded quality indicator
	end
end;

# ╔═╡ 17de112e-91a8-4b55-93da-cecd0d9ca89f
cm"""
!!! hint "Comparison to Gaia"

	$(plot(
		scatter(;
			x = df_ans.:var"bp_rp",
			y = df_ans.phot_g_mean_mag,
			mode = :markers,
		),
		Layout(;
			xaxis_title = "G<sub>BP</sub> - G<sub>RP</sub>",
			xaxis_range = [0, 2],
			xaxis_autorange = false,
			yaxis_title = "G",
			yaxis_range = [16, 8],
			yaxis_autorange = :reverse,
			title = "M67 Color Magnitude Diagram -- Gaia DR3",
			uirevision = 1,
		),
	))

	**Parallax** ≈ 1.1 mas | **RA proper motion** ≈ -11.0 mas/yr | **Dec Proper motion** ≈ -3.0 mas/yr
"""

# ╔═╡ 1ad86cd6-415e-432a-adec-366cb9a54bba
df_cluster = @chain df_matched begin
	@rsubset begin
		first(cmd_cuts.plx) ≤ :parallax
		:parallax ≤ last(cmd_cuts.plx)
		
		first(cmd_cuts.pmra) ≤ :pmra
		:pmra ≤ last(cmd_cuts.pmra)
		
		first(cmd_cuts.pmdec) ≤ :pmdec
		:pmdec ≤ last(cmd_cuts.pmdec)
	
		:ruwe ≤ 1.4 # Hard-coded quality indicator
	end
end;

# ╔═╡ f37c9963-ed1b-4784-a0df-3745bcadd1b1
plot(
	scatter(; x = df_cluster.bp_rp, y = log10.(df_cluster.flux), mode = :markers),
	Layout(;
		xaxis_title = "G<sub>BP</sub> - G<sub>RP</sub> (Gaia DR3)",
		xaxis_range = [0, 2],
		xaxis_autorange = false,
		yaxis_title = "log F (Unistellar)",
		yaxis_range = [2.5, 5],
		yaxis_autorange = false,
		title = "M67 Color Magnitude Diagram -- N: $(nrow(df_cluster))",
		uirevision = 1,
	),
)

# ╔═╡ edb99047-cdea-4149-ab67-640ddbd7aec5
let
	p = plot_img(img_M67)

	aps = CircularAperture.(df_cluster.x, df_cluster.y, 20)
	
	shapes = [circ(ap) for ap in aps]
	
	relayout!(p; shapes, title = "Sources selected")

	p
end

# ╔═╡ b2a5ce6c-34fd-4d50-92d0-5d35df4447af
md"""
## Packages
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AstroImages = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
ColorTypes = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
CommonMark = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
DataFramesMeta = "1313f7d8-7da2-5740-9ea0-a2ca25f37964"
FlexiJoins = "e37f2e79-19fa-4eb7-8510-b63b51fe0a37"
Photometry = "af68cb61-81ac-52ed-8703-edc140936be4"
PlutoPlotly = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
SkyCoords = "fc659fc5-75a3-5475-a2ea-3da92c065361"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"
UnitfulAstro = "6112ee07-acf9-5e0f-b108-d242c714bf9f"
VirtualObservatory = "d7ce213e-d3b9-4ed1-b00e-1146b7ac83e0"

[compat]
AstroImages = "~0.5.1"
CSV = "~0.10.16"
ColorTypes = "~0.12.1"
CommonMark = "~1.0.1"
DataFramesMeta = "~0.15.6"
FlexiJoins = "~0.1.38"
Photometry = "~0.9.6"
PlutoPlotly = "~0.6.5"
PlutoUI = "~0.7.80"
SkyCoords = "~1.7.0"
Unitful = "~1.28.0"
UnitfulAstro = "~1.2.2"
VirtualObservatory = "~0.1.14"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "8082d32936d56fe782026937bec29908d7b2d3bc"

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
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

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

[[deps.AccessorsExtra]]
deps = ["Accessors", "CompositionsBase", "ConstructionBase", "DataPipes", "InverseFunctions", "LinearAlgebra", "Reexport"]
git-tree-sha1 = "5c6d50ec5b3a3fc2e87d0ce26b934fb87ec4d41b"
uuid = "33016aad-b69d-45be-9359-82a41f556fd4"
version = "0.1.102"

    [deps.AccessorsExtra.extensions]
    ColorTypesExt = "ColorTypes"
    DateFormatsExt = "DateFormats"
    DatesExt = "Dates"
    DictArraysExt = "DictArrays"
    DictionariesExt = "Dictionaries"
    DistributionsExt = "Distributions"
    DomainSetsExt = "DomainSets"
    FlexiGroupsExt = "FlexiGroups"
    FlexiMapsExt = "FlexiMaps"
    FlexiMapsStructArraysExt = ["FlexiMaps", "StructArrays"]
    MakieExt = "Makie"
    SkipperExt = "Skipper"
    StaticArraysExt = "StaticArrays"
    StatisticsExt = "Statistics"
    StatsBaseExt = "StatsBase"
    StructArraysExt = "StructArrays"
    TablesExt = "Tables"
    TestExt = "Test"
    URIsExt = "URIs"
    UnitfulExt = "Unitful"

    [deps.AccessorsExtra.weakdeps]
    ColorTypes = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
    DateFormats = "44557152-fe0a-4de1-8405-416d90313ce6"
    Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
    DictArrays = "e9958f2c-b184-4647-9c5a-224a61f6a14b"
    Dictionaries = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
    Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
    DomainSets = "5b8099bc-c8ec-5219-889f-1d9e522a28bf"
    FlexiGroups = "1e56b746-2900-429a-8028-5ec1f00612ec"
    FlexiMaps = "6394faf6-06db-4fa8-b750-35ccc60383f7"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    Skipper = "fc65d762-6112-4b1c-b428-ad0792653d81"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
    StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    URIs = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "0761717147821d696c9470a7a86364b2fbd22fd8"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.5.2"
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
git-tree-sha1 = "54f895554d05c83e3dd59f6a396671dae8999573"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.24.0"

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

[[deps.ArraysOfArrays]]
deps = ["Statistics"]
git-tree-sha1 = "8e64c97ac7bffbd3327d8ddadf8dad26b87a2664"
uuid = "65a8f2f4-9b39-5baf-92e2-a9cc46fdf018"
version = "0.6.6"
weakdeps = ["Adapt", "ChainRulesCore", "StaticArraysCore"]

    [deps.ArraysOfArrays.extensions]
    ArraysOfArraysAdaptExt = "Adapt"
    ArraysOfArraysChainRulesCoreExt = "ChainRulesCore"
    ArraysOfArraysStaticArraysCoreExt = "StaticArraysCore"

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

[[deps.BangBang]]
deps = ["Accessors", "ConstructionBase", "InitialValues", "LinearAlgebra"]
git-tree-sha1 = "cceb62468025be98d42a5dc581b163c20896b040"
uuid = "198e06fe-97b7-11e9-32a5-e1d131e6ad66"
version = "0.4.9"
weakdeps = ["ChainRulesCore", "DataFrames", "StaticArrays", "StructArrays", "Tables", "TypedTables"]

    [deps.BangBang.extensions]
    BangBangChainRulesCoreExt = "ChainRulesCore"
    BangBangDataFramesExt = "DataFrames"
    BangBangStaticArraysExt = "StaticArrays"
    BangBangStructArraysExt = "StructArrays"
    BangBangTablesExt = "Tables"
    BangBangTypedTablesExt = "TypedTables"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

[[deps.Baselet]]
git-tree-sha1 = "aebf55e6d7795e02ca500a689d326ac979aaf89e"
uuid = "9718e550-a3fa-408a-8086-8db961cd8217"
version = "0.1.1"

[[deps.BenchmarkTools]]
deps = ["Compat", "JSON", "Logging", "PrecompileTools", "Printf", "Profile", "Statistics", "UUIDs"]
git-tree-sha1 = "9670d3febc2b6da60a0ae57846ba74670290653f"
uuid = "6e4b80f9-dd63-53aa-95a3-0cdb28fa8baf"
version = "1.8.0"

[[deps.BitFlags]]
git-tree-sha1 = "0691e34b3bb8be9307330f88d1a3c3f25466c24d"
uuid = "d1d4a3ce-64b1-5f1a-9ba4-7e7e69966f35"
version = "0.1.9"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "1b96ea4a01afe0ea4090c5c8039690672dd13f2e"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.9+0"

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
git-tree-sha1 = "98810ce932373ec43ef72cd4ae373640808a79c3"
uuid = "b3e40c51-02ae-5482-8a39-3ace5868dcf4"
version = "4.6.3+0"

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

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "PrecompileTools", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "8d8e0b0f350b8e1c91420b5e64e5de774c2f0f4d"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.16"

[[deps.CURL_jll]]
deps = ["Artifacts", "JLLWrappers", "LibCURL_jll", "LibSSH2_jll", "Libdl", "OpenSSL_jll", "Zlib_jll", "nghttp2_jll"]
git-tree-sha1 = "574b2e28b5b72d04383bbcd522f8fc70572f2d92"
uuid = "b21e61f3-bafc-59ac-ab14-4c5c62d6588d"
version = "8.14.1+0"

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
git-tree-sha1 = "019ad9e55bb3549403f2d5a9b314fbb29a806ecb"
uuid = "a80b9123-70ca-4bc0-993e-6e3bcb318db6"
version = "1.0.1"

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

[[deps.ConcurrentUtilities]]
deps = ["Serialization", "Sockets"]
git-tree-sha1 = "21d088c496ea22914fe80906eb5bce65755e5ec8"
uuid = "f0e56b4a-5159-44fe-b623-3e5288b988bb"
version = "2.5.1"

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

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.CustomUnitRanges]]
git-tree-sha1 = "1a3f97f907e6dd8983b744d2642651bb162a3f7a"
uuid = "dc8bdbbb-1ca9-579f-8c36-e416f6a65cce"
version = "1.0.2"

[[deps.DBInterface]]
git-tree-sha1 = "a444404b3f94deaa43ca2a58e18153a82695282b"
uuid = "a10d1c49-ce27-4219-8d33-6db1a4562965"
version = "2.6.1"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

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

[[deps.DataPipes]]
git-tree-sha1 = "3fb39158bc35c984cac5edb1ff55daa88a4b5074"
uuid = "02685ad9-2d12-40c3-9f73-c6aeda6a7ff5"
version = "0.3.19"

[[deps.DataStructures]]
deps = ["OrderedCollections"]
git-tree-sha1 = "e86f4a2805f7f19bec5129bc9150c38208e5dc23"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.19.4"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.DateFormats]]
deps = ["Dates", "Reexport"]
git-tree-sha1 = "a73965314cb45f0ac9cc617267cb3f1d4f617742"
uuid = "44557152-fe0a-4de1-8405-416d90313ce6"
version = "0.1.20"

    [deps.DateFormats.extensions]
    AccessorsExt = "Accessors"
    IntervalSetsExt = "IntervalSets"
    InverseFunctionsExt = "InverseFunctions"
    StatisticsExt = "Statistics"
    TimeZonesExt = "TimeZones"

    [deps.DateFormats.weakdeps]
    Accessors = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    InverseFunctions = "3587e190-3f89-42d0-90ee-14403ec27112"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
    TimeZones = "f269a46b-ccf7-5d73-abea-4c690281aa53"

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
git-tree-sha1 = "23163d55f885173722d1e4cf0f6110cdbaf7e272"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.15.1"

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

[[deps.EnumX]]
git-tree-sha1 = "c49898e8438c828577f04b92fc9368c388ac783c"
uuid = "4e289a0a-7415-4d19-859d-a7e5c4648b56"
version = "1.0.7"

[[deps.ErrorfreeArithmetic]]
git-tree-sha1 = "d6863c556f1142a061532e79f611aa46be201686"
uuid = "90fa49ef-747e-5e6f-a989-263ba693cf1a"
version = "0.5.2"

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

[[deps.EzXML]]
deps = ["Printf", "XML2_jll"]
git-tree-sha1 = "7ea1aa5869e2626ccae84480e4f37185bc6f41d3"
uuid = "8f5d6c58-4d21-5cfd-889c-e3ad7ee6a615"
version = "1.2.3"

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
git-tree-sha1 = "6d6219a004b8cf1e0b4dbe27a2860b8e04eba0be"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.11+0"

[[deps.FITSIO]]
deps = ["CFITSIO", "Printf", "Reexport", "Tables"]
git-tree-sha1 = "f57de3f533590c785210893030736dc11c4a4afb"
uuid = "525bcba6-941b-5504-bd06-fd0dc1a4d2eb"
version = "0.17.5"

[[deps.FastRounding]]
deps = ["ErrorfreeArithmetic", "LinearAlgebra"]
git-tree-sha1 = "6344aa18f654196be82e62816935225b3b9abe44"
uuid = "fa42c844-2597-5d31-933b-ebd51ab2693f"
version = "0.3.1"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "6522cfb3b8fe97bec632252263057996cbd3de20"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.18.0"
weakdeps = ["HTTP"]

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates"]
git-tree-sha1 = "3bab2c5aa25e7840a4b065805c0cdfc01f3068d2"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.24"
weakdeps = ["Mmap", "Test"]

    [deps.FilePathsBase.extensions]
    FilePathsBaseMmapExt = "Mmap"
    FilePathsBaseTestExt = "Test"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.FlexiJoins]]
deps = ["Accessors", "ArraysOfArrays", "DataAPI", "DataPipes", "FlexiMaps", "IntervalSets", "NearestNeighbors", "SentinelViews", "StaticArrays", "StructArrays"]
git-tree-sha1 = "639e640c9985d9aeb1f1c8332aa2b9348b89b668"
uuid = "e37f2e79-19fa-4eb7-8510-b63b51fe0a37"
version = "0.1.38"
weakdeps = ["DataFrames", "SkyCoords"]

    [deps.FlexiJoins.extensions]
    DataFramesExt = "DataFrames"
    SkyCoordsExt = "SkyCoords"

[[deps.FlexiMaps]]
deps = ["Accessors", "DataPipes", "InverseFunctions"]
git-tree-sha1 = "c2e79264c5e749d099d7ae854f64ec73f2f9e3e9"
uuid = "6394faf6-06db-4fa8-b750-35ccc60383f7"
version = "0.1.29"

    [deps.FlexiMaps.extensions]
    AxisKeysExt = "AxisKeys"
    DictionariesExt = "Dictionaries"
    IntervalSetsExt = "IntervalSets"
    StructArraysExt = "StructArrays"
    UnitfulExt = "Unitful"

    [deps.FlexiMaps.weakdeps]
    AxisKeys = "94b1ba4f-4ee9-5380-92f1-94cde586c3c5"
    Dictionaries = "85a47980-9c8c-11e8-2b9f-f7ca1fa99fb4"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    StructArrays = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions"]
git-tree-sha1 = "cddeab6487248a39dae1a960fff0ac17b2a28888"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "1.3.3"
weakdeps = ["StaticArrays"]

    [deps.ForwardDiff.extensions]
    ForwardDiffStaticArraysExt = "StaticArrays"

[[deps.FunSQL]]
deps = ["DBInterface", "DataAPI", "Dates", "LRUCache", "OrderedCollections", "PrettyPrinting", "Tables"]
git-tree-sha1 = "0d9b304dd53fae993db7e9885d8176f38b30236a"
uuid = "cf6cc811-59f4-4a10-b258-a8547a8f6407"
version = "0.15.0"

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
git-tree-sha1 = "7134810b1afce04bbc1045ca1985fbe81ce17653"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.5"

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
deps = ["CRlibm", "EnumX", "FastRounding", "LinearAlgebra", "Markdown", "Random", "RecipesBase", "RoundingEmulator", "SetRounding", "StaticArrays"]
git-tree-sha1 = "f59e639916283c1d2e106d2b00910b50f4dab76c"
uuid = "d1acc4aa-44c8-5952-acd4-ba5d80a2a253"
version = "0.21.2"

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
git-tree-sha1 = "0533e564aae234aff59ab625543145446d8b6ec2"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.7.1"

[[deps.JSON]]
deps = ["Dates", "Logging", "Parsers", "PrecompileTools", "StructUtils", "UUIDs", "Unicode"]
git-tree-sha1 = "67c6f1f085cb2671c93fe34244c9cccde30f7a26"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "1.5.0"

    [deps.JSON.extensions]
    JSONArrowExt = ["ArrowTypes"]

    [deps.JSON.weakdeps]
    ArrowTypes = "31f734f8-188a-4ce0-8406-c8a06bd891cd"

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
git-tree-sha1 = "4091a1338a0e32766b11b9bd3fac247d34200c77"
uuid = "4076af6c-e467-56ae-b986-b466b2749572"
version = "1.30.0"
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

[[deps.LRUCache]]
git-tree-sha1 = "5519b95a490ff5fe629c4a7aa3b3dfc9160498b3"
uuid = "8ac3fa9e-de4c-5943-b1dc-09c6b5f20637"
version = "1.6.2"
weakdeps = ["Serialization"]

    [deps.LRUCache.extensions]
    SerializationExt = ["Serialization"]

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
git-tree-sha1 = "0661819a2857cb1a8d6712d96e3ba5647c32cc8e"
uuid = "b4f0291d-fe17-52bc-9479-3d1a343d9043"
version = "5.3.0"

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

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "be484f5c92fad0bd8acfef35fe017900b0b73809"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.18.0+0"

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
deps = ["BenchmarkTools", "CodecBzip2", "CodecZlib", "ForwardDiff", "JSON", "LinearAlgebra", "MutableArithmetics", "NaNMath", "OrderedCollections", "PrecompileTools", "Printf", "SparseArrays", "SpecialFunctions", "Test"]
git-tree-sha1 = "ce739e3d8a21313ea418772edfc3b7b15a1dfc16"
uuid = "b8f27783-ece8-5eb3-8dc8-9495eed66fee"
version = "1.50.1"

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

[[deps.MetadataArrays]]
git-tree-sha1 = "fea53b6812f0fd3b12041f2652fbd214e36605bf"
uuid = "49441bc9-da82-574f-b07c-a0d10dd4ac13"
version = "0.1.1"

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
git-tree-sha1 = "7c25249fc13a070f5ba433c50e21e22bb33c6fb0"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.7.1"

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
git-tree-sha1 = "9ac7c730c53b3b5d9a73fb900ac4b4fc263774db"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.4.9+0"

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
git-tree-sha1 = "05868e21324cede2207c6f0f466b4bfef6d5e7ee"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.8.1"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "cf181f0b1e6a18dfeb0ee8acc4a9d1672499626c"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.4.4"

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
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.Photometry]]
deps = ["ImageFiltering", "ImageTransformations", "Interpolations", "LazySets", "NearestNeighbors", "Parameters", "RecipesBase", "Reexport", "Rotations", "StaticArrays", "Statistics", "StatsBase", "Transducers", "TypedTables"]
git-tree-sha1 = "7ef9827b25d13d64b2b88952223d6eedfa9fcf43"
uuid = "af68cb61-81ac-52ed-8703-edc140936be4"
version = "0.9.6"

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
git-tree-sha1 = "8acd04abc9a636ef57004f4c2e6f3f6ed4611099"
uuid = "8e989ff0-3d88-8e9f-f020-2b208a939ff0"
version = "0.6.5"

    [deps.PlutoPlotly.extensions]
    PlotlyKaleidoExt = "PlotlyKaleido"
    UnitfulExt = "Unitful"

    [deps.PlutoPlotly.weakdeps]
    PlotlyKaleido = "f2990250-8cf9-495f-b13a-cce12b45703c"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "fbc875044d82c113a9dee6fc14e16cf01fd48872"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.80"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "36d8b4b899628fb92c2749eb488d884a926614d3"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.3"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "07a921781cab75691315adc645096ed5e370cb77"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.3.3"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "8b770b60760d4451834fe79dd483e318eee709c4"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.5.2"

[[deps.PrettyPrinting]]
git-tree-sha1 = "142ee93724a9c5d04d78df7006670a93ed1b244e"
uuid = "54e16d92-306c-5ea0-a30b-337be88ac337"
version = "0.4.2"

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

[[deps.Profile]]
deps = ["StyledStrings"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"
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

[[deps.SQLCollections]]
deps = ["AccessorsExtra", "DBInterface", "DataPipes", "Dictionaries", "FunSQL", "Printf", "StructArrays", "Tables"]
git-tree-sha1 = "636e9229e5fb72e7c1fc53d097c891b885d813a0"
uuid = "3934435e-e6e6-4fea-a5c0-3a716143d619"
version = "0.1.15"

    [deps.SQLCollections.extensions]
    DataManipulationExt = "DataManipulation"
    DatesExt = "Dates"
    DuckDBExt = "DuckDB"
    FlexiGroupsExt = "FlexiGroups"
    FlexiMapsExt = "FlexiMaps"
    IntervalSetsExt = "IntervalSets"
    SQLiteExt = "SQLite"
    StatisticsExt = "Statistics"

    [deps.SQLCollections.weakdeps]
    DataManipulation = "38052440-ad76-4236-8414-61389b2c5143"
    Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
    DuckDB = "d2f5444f-75bc-4fdf-ac35-56f514c445e1"
    FlexiGroups = "1e56b746-2900-429a-8028-5ec1f00612ec"
    FlexiMaps = "6394faf6-06db-4fa8-b750-35ccc60383f7"
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    SQLite = "0aa819cd-b072-5ff4-a722-6bc24af294d9"
    Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.SQLite]]
deps = ["DBInterface", "Random", "SQLite_jll", "Serialization", "Tables", "WeakRefStrings"]
git-tree-sha1 = "87b47a05946c50f44531b447b1f24968345316a4"
uuid = "0aa819cd-b072-5ff4-a722-6bc24af294d9"
version = "1.8.0"

[[deps.SQLite_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll", "dlfcn_win32_jll"]
git-tree-sha1 = "0b5f220f90642566b65ba86549d1ee4118ab2579"
uuid = "76ed43ae-9a5d-5a62-8c75-30186b810ce8"
version = "3.51.2+0"

[[deps.SciMLPublic]]
git-tree-sha1 = "0ba076dbdce87ba230fff48ca9bca62e1f345c9b"
uuid = "431bcebd-1456-4ced-9d72-93c2757fff0b"
version = "1.0.1"

[[deps.ScopedValues]]
deps = ["HashArrayMappedTries", "Logging"]
git-tree-sha1 = "ac4b837d89a58c848e85e698e2a2514e9d59d8f6"
uuid = "7e506255-f358-4e82-b7e4-beb19740aa63"
version = "1.6.0"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "9b81b8393e50b7d4e6d0a9f14e192294d3b7c109"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.3.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "ebe7e59b37c400f694f52b58c93d26201387da70"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.4.9"

[[deps.SentinelViews]]
git-tree-sha1 = "e1654cb20273458138262e24d5f5572179013913"
uuid = "1c95a9c1-8e3f-460f-8963-106dcc440218"
version = "0.1.4"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.SetRounding]]
git-tree-sha1 = "d7a25e439d07a17b7cdf97eecee504c50fedf5f6"
uuid = "3cc68bcd-71a2-5612-b932-767ffbe40ab0"
version = "0.2.1"

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
git-tree-sha1 = "be8eeac05ec97d379347584fa9fe2f5f76795bcb"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.5"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "0494aed9501e7fb65daba895fb7fd57cc38bc743"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.5"

[[deps.SkyCoords]]
deps = ["ConstructionBase", "LinearAlgebra", "Rotations", "StaticArrays"]
git-tree-sha1 = "a3411c6dc0bddec83ce7786e77ebed47989a9d99"
uuid = "fc659fc5-75a3-5475-a2ea-3da92c065361"
version = "1.7.0"

    [deps.SkyCoords.extensions]
    AccessorsExt = "Accessors"
    MakieExt = "Makie"
    NearestNeighborsExt = "NearestNeighbors"
    UnitfulExt = "Unitful"

    [deps.SkyCoords.weakdeps]
    Accessors = "7d9f7c33-5ae7-4f3b-8dc6-eff91059b697"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    NearestNeighbors = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

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
git-tree-sha1 = "2700b235561b0335d5bef7097a111dc513b8655e"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.7.2"
weakdeps = ["ChainRulesCore"]

    [deps.SpecialFunctions.extensions]
    SpecialFunctionsChainRulesCoreExt = "ChainRulesCore"

[[deps.SplitApplyCombine]]
deps = ["Dictionaries", "Indexing"]
git-tree-sha1 = "c06d695d51cfb2187e6848e98d6252df9101c588"
uuid = "03a91e81-4c3e-53e1-a0a4-9c0c8f19dd66"
version = "1.2.3"

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
git-tree-sha1 = "49440414711eddc7227724ae6e570c7d5559a086"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "1.3.1"

[[deps.StaticArrayInterface]]
deps = ["ArrayInterface", "Compat", "IfElse", "LinearAlgebra", "PrecompileTools", "SciMLPublic", "Static"]
git-tree-sha1 = "aa1ea41b3d45ac449d10477f65e2b40e3197a0d2"
uuid = "0d7ed370-da01-4f52-bd93-41d350b8b718"
version = "1.9.0"
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
git-tree-sha1 = "aceda6f4e598d331548e04cc6b2124a6148138e3"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.34.10"

[[deps.StringManipulation]]
deps = ["PrecompileTools"]
git-tree-sha1 = "d05693d339e37d6ab134c5ab53c29fce5ee5d7d5"
uuid = "892a3eda-7b42-436c-8928-eab12a02cf0e"
version = "0.4.4"

[[deps.StringViews]]
git-tree-sha1 = "f2dcb92855b31ad92fe8f079d4f75ac57c93e4b8"
uuid = "354b36f9-a18e-4713-926e-db85100087ba"
version = "1.3.7"

[[deps.StructArrays]]
deps = ["ConstructionBase", "DataAPI", "Tables"]
git-tree-sha1 = "ad8002667372439f2e3611cfd14097e03fa4bccd"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.7.3"

    [deps.StructArrays.extensions]
    StructArraysAdaptExt = "Adapt"
    StructArraysGPUArraysCoreExt = ["GPUArraysCore", "KernelAbstractions"]
    StructArraysLinearAlgebraExt = "LinearAlgebra"
    StructArraysSparseArraysExt = "SparseArrays"
    StructArraysStaticArraysExt = "StaticArrays"

    [deps.StructArrays.weakdeps]
    Adapt = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
    KernelAbstractions = "63c18a36-062a-441e-b654-da1e3ab1ce7c"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.StructUtils]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "aab80fbf866600f3299dd7f6656d80e7be177cfe"
uuid = "ec057cc2-7a8d-4b58-b3b3-92acb9f63b42"
version = "2.7.2"

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

[[deps.UnitfulAngles]]
deps = ["Dates", "Unitful"]
git-tree-sha1 = "79875b1f2e4bf918f0702a5980816955066d9ae2"
uuid = "6fb2a4bd-7999-5318-a3b2-8ad61056cd98"
version = "0.7.2"

[[deps.UnitfulAstro]]
deps = ["Unitful", "UnitfulAngles"]
git-tree-sha1 = "fbe44a0ade62ae5ed0240ad314dfdd5482b90b40"
uuid = "6112ee07-acf9-5e0f-b108-d242c714bf9f"
version = "1.2.2"

[[deps.UnsafeArrays]]
git-tree-sha1 = "c63023bd84f46f9df786c90180d4f79dbfdafa2a"
uuid = "c4a57d5a-5b31-53a6-b365-19f8c011fbd6"
version = "1.0.9"

[[deps.VOTables]]
deps = ["AccessorsExtra", "AstroAngles", "Base64", "DataAPI", "DataPipes", "DateFormats", "Dates", "Dictionaries", "EzXML", "MetadataArrays", "Mmap", "PrecompileTools", "StringViews", "StructArrays", "Tables", "UnsafeArrays"]
git-tree-sha1 = "6bb2ee7cb7673da330dca5d1815598097bf65e3b"
uuid = "3abbdab7-df67-4801-8590-8effec53f469"
version = "0.1.23"

    [deps.VOTables.extensions]
    DictArraysExt = "DictArrays"
    UnitfulExt = "Unitful"

    [deps.VOTables.weakdeps]
    DictArrays = "e9958f2c-b184-4647-9c5a-224a61f6a14b"
    Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"

[[deps.VirtualObservatory]]
deps = ["AccessorsExtra", "CSV", "CURL_jll", "DBInterface", "DataAPI", "DataPipes", "FlexiMaps", "HTTP", "SQLCollections", "SQLite", "Scratch", "StructArrays", "Tables", "URIs", "VOTables"]
git-tree-sha1 = "c51ad8c80e96f7d8395111789299d4b46c4b4f8a"
uuid = "d7ce213e-d3b9-4ed1-b00e-1146b7ac83e0"
version = "0.1.14"

    [deps.VirtualObservatory.extensions]
    DictArraysExt = ["DictArrays"]
    FlexiJoinsSkyCoordsExt = ["FlexiJoins", "SkyCoords"]

    [deps.VirtualObservatory.weakdeps]
    DictArrays = "e9958f2c-b184-4647-9c5a-224a61f6a14b"
    FlexiJoins = "e37f2e79-19fa-4eb7-8510-b63b51fe0a37"
    SkyCoords = "fc659fc5-75a3-5475-a2ea-3da92c065361"

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

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

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

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Zlib_jll"]
git-tree-sha1 = "5c959b708667b34cb758e8d7c6f8e69b94c32deb"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.15.1+0"

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

[[deps.dlfcn_win32_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "e141d67ffe550eadfb5af1bdbdaf138031e4805f"
uuid = "c4b69c83-5512-53e3-94e6-de98773c479f"
version = "1.4.2+0"

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
git-tree-sha1 = "1350188a69a6e46f799d3945beef36435ed7262f"
uuid = "1317d2d5-d96f-522e-a858-c73665f53c3e"
version = "2022.0.0+1"

[[deps.p7zip_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.7.0+0"
"""

# ╔═╡ Cell order:
# ╟─8616ef80-e4f2-4121-8463-f83e3594ac91
# ╟─9963a6fc-e38f-4654-a664-2b47398a3b44
# ╠═ea3dd7a0-7ecc-4063-8a3e-0e46a470f80c
# ╟─784cd02d-cd07-409a-a6be-738ab091cea5
# ╟─0a38efe9-c833-49b3-885d-d406d47cdf3b
# ╟─c7b42a87-c84c-4c88-aa8f-c8f4d688c23a
# ╠═0c7649a7-da58-4d40-8b4b-bc724c56407c
# ╟─b3d75f94-55f3-44fa-b3a2-d0fb84d4e6da
# ╟─35be24e5-8d6c-418f-8144-eb8c0db2b19a
# ╟─a6c8a4d9-6104-4631-95a3-2a5652fae604
# ╟─93de8b0b-416f-440d-842a-811e488ed2a7
# ╠═f8127edf-adf1-4305-8cdc-267fc746b874
# ╟─3ca7cfef-c070-4c6f-92e1-bd4176ee9562
# ╟─fe74d128-cb80-4a0f-8af2-b3e60d21ef51
# ╟─9781946b-259b-4d75-8aee-47537ce2c569
# ╟─58659a40-d37f-46ee-87ce-25bb3a8acca7
# ╟─b1c2555a-39aa-4ba1-8203-da85b6221c96
# ╟─00413909-645e-4207-8f29-d1caa278ccc4
# ╟─a6db9de8-1ee3-4b4e-9034-09aa43e3d972
# ╟─f37c9963-ed1b-4784-a0df-3745bcadd1b1
# ╟─ecec680f-5536-4798-861f-6f0945e6c175
# ╟─ccbb091b-19c2-4bfb-9e04-4f77f395fdba
# ╟─edb99047-cdea-4149-ab67-640ddbd7aec5
# ╟─73335835-def4-4a1c-a6fa-61158f445dcb
# ╟─17de112e-91a8-4b55-93da-cecd0d9ca89f
# ╟─72ddeeae-4cb0-4268-bbe8-c60f5be6bdb2
# ╠═f3d465f2-1b09-4c24-985a-9696d13699b2
# ╠═1ad86cd6-415e-432a-adec-366cb9a54bba
# ╠═d5ac78a4-70c3-4a35-95c1-1d58f403facd
# ╠═e4b279ba-bbe5-4c1c-a346-ab70a1b61cc6
# ╠═0468013d-5283-4b48-8729-e833b3d2f8f8
# ╠═2b52be49-eb95-4d11-adc4-c0b64a818872
# ╠═1d81674b-67f5-4c9c-a351-b2fda419aba3
# ╠═4a2e1f66-d637-476f-8f80-e5c46798e4bd
# ╠═f70883db-74cb-485e-a426-f334dce178b2
# ╠═e15a8d41-41b8-4f55-b364-9586dc729bc3
# ╠═e24420c8-2c85-468a-92df-814ba619e575
# ╠═db733129-28e0-49e0-811f-f38f670fda38
# ╠═fa0d3f2f-3ce2-4e19-bb8e-874bdd7028bc
# ╠═a877a885-d771-407d-9a29-d13f384c4ae5
# ╠═2a2e0c2e-7397-4255-98c1-267b93ed4e55
# ╟─b2a5ce6c-34fd-4d50-92d0-5d35df4447af
# ╠═760e3f79-d623-4544-af77-5250d61f4854
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
