### A Pluto.jl notebook ###
# v0.20.17

#> [frontmatter]
#> image = "https://www.seti.org/media/5b4llxo1/exoplanet-education-03-2022.jpg"
#> title = "Color Images"
#> date = "2025-08-01"
#> tags = ["images"]
#> description = "Create color images from FITS file data."

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

# ╔═╡ a2044d4d-77de-446b-b7e1-b7a32c65266c
using AstroImages

# ╔═╡ 926ae0c8-5dd2-11f0-3c63-e540d51a756c
begin
	using PlutoUI
	
	# Re-exported from ColorTypes.jl for convenience
	using AstroImages: RGB, Gray, red, green, blue, gray 
	
	AstroImages.set_cmap!(nothing)
end

# ╔═╡ 8e324690-373d-4139-8350-add89a86c9b0
md"""

# 🎨 Color Images

$(Resource("https://imgs.xkcd.com/comics/painbow_award.png"))

_Image credit: [xkcd](https://xkcd.com/2537/). Alt text: "This year, our team took home the dark blue ribbon, better than the midnight blue we got last year but still short of the winning navy blue."_

---

What's in an image? Turns out just a nice, orderly set of numbers. In this brief primer, we will explore how astronomers use scientific programming to interpret these numbers. Along the way, we will cover the following key concepts in astronomical imaging:

1. Software tools
1. Image formats
1. Array representations
1. Color maps and color scales
1. Image stacking
"""

# ╔═╡ 22d2fa56-a505-43af-9bc5-034045e13dd9
md"""
!!! note "Coffee? ☕"
	The first time this notebook runs might take a while (~ a couple minutes on older devices) because it will download and set up everything for us. This is a good chance to take a stretch or grab a nice beverage 🫖.
"""

# ╔═╡ d23819bc-ddae-4de7-83b1-58453848d266
md"""
## 1. Software tools 💻

Today, there are a wide range of tools to select from when doing astronomical research. For this workshop series we will use [Julia](https://julialang.org/), a modern programming language geared towards [science and engineering applications](https://juliahub.com/industries/case-studies). A growing list of astronomy and astrophysics applications can be found on the [JuliaAstro case studies page](https://juliaastro.org/home/case_studies/).

To promote best practices in modern science software developement (e.g., reproducibility, maintainability, and literacy), we will be using the [Pluto.jl](https://plutojl.org/) notebook environment (also written in Julia) to share and work with real code used by professional astronomers throughout this workshop. This notebook you are currently reading is also a Pluto.jl notebook!

!!! tip
	* For folks approaching programming for the first time: [What is a notebook?](https://en.wikipedia.org/wiki/Notebook_interface)

	* For folks coming from a Python background: Julia is to Python as Pluto.jl is to Jupyter
"""

# ╔═╡ 1a9ae0d8-9da7-4c60-a088-e242565b4534
md"""
### Quickstart

To get started, please follow the instructions in the following two steps below:

1. [Install Julia](https://julialang.org/install/) 
1. [Install Pluto.jl](https://plutojl.org/#install) 

Additional resources:

* Learn Julia: [Julia website](https://julialang.org/learning/)
* Noteworthy Differences from other Languages: [Julia manual](https://docs.julialang.org/en/v1/manual/noteworthy-differences/)
* Handy cheatsheets: [JuliaDocs](https://cheatsheet.juliadocs.org/), [MATLAB--Python--Julia](https://cheatsheets.quantecon.org/)
* [Featured Pluto.jl notebooks](https://featured.plutojl.org/)
"""

# ╔═╡ af1b84fc-cc08-45e0-a849-fa11c1267b91
md"""
## 2. Image formats 📚

Astronomical images start their lives as a box of numbers. This box can be represented in a variety of different formats, the most popular currently being the [Flexible Image Transport System](https://en.wikipedia.org/wiki/FITS) (FITS) format. We will explore FITS files shortly, but let's start with another common format that you might use every day, [Portable Network Graphics](https://en.wikipedia.org/wiki/PNG) (PNG), to get an idea of how image data is represented and how these different formats relate to each other.
"""

# ╔═╡ e054ca6a-d276-47d5-b8ee-eb63d7d770fa
md"""
### PNG

We can use an image of anything, really. Below, we download a PNG of the famous ["Cosmic Cliffs"](https://webbtelescope.org/contents/media/images/2022/031/01G77PKB8NKR7S8Z6HBXMYATGJ) image taken from JWST and store it in a variable named `img`:
"""

# ╔═╡ 563781c1-5046-413b-8846-6514cba58d77
img = load(download("https://stsci-opo.org/STScI-01GA6KNV1S3TP2JBPCDT8G826T.png"))

# ╔═╡ 1bc51ec7-5dbf-43f7-b158-dc90992a48fe
md"""
_Image credit: NASA, ESA, CSA, STScI_
"""

# ╔═╡ 8769ad1c-9de8-4ee4-b030-a2805f28353f
md"""
We now have an image that we can analyze. For starters, let's display some key characteristics about `img`:
"""

# ╔═╡ 8eb994d7-c74d-481a-9e75-9c834d23bd18
nrows, ncols = size(img)

# ╔═╡ 49ca1b81-2eed-40da-afca-d9d2d51438f6
px_type = eltype(img)

# ╔═╡ 100d8b5b-9fb3-4008-89cf-b94a9ecd67b3
md"""
We see here that our image is $(nrows) rows by $(ncols) columns wide, and each cell (or pixel) of this image is represented by a $(px_type) type.

Even though this part is Julia specific, the underlying information is general enough to apply to most image processing libraries. Let's break down what each piece means: 

* [`ColorTypes`](https://github.com/JuliaGraphics/ColorTypes.jl): The name of the package where a type called `RGB` is defined.

* [`RGB`](https://github.com/JuliaGraphics/ColorTypes.jl#rgb-plus-bgr-xrgb-rgbx-and-rgb24-the-abstractrgb-group): A type that stores the red, green, and blue intensity values of a pixel. These can be thought of as [sub-pixels](https://en.wikipedia.org/wiki/Pixel#Subpixels).

* [`FixedPointNumbers`](https://github.com/JuliaMath/FixedPointNumbers.jl): The name of the package where a type called `N0f8` is defined.

* [`N0f8`](https://github.com/JuliaMath/FixedPointNumbers.jl#type-hierarchy-and-interpretation): A type that represents a number in memory. This essentially defines the specific number type used for each red, green, and blue value in each pixel. More on [`N0f8` and other number formats](https://juliaimages.org/latest/tutorials/quickstart/#The-0-to-1-intensity-scale).

To summarize, our image is just a matrix of pixels, where each pixel value is represented by a triple of RGB values stored in a memory efficient format. Let's explore next how these numbers connect to how we perceive color.
"""

# ╔═╡ d8cd4c83-9b02-43d2-947c-354ec7c51637
@bind resample Button("Resample")

# ╔═╡ c7cbf787-a8a5-4e57-b4d2-4dc0a592d821
begin
	N_sampled_px = 5
	resample
	sample_px = rand(img, N_sampled_px)
end

# ╔═╡ 9cac3e33-c68a-4f6b-8021-003ba876b4e9
md"""
### Pixel colors

Below, we sample $(N_sampled_px) random pixels from `img`. Based on how colorful and varied the image is, these pixels can have a range of different colors between them. Pull the slider to look at each of these pixels one by one and/or click the `Resample` button to select $(N_sampled_px) new pixels at random. For convenience, we also display the individual (R, G, B) values next to our slider.
"""

# ╔═╡ 1f95d2e2-33f4-4016-84a6-b983ede688b2
@bind px_img Slider(sample_px; show_value=true)

# ╔═╡ f73c7298-cd97-4539-b85f-25cf69508466
begin
	r, g, b = px_img .|> (red, green, blue)
	
	md"""
	Pixel | R | G | B
	:-:|:-:|:-:|:-:
	$(px_img) | $(RGB(r, 0, 0)) | $(RGB(0, g, 0)) | $(RGB(0, 0, b))
	"""
end

# ╔═╡ 5e185421-f0f1-4337-b59f-1752addbbe09
md"""
Below our selected pixel, we map these (R, G, B) values to their corresponding sub-pixel, where 0 represents black (or no brightness), and 1 represents the peak brightness for the given color channel. The resulting color is then the [additive combination](https://en.wikipedia.org/wiki/RGB_color_model#Additive_colors) of these individual subpixels.

Astronomers typically work with [black and white](https://hubblesite.org/contents/articles/the-meaning-of-light-and-color) (or [grayscale](https://en.wikipedia.org/wiki/Grayscale)) images, so we will next see how we can convert our image to this form using the information we have above. Later, we will see why this is a beneficial form to have our image in when we explore the FITS file format.
"""

# ╔═╡ b4c6c60b-b7bc-46a7-9e3c-5f8494fc8068
md"""
### Grayscale

The converversion process from ``RGB`` to grayscale for a given pixel is achieved by taking a weighted average of its channel values according to an [international standard](https://en.wikipedia.org/wiki/Luma_%28video%29#Rec._601_luma_versus_Rec._709_luma_coefficients) established to emulate how the [human eye perceives relative brightnesses](https://en.wikipedia.org/wiki/Grayscale#Converting_color_to_grayscale):

```math
0.299 R + 0.587 G + 0.114 B \quad.
```

This is [already implemented for us](https://juliaimages.org/latest/examples/color_channels/rgb_grayscale/) in the `ColorTypes` package with the `Gray` function, which we apply below to each pixel of our image to produce the following grayscale version:
"""

# ╔═╡ 57a70e86-625e-4ab4-9309-d618c5edba1b
img_gray = Gray.(img)

# ╔═╡ 807485a1-aae1-4e4f-9787-14254fb8a005
md"""
Taking a look at the properties of our new image, we see that now instead of being a matrix composed of `RGB{N0f8}` types, it is composed of `Gray{N0f8}`s:
"""

# ╔═╡ 92314a4b-3e05-42bf-a221-7dcf96c015fe
eltype(img_gray)

# ╔═╡ 90960427-7433-4528-8cba-03444212d2c0
md"""
!!! note
	We elide the package names for brevity.

In other words, instead of three numbers representing each pixel, we now have a single number for each, which we can view directly:
"""

# ╔═╡ 79184229-63fa-44e8-a79e-8e6ac6ce485f
img_data = gray.(img_gray)

# ╔═╡ fc10e422-b881-4b40-8d33-e5f53008045c
md"""
This "box of numbers" format is how image data is represented in FITS files.

!!! tip "Exercise"
	Try repeating the above analysis with you own PNG image! Note that the filetype must be a PNG.
"""

# ╔═╡ 3805d078-f4d0-485a-897d-82b3ea3da4ee
@bind img_local FilePicker([MIME("image/png")])

# ╔═╡ 9cda2b8c-ed17-4a16-92bc-f6b334d24208
my_img = if !isnothing(img_local)
	path = tempname() * img_local["name"]
	write(path, img_local["data"])
	load(path)
else
	nothing
end

# ╔═╡ 94dae9e9-9eb5-406d-b777-976db28d6631
md"""
### FITS

[FITS](https://en.wikipedia.org/wiki/FITS) images are already in grayscale and can come packaged with additional metadata (known as *headers*) and data tables that inform us about the observing conditions (e.g., longitude, latitude, gain, exposure time) that our data were taken in. Together these are known as Headers + Data Units (or [*HDUs*](https://heasarc.gsfc.nasa.gov/docs/heasarc/fits_overview.html)), and they can help us reduce systematics from the instrument and environment. Additionally, individual science images can be stacked together to increase the overall signal-to-noise ratio (SNR) of our observations.

!!! note "But why grayscale?"
	FITS images give us a direct correspondence between the location of the pixel that a particular photon of light falls on in our array, and how strong that signal will be. Images taken at specific wavelengths can then be stacked together to create [full color composite images](https://hubblesite.org/contents/articles/the-meaning-of-light-and-color). The downside for our particular usecase is that these images taken by our eVscope sensor have not been [debayered](https://en.wikipedia.org/wiki/Bayer_filter), which complicates this correspondance. We will explore some of the imaging artifacts that are introduced by this, and potential techniques that we can use to mitigate them.

Later in this workshop, we will explore working with real FITS data taken by your eVscope. For now, we will continue working with the underlying "box of numbers" array representation to build intuition for processing this kind of data.
"""

# ╔═╡ d47ae19a-9b82-41a2-ba38-6087623f5de8
md"""
## 3. Array representations 🔢

Now that we have this mathematical representation of our image, let's explore a few key operations that we can perform on it:

1. Indexing
2. Slicing
3. Reducing
"""

# ╔═╡ a353587e-9c79-455f-a00c-f58b8eb86b4d
md"""
#### 3.1 Indexing

We actually saw this earlier already when looking at individual pixels in our image. Indexing is just another way of saying selecting a subset of our image. For example,
"""

# ╔═╡ 0923a1b3-2ccb-4fd5-b00f-a0a5eec660c9
img_data[1, 1]

# ╔═╡ 070fbd79-830e-46c9-aeed-dcad3a5836f9
md"""
selects the element in the first row and first column of our image. We can also use generic keywords like `begin` and `end` to select the first or last element of our matrix, respectively.
"""

# ╔═╡ 9d8ef8cb-300a-4872-9220-f70988a38154
md"""
!!! tip "Question"
	What does indexing with only a single number, e.g., `img_data[10]` return? Why is this?
"""

# ╔═╡ 87cc25a5-c3fa-436a-aa1a-9c2a670433f1
md"""
👉 Your notes here

"""

# ╔═╡ 1cbafa19-93b8-4589-9060-839bd010d60f
md"""
!!! hint
	See [here](https://docs.julialang.org/en/v1/manual/arrays/#Linear-indexing) and [here](https://docs.julialang.org/en/v1/manual/performance-tips/#man-performance-column-major) in the manual.
"""

# ╔═╡ e43c8196-d6fd-4b77-8e07-122567b7f30d
md"""
#### 3.2 Slicing

Selecting multiple elements that are next to each other (contiguous) is known as slicing. For example,
"""

# ╔═╡ 348599bf-cda8-4ebb-8e3d-83ce0171c7f8
img_data_row = img_data[1, :]

# ╔═╡ 6bb683f6-c237-4e31-963e-fb1135670cbf
md"""
selects every column in the first row of `img_data` while,
"""

# ╔═╡ 17b7c5fa-8360-41ca-86c7-686e05375886
img_data_corner = img_data[1:500, 1:500]

# ╔═╡ 167a81cd-26fa-4500-9b90-6b6b449ba87a
md"""
returns the first $(size(img_data_corner, 1)) rows and first $(size(img_data_corner, 2)) columns, i.e., the top-left corner:
"""

# ╔═╡ 9e6c60e8-a28d-42d5-bb91-18ea8d477027
img_corner_gray = img_data_corner .|> Gray

# ╔═╡ c8468580-b24c-465a-bb28-b60033cecfcb
details(md"What does `|>` do?",
md"""
!!! note ""
	Known as the [pipe operator](https://docs.julialang.org/en/v1/manual/functions/#Function-composition-and-piping), this is a convenient way to pass the output of one function as input to another. For example,

	```julia
	sqrt(sum([1, 4, 5, 6])) # 4.0
	```

	is equivalent to:

	```julia
	[1, 4, 5, 6] |> sum |> sqrt # 4.0
	```

	Note how this seamlessly composes with the dot operator in our image example above.
""")

# ╔═╡ 5b303ede-1726-46f5-8ba4-8fdbfec3211e
md"""
!!! tip "Question"
	Try going back to your original color image `img`. Using slices, try to produce the following image:
"""

# ╔═╡ 88bbd6c2-896d-4c14-8c59-7e4720ab69a4
img[1, :]

# ╔═╡ 34404369-9a2c-461d-a281-702fe208cd8a
md"""
👉 Your notes here


"""

# ╔═╡ 869491d6-660a-4bfc-94db-1ed87b547085
md"""
#### 3.3 Reducing

Often, we would like to know summary statistics about a given region in our image. Applying functions that boil down our box of numbers to a smaller representative set is known as reduction. For example, to get the total pixel value in each column of our above slice, we could do the following:
"""

# ╔═╡ 4a43a5ef-db43-46c6-85c7-e87a74349bae
sum(img_data[1, :]; dims=2)

# ╔═╡ 120d584b-9f8b-48e8-866a-21a01be34fe8
md"""
!!! tip "Question"
	What does the `dims` keyword do? Try it out on a simpler matrix like:

	```julia
	arr = [
		1 2
		3 4
	]
	```

	Note: You can pull up the documentation for any function by selecting the `Live Docs` button in the bottom right corner of this notebook.
"""

# ╔═╡ 258e42cb-4f72-4400-8954-30ab72be4c5f
md"""
👉 Your notes here


"""

# ╔═╡ ea73493c-8076-4823-9129-83dea64f8e9f
md"""
## 4. Color maps and color scales 🌈

So far, we have been using general purpose tools for displaying images. We now transition to a more specialized tool named [AstroImages.jl](https://juliaastro.org/AstroImages/stable/), which extends the functionality we have already used to work with astronomical images.


$(details("Aside", md" 
This method of extending functionality in separate packages is a core part of the Julia language. It allows for ecosystems of tools to form naturally in different fields of study, which then compose seamlessly with each other thanks to the [multiple dispatch](https://docs.julialang.org/en/v1/manual/methods/#Methods) paradigm that underpins the language. For more on this, see [this talk](https://www.youtube.com/watch?v=kc9HwsxE1OY) by one of the Julia creators."
))

To start, let's wrap our underlying image data in `img_data_corner` in an `AstroImage` type:
"""

# ╔═╡ 3414a8d3-8f6e-4bb5-a49a-07b50214d0d1
img_astro_gray = AstroImage(img_data_corner)

# ╔═╡ cbe507f9-81ff-4384-9d5e-0e41f9c7db1d
details("Why do things looks flipped?",
md"""
You may notice that `img_astro` looks transposed and flipped relative to `img_data`. This is to comply with the [FITS convention](https://juliaastro.org/AstroImages/stable/manual/conventions/) of placing the origin of an image in the bottom left corner, instead of the top left.
"""
)

# ╔═╡ 90e0f43a-aa13-46ad-be19-62c94e599bc5
md"""
We now have all of the usual benefits of working with image data that we have seen already, along with additional features specific to FITS files, like headers and WCS information if available. We will explore these features more later in the workshop. For now, we will use the [`imview`](https://juliaastro.org/AstroImages/stable/api/#AstroImages.imview) function that comes with AstroImages.jl to explore different ways to visualize our given data.

We called:

```julia
AstroImages.set_cmap!(nothing)
```

at the bottom of this notebook to set the default grayscale colormap (the relationship between the given pixel value and associated color) that our AstroImage.jl images are displayed in. We can override this mapping by passing the `cmap` keyword to `imview`:
"""

# ╔═╡ 137564b4-a4c6-4271-9399-379d655e8302
imview(img_astro_gray; cmap = :cividis)

# ╔═╡ d59a25de-7117-4fc0-9ec3-7b5a993b34bd
md"""
This now our image using the Cividis colormap, which can be a good choice for people with color vision deficiencies to help make accurate interpretations of scientific data.

To help bring out features of interest, we can also control the functional mapping between pixel value and color via the `stretch` keyword:
"""

# ╔═╡ 9c3bfa7d-b324-4a04-bcaf-3a3a549ca356
imview(img_astro_gray; cmap = :cividis, stretch = powstretch)

# ╔═╡ 8827b121-279d-42a2-9a74-098bec267318
md"""
!!! tip "Question"

	What is `powstretch`? What other functions can be passed?

!!! hint
	AstroImages.jl follows the colorscale specifications [defined in DS9](https://ds9.si.edu/doc/ref/how.html).
"""

# ╔═╡ 9afd404b-5bed-4edd-859d-a07250860d28
md"""
👉 Your notes here


"""

# ╔═╡ c47504a5-60d2-4ef6-a75a-2e5e2e1dc984
md"""
## 5. Image stacking 🥞

_Examples taken from [`JuliaAstro > AstroImages.jl > Converting to RGB`](https://juliaastro.org/AstroImages/stable/manual/converting-to-rgb/)_.

!!! todo
	Fill out
"""

# ╔═╡ f947c8a9-861e-404d-8dab-d4a88b913fe8
md"""
### RGB
"""

# ╔═╡ f11c4c56-101c-42fb-9fa4-bf6b91c30ad1
# We crop some of the images a bit to help align them with the other color channels
antred = AstroImage(download("https://esahubble.org/static/projects/fits_liberator/datasets/antennae/red.fits"))[:, begin+14:end]

# ╔═╡ 688a41ca-5652-43c3-83a6-b4ab03301867
antgreen = AstroImage(download("https://esahubble.org/static/projects/fits_liberator/datasets/antennae/green.fits"))

# ╔═╡ 0d8df701-596a-4200-bf88-adf4adb9f168
antblue = AstroImage(download("https://esahubble.org/static/projects/fits_liberator/datasets/antennae/blue.fits"))[:, begin+14:end]

# ╔═╡ 3fffe0f3-e332-4016-9c9c-0be1c2694e63
rgb = composecolors([antred, antgreen, antblue];
	clims = Percent(97),
	stretch = asinhstretch,
    multiplier = [1, 1.7, 1],
)

# ╔═╡ fbecb5d2-2892-4e04-8bcb-59f4c29b08cf
md"""
### H-alpha
"""

# ╔═╡ 8bd7e1b6-a146-4ece-ad95-a097c6387705
anthalph = AstroImage(download("https://esahubble.org/static/projects/fits_liberator/datasets/antennae/hydrogen.fits"))[:, begin+14:end]

# ╔═╡ bbe0c915-9a64-4234-8b51-d14e170c3c90
rgb6 = composecolors(
    [antred, antgreen, antblue, anthalph],
    ["red", "green", "blue", "maroon1"],
    stretch=[
        asinhstretch,
        asinhstretch,
        asinhstretch,
        identity,
    ],
    multiplier=[1,1.7,1,0.8]
)

# ╔═╡ 98e95070-f5a9-4d5a-b2c2-14d1b489febe
md"""
# 📖 Further reading

!!! todo
	Clean up

<https://science.nasa.gov/ems/04_energytoimage/>

<https://webbtelescope.org/contents/articles/how-are-webbs-full-color-images-made>

<https://computationalthinking.mit.edu/Fall24/images_abstractions/images/>
"""

# ╔═╡ ef1945ce-84be-4ed9-ba0e-25b7be69400a
md"""
# 🔧 Notebook setup
"""

# ╔═╡ 1ddf2e92-a35d-4f24-87e0-2ca04bb4059e
TableOfContents(depth = 4)

# ╔═╡ c2816617-5cb1-4e51-948e-60efdaa7db1c
msg(x) = details("Details", x)

# ╔═╡ 4c0dd0c1-b446-46c2-a190-10eac40d1cc4
md"""
!!! note
	Julia has a delightful way of applying a function element-wise to its inputs, known as [dot syntax](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized).
""" |> msg

# ╔═╡ 3e9f7a17-b6cb-4c50-b38b-e39f437a5c30
html"""
<style>
	table { float: left }
</style>
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
AstroImages = "fe3fc30c-9b16-11e9-1c73-17dabf39f4ad"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
AstroImages = "~0.5.1"
PlutoUI = "~0.7.68"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.11.6"
manifest_format = "2.0"
project_hash = "7a0c16e8adb06eb12ad62741682e2c740c55dbcf"

[[deps.AbstractFFTs]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "d92ad398961a3ed262d8bf04a1a2b8340f915fef"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.5.0"

    [deps.AbstractFFTs.extensions]
    AbstractFFTsChainRulesCoreExt = "ChainRulesCore"
    AbstractFFTsTestExt = "Test"

    [deps.AbstractFFTs.weakdeps]
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "6e1d2a35f2f90a4bc7c2ed98079b2ba09c35b83a"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.3.2"

[[deps.Adapt]]
deps = ["LinearAlgebra", "Requires"]
git-tree-sha1 = "f7817e2e585aa6d924fd714df1e2a84be7896c60"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "4.3.0"

    [deps.Adapt.extensions]
    AdaptSparseArraysExt = "SparseArrays"
    AdaptStaticArraysExt = "StaticArrays"

    [deps.Adapt.weakdeps]
    SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.2"

[[deps.ArrayInterface]]
deps = ["Adapt", "LinearAlgebra"]
git-tree-sha1 = "9606d7832795cbef89e06a550475be300364a8aa"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "7.19.0"

    [deps.ArrayInterface.extensions]
    ArrayInterfaceBandedMatricesExt = "BandedMatrices"
    ArrayInterfaceBlockBandedMatricesExt = "BlockBandedMatrices"
    ArrayInterfaceCUDAExt = "CUDA"
    ArrayInterfaceCUDSSExt = "CUDSS"
    ArrayInterfaceChainRulesCoreExt = "ChainRulesCore"
    ArrayInterfaceChainRulesExt = "ChainRules"
    ArrayInterfaceGPUArraysCoreExt = "GPUArraysCore"
    ArrayInterfaceReverseDiffExt = "ReverseDiff"
    ArrayInterfaceSparseArraysExt = "SparseArrays"
    ArrayInterfaceStaticArraysCoreExt = "StaticArraysCore"
    ArrayInterfaceTrackerExt = "Tracker"

    [deps.ArrayInterface.weakdeps]
    BandedMatrices = "aae01518-5342-5314-be14-df237901396f"
    BlockBandedMatrices = "ffab5731-97b5-5995-9138-79e8c1846df0"
    CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
    CUDSS = "45b445bb-4962-46a0-9369-b4df9d0f772e"
    ChainRules = "082447d4-558c-5d27-93f4-14fc19e9eca2"
    ChainRulesCore = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
    GPUArraysCore = "46192b85-c4d5-4398-a991-12ede77f4527"
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

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "16351be62963a67ac4083f748fdb3cca58bfd52f"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.7"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"
version = "1.11.0"

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
git-tree-sha1 = "15e80be798d7711411f4ac4273144cdb2a89eb2f"
uuid = "b3e40c51-02ae-5482-8a39-3ace5868dcf4"
version = "4.6.2+0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "PrecompileTools", "Random"]
git-tree-sha1 = "a656525c8b46aa6a1c76891552ed5381bb32ae7b"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.30.0"

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

    [deps.ColorVectorSpace.extensions]
    SpecialFunctionsExt = "SpecialFunctions"

    [deps.ColorVectorSpace.weakdeps]
    SpecialFunctions = "276daf66-3868-5448-9aa4-cd146d93841b"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "37ea44092930b1811e666c3bc38065d7d87fcc74"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.13.1"

[[deps.Compat]]
deps = ["TOML", "UUIDs"]
git-tree-sha1 = "3a3dfb30697e96a440e4149c8c51bf32f818c0f3"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.17.0"
weakdeps = ["Dates", "LinearAlgebra"]

    [deps.Compat.extensions]
    CompatLinearAlgebraExt = "LinearAlgebra"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.1.1+0"

[[deps.ConstructionBase]]
git-tree-sha1 = "b4b092499347b18a015186eae3042f72267106cb"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.6.0"

    [deps.ConstructionBase.extensions]
    ConstructionBaseIntervalSetsExt = "IntervalSets"
    ConstructionBaseLinearAlgebraExt = "LinearAlgebra"
    ConstructionBaseStaticArraysExt = "StaticArrays"

    [deps.ConstructionBase.weakdeps]
    IntervalSets = "8197267c-284f-5f27-9208-e0e47529a953"
    LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
    StaticArrays = "90137ffa-7385-5640-81b9-e52037218182"

[[deps.DataAPI]]
git-tree-sha1 = "abe83f3a2f1b857aac70ef8b269080af17764bbe"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.16.0"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "4e1fe97fdaed23e9dc21d4d664bea76b65fc50a0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.22"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"
version = "1.11.0"

[[deps.DimensionalData]]
deps = ["Adapt", "ArrayInterface", "ConstructionBase", "DataAPI", "Dates", "Extents", "Interfaces", "IntervalSets", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "PrecompileTools", "Random", "RecipesBase", "SparseArrays", "Statistics", "TableTraits", "Tables"]
git-tree-sha1 = "b628bd06173897d44ab5cb5122e4a31509997c5a"
uuid = "0703355e-b756-11e9-17c0-8b28908087d0"
version = "0.29.17"

    [deps.DimensionalData.extensions]
    DimensionalDataAlgebraOfGraphicsExt = "AlgebraOfGraphics"
    DimensionalDataCategoricalArraysExt = "CategoricalArrays"
    DimensionalDataDiskArraysExt = "DiskArrays"
    DimensionalDataMakie = "Makie"
    DimensionalDataNearestNeighborsExt = "NearestNeighbors"
    DimensionalDataPythonCall = "PythonCall"
    DimensionalDataStatsBase = "StatsBase"

    [deps.DimensionalData.weakdeps]
    AlgebraOfGraphics = "cbdf2221-f076-402e-a563-3d30da359d67"
    CategoricalArrays = "324d7699-5711-5eae-9e2f-1d82baa6b597"
    DiskArrays = "3c3547ce-8d99-4f5e-a174-61eb10b00ae3"
    Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
    NearestNeighbors = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
    PythonCall = "6099a3de-0909-46bc-b1f4-468b9a2dfc0d"
    StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"

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
version = "1.6.0"

[[deps.Extents]]
git-tree-sha1 = "b309b36a9e02fe7be71270dd8c0fd873625332b4"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.6"

[[deps.FITSIO]]
deps = ["CFITSIO", "Printf", "Reexport", "Tables"]
git-tree-sha1 = "f57de3f533590c785210893030736dc11c4a4afb"
uuid = "525bcba6-941b-5504-bd06-fd0dc1a4d2eb"
version = "0.17.5"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "b66970a70db13f45b7e57fbda1736e1cf72174ea"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.17.0"

    [deps.FileIO.extensions]
    HTTPExt = "HTTP"

    [deps.FileIO.weakdeps]
    HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"
version = "1.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "05882d6995ae5c12bb5f36dd2ed3f61c98cbb172"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.5"

[[deps.Giflib_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "6570366d757b50fabae9f4315ad74d2e40c0560a"
uuid = "59f7168a-df46-5410-90c8-f2779963d0ec"
version = "5.2.3+0"

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
git-tree-sha1 = "b6d6bfdd7ce25b0f9b2f6b3dd56b2673a66c8770"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.5"

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

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "0936ba688c6d201805a83da835b55c61a180db52"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.11+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "d1b1b796e47d94588b3757fe84fbf65a5ec4a80d"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.5"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
version = "1.11.0"

[[deps.Interfaces]]
git-tree-sha1 = "331ff37738aea1a3cf841ddf085442f31b84324f"
uuid = "85a1e053-f937-4924-92a5-1367d23b7b87"
version = "0.3.2"

[[deps.IntervalSets]]
git-tree-sha1 = "5fbb102dcb8b1a858111ae81d56682376130517d"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.7.11"
weakdeps = ["Random", "RecipesBase", "Statistics"]

    [deps.IntervalSets.extensions]
    IntervalSetsRandomExt = "Random"
    IntervalSetsRecipesBaseExt = "RecipesBase"
    IntervalSetsStatisticsExt = "Statistics"

[[deps.InvertedIndices]]
git-tree-sha1 = "6da3c4316095de0f5ee2ebd875df8721e7e0bdbe"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.3.1"

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
git-tree-sha1 = "a007feb38b422fbdab534406aeca1b86823cb4d6"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.7.0"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "31e996f0a15c7b280ba9f76636b3ff9e2ae58c9a"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.4"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "9496de8fb52c224a2e3f9ff403947674517317d9"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.6"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "eac1206917768cb54957c65a615460d87b455fc1"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "3.1.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "aaafe88dccbd957a8d82f7d05be9b69172e0cee3"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "4.0.1+0"

[[deps.LazyModules]]
git-tree-sha1 = "a560dd966b386ac9ae60bdd3a3d3a326062d3c3e"
uuid = "8cdb02fc-e678-4876-92c5-9defec4f444e"
version = "0.3.1"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.4"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "8.6.0+0"

[[deps.LibGit2]]
deps = ["Base64", "LibGit2_jll", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"
version = "1.11.0"

[[deps.LibGit2_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll"]
uuid = "e37daf67-58a4-590a-8e99-b0245dd2ffc5"
version = "1.7.2+0"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.11.0+1"

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
git-tree-sha1 = "4ab7581296671007fc33f07a721631b8855f4b1d"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.7.1+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
version = "1.11.0"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"
version = "1.11.0"

[[deps.MIMEs]]
git-tree-sha1 = "c64d943587f7187e751162b3b84445bbbd79f691"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "1.1.0"

[[deps.MacroTools]]
git-tree-sha1 = "1e0228a030642014fe5cfe68c2c0a818f9e3f522"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.16"

[[deps.MappedArrays]]
git-tree-sha1 = "2dab0221fe2b0f2cb6754eaa743cc266339f527e"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.2"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"
version = "1.11.0"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.6+0"

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
version = "2023.12.12"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore", "ImageMetadata"]
git-tree-sha1 = "d92b107dbb887293622df7697a2223f9f8176fcd"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.1.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

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
version = "0.3.27+1"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "97db9e07fe2091882c765380ef58ec553074e9c7"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.3"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "8292dd5c8a38257111ada2174000a33745b06d4e"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.2.4+0"

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

[[deps.Parsers]]
deps = ["Dates", "PrecompileTools", "UUIDs"]
git-tree-sha1 = "7d2f8f21da5db6a806faf7b9b292296da42b2810"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.8.3"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "Random", "SHA", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.11.0"
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
git-tree-sha1 = "3ca9a356cd2e113c420f2c13bea19f8d3fb1cb18"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.4.3"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Downloads", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "ec9e63bd098c50e4ad28e7cb95ca7a4860603298"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.68"

[[deps.PrecompileTools]]
deps = ["Preferences"]
git-tree-sha1 = "5aa36f7049a63a1528fe8f7c3f2113413ffd4e1f"
uuid = "aea7be01-6a6a-4083-8856-8a6e6704d82a"
version = "1.2.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "9306f6085165d270f7e3db02af26a400d580f5c6"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.4.3"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"
version = "1.11.0"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "13c5103482a8ed1536a54c08d0e742ae3dca2d42"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.10.4"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "8b3fc30bc0390abdce15f8822c889f669baed73d"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.1"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "StyledStrings", "Unicode"]
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

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.SIMD]]
deps = ["PrecompileTools"]
git-tree-sha1 = "fea870727142270bdf7624ad675901a1ee3b4c87"
uuid = "fdea26ae-647d-5447-a871-4b548cad5224"
version = "3.7.1"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"
version = "1.11.0"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "0494aed9501e7fb65daba895fb7fd57cc38bc743"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.5"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"
version = "1.11.0"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
version = "1.11.0"

[[deps.StableRNGs]]
deps = ["Random"]
git-tree-sha1 = "95af145932c2ed859b63329952ce8d633719f091"
uuid = "860ef19b-820b-49d6-a774-d7a799459cd3"
version = "1.0.3"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "be1cf4eb0ac528d96f5115b4ed80c26a8d8ae621"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.2"

[[deps.Statistics]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "ae3bb1eb3bba077cd276bc5cfc337cc65c3075c0"
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.11.1"
weakdeps = ["SparseArrays"]

    [deps.Statistics.extensions]
    SparseArraysExt = ["SparseArrays"]

[[deps.StyledStrings]]
uuid = "f489334b-da3d-4c2e-b8f0-e476e12c162b"
version = "1.11.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "7.7.0+0"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

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
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "Mmap", "OffsetArrays", "PkgVersion", "PrecompileTools", "ProgressMeter", "SIMD", "UUIDs"]
git-tree-sha1 = "02aca429c9885d1109e58f400c333521c13d48a0"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.11.4"

[[deps.Tricks]]
git-tree-sha1 = "6cae795a5a9313bbb4f60683f7263318fc7d1505"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.10"

[[deps.URIs]]
git-tree-sha1 = "bef26fb046d031353ef97a82e3fdb6afe7f21b1a"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.6.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"
version = "1.11.0"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"
version = "1.11.0"

[[deps.WCS]]
deps = ["ConstructionBase", "WCS_jll"]
git-tree-sha1 = "858cf2784ff27d908df7a3fe22fcd5fbf02f508b"
uuid = "15f3aee2-9e10-537f-b834-a6fb8bdb944d"
version = "0.6.2"

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

[[deps.XZ_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "fee71455b0aaa3440dfdd54a9a36ccef829be7d4"
uuid = "ffd25f8a-64ca-5728-b0f7-c24cf3aae800"
version = "5.8.1+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "b5899b25d17bf1889d25906fb9deed5da0c15b3b"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.8.12+0"

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
git-tree-sha1 = "a4c0ee07ad36bf8bbce1c3bb52d21fb1e0b987fb"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.7+0"

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
version = "1.2.13+1"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl"]
git-tree-sha1 = "446b23e73536f84e8037f5dce465e92275f6a308"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.7+1"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.11.0+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Zlib_jll"]
git-tree-sha1 = "07b6a107d926093898e82b3b1db657ebe33134ec"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.50+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "libpng_jll"]
git-tree-sha1 = "c1733e347283df07689d71d61e14be986e49e47a"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.10.5+0"

[[deps.libwebp_jll]]
deps = ["Artifacts", "Giflib_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libglvnd_jll", "Libtiff_jll", "libpng_jll"]
git-tree-sha1 = "d2408cac540942921e7bd77272c32e58c33d8a77"
uuid = "c5f90fcd-3b7e-5836-afba-fc50a0988cb2"
version = "1.5.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.59.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+2"
"""

# ╔═╡ Cell order:
# ╟─8e324690-373d-4139-8350-add89a86c9b0
# ╟─22d2fa56-a505-43af-9bc5-034045e13dd9
# ╟─d23819bc-ddae-4de7-83b1-58453848d266
# ╟─1a9ae0d8-9da7-4c60-a088-e242565b4534
# ╟─af1b84fc-cc08-45e0-a849-fa11c1267b91
# ╟─e054ca6a-d276-47d5-b8ee-eb63d7d770fa
# ╠═563781c1-5046-413b-8846-6514cba58d77
# ╟─1bc51ec7-5dbf-43f7-b158-dc90992a48fe
# ╟─8769ad1c-9de8-4ee4-b030-a2805f28353f
# ╠═8eb994d7-c74d-481a-9e75-9c834d23bd18
# ╠═49ca1b81-2eed-40da-afca-d9d2d51438f6
# ╟─100d8b5b-9fb3-4008-89cf-b94a9ecd67b3
# ╟─9cac3e33-c68a-4f6b-8021-003ba876b4e9
# ╟─d8cd4c83-9b02-43d2-947c-354ec7c51637
# ╟─c7cbf787-a8a5-4e57-b4d2-4dc0a592d821
# ╟─1f95d2e2-33f4-4016-84a6-b983ede688b2
# ╟─f73c7298-cd97-4539-b85f-25cf69508466
# ╟─5e185421-f0f1-4337-b59f-1752addbbe09
# ╟─b4c6c60b-b7bc-46a7-9e3c-5f8494fc8068
# ╠═57a70e86-625e-4ab4-9309-d618c5edba1b
# ╟─4c0dd0c1-b446-46c2-a190-10eac40d1cc4
# ╟─807485a1-aae1-4e4f-9787-14254fb8a005
# ╠═92314a4b-3e05-42bf-a221-7dcf96c015fe
# ╟─90960427-7433-4528-8cba-03444212d2c0
# ╠═79184229-63fa-44e8-a79e-8e6ac6ce485f
# ╟─fc10e422-b881-4b40-8d33-e5f53008045c
# ╟─3805d078-f4d0-485a-897d-82b3ea3da4ee
# ╟─9cda2b8c-ed17-4a16-92bc-f6b334d24208
# ╟─94dae9e9-9eb5-406d-b777-976db28d6631
# ╟─d47ae19a-9b82-41a2-ba38-6087623f5de8
# ╟─a353587e-9c79-455f-a00c-f58b8eb86b4d
# ╠═0923a1b3-2ccb-4fd5-b00f-a0a5eec660c9
# ╟─070fbd79-830e-46c9-aeed-dcad3a5836f9
# ╟─9d8ef8cb-300a-4872-9220-f70988a38154
# ╠═87cc25a5-c3fa-436a-aa1a-9c2a670433f1
# ╟─1cbafa19-93b8-4589-9060-839bd010d60f
# ╟─e43c8196-d6fd-4b77-8e07-122567b7f30d
# ╠═348599bf-cda8-4ebb-8e3d-83ce0171c7f8
# ╟─6bb683f6-c237-4e31-963e-fb1135670cbf
# ╠═17b7c5fa-8360-41ca-86c7-686e05375886
# ╟─167a81cd-26fa-4500-9b90-6b6b449ba87a
# ╠═9e6c60e8-a28d-42d5-bb91-18ea8d477027
# ╟─c8468580-b24c-465a-bb28-b60033cecfcb
# ╟─5b303ede-1726-46f5-8ba4-8fdbfec3211e
# ╟─88bbd6c2-896d-4c14-8c59-7e4720ab69a4
# ╠═34404369-9a2c-461d-a281-702fe208cd8a
# ╟─869491d6-660a-4bfc-94db-1ed87b547085
# ╠═4a43a5ef-db43-46c6-85c7-e87a74349bae
# ╟─120d584b-9f8b-48e8-866a-21a01be34fe8
# ╠═258e42cb-4f72-4400-8954-30ab72be4c5f
# ╟─ea73493c-8076-4823-9129-83dea64f8e9f
# ╠═3414a8d3-8f6e-4bb5-a49a-07b50214d0d1
# ╟─cbe507f9-81ff-4384-9d5e-0e41f9c7db1d
# ╟─90e0f43a-aa13-46ad-be19-62c94e599bc5
# ╠═137564b4-a4c6-4271-9399-379d655e8302
# ╟─d59a25de-7117-4fc0-9ec3-7b5a993b34bd
# ╠═9c3bfa7d-b324-4a04-bcaf-3a3a549ca356
# ╟─8827b121-279d-42a2-9a74-098bec267318
# ╠═9afd404b-5bed-4edd-859d-a07250860d28
# ╟─c47504a5-60d2-4ef6-a75a-2e5e2e1dc984
# ╟─f947c8a9-861e-404d-8dab-d4a88b913fe8
# ╠═f11c4c56-101c-42fb-9fa4-bf6b91c30ad1
# ╠═688a41ca-5652-43c3-83a6-b4ab03301867
# ╠═0d8df701-596a-4200-bf88-adf4adb9f168
# ╠═3fffe0f3-e332-4016-9c9c-0be1c2694e63
# ╟─fbecb5d2-2892-4e04-8bcb-59f4c29b08cf
# ╠═8bd7e1b6-a146-4ece-ad95-a097c6387705
# ╠═bbe0c915-9a64-4234-8b51-d14e170c3c90
# ╟─98e95070-f5a9-4d5a-b2c2-14d1b489febe
# ╟─ef1945ce-84be-4ed9-ba0e-25b7be69400a
# ╠═1ddf2e92-a35d-4f24-87e0-2ca04bb4059e
# ╠═c2816617-5cb1-4e51-948e-60efdaa7db1c
# ╠═3e9f7a17-b6cb-4c50-b38b-e39f437a5c30
# ╠═a2044d4d-77de-446b-b7e1-b7a32c65266c
# ╠═926ae0c8-5dd2-11f0-3c63-e540d51a756c
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
