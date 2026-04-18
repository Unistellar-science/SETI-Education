### A Pluto.jl notebook ###
# v0.20.24

#> [frontmatter]
#> image = "https://www.seti.org/media/h3ejkrf3/image_0.png"
#> title = "Stellar Pulsators Lab"
#> date = "2026-04-17"
#> tags = ["time series", "pulsatords"]
#> description = "Observe a nearby asteroid occulting a background source."
#> layout = "layout.jlhtml"

using Markdown
using InteractiveUtils

# ╔═╡ 1c24444a-4274-485a-91fa-9584be38a891
md"""
# Stellar Puslators Lab

Target: <https://vsx.aavso.org/index.php?view=detail.top&oid=17922>
"""

# ╔═╡ 193adfcc-3ab9-11f1-b7d0-5b93798eec02
md"""
```julia
# Slack message backup
#
# Thanks for the comparison values! I went back and did a slightly more careful JD --> HJD conversion with my team as a gut check:
using Astrometry, LinearAlgebra

function t_corrected_astrom(t, ra, dec; kind = :heliocentric)
    # Astrometry
    jdtdb = from_utc(t; scale = TDB) |> julian |> value
    astrom = SOFA.apcg13(jdtdb, 0.0)
    gcra, gcdec = SOFA.atciq(deg2rad(ra), deg2rad(dec), 0.0, 0.0, 0.0, 0.0, astrom)

    # Heliocentric light travel time delay
    r⃗ = astrom.em * astrom.eh # Earth -- Sun vec, AU
    n̂ = SOFA.s2c(gcra, gcdec) # Earth -- source unit vec
    c = SOFA.LIGHTSPEED / SOFA.AU * SOFA.SECPERDAY # AU/day
    Δt = r⃗ ⋅ n̂ / c

    # Store results
    bjd = jdtdb + Δt
    ep = TDBEpoch(bjd * days; origin = :julian)
    return to_utc(DateTime, ep)
end

# which for your observed time of max light gives us about a 7 minute lag time for HJD:

t_utc = DateTime(2026, 02, 21, 23, 0, 0) # Just eye-balling from plot
t_corrected_astrom(t_utc, ra, dec) # 2026-02-21T23:07:03.850

# This is also in good agreement (< 30 ms in the barycentric frame) with this popular time conversion calculator made by one of my colleagues. This, combined with the fact that @Ingo (Freiburg, Germany)'s observations line up nicely with yours makes me more confident that we have our times correct (yay having multiple observations).
# 
# This also looks to be the exact discrepancy seen in the AAVSO ephemeris table, just in the opposite direction (22:53 UTC vs. 23:00 UTC), which leads me to the following speculation:
# 
# Speculation: This will require some follow-up, but something I noticed is that the binary separation of this pulsator and its companion is about 1 AU, which seems like a suspicious coincidence. If the AAVSO ephemeris only takes the pulsation period into account, and not the orbital period of this system, then there is a possibility that this 7 minute discrepancy could be coming from Sz Lyn being roughly 1 AU farther from us (up to the sine of its inclination) at the time of observation, which as we saw in the heliocentric case, can give a correction of up to +/- 8 minutes (1 AU / speed of light). It would be interesting to see how the ephemeris is being calculated, and what, if any, the contribution from its orbital period would be. This is exciting =]
#
# Neat, I think that might be it. It looks like AAVSO is indeed just using a linear ephemeris, and leaves higher-order corrections to us. Luckily, there's an observer note under the "Remarks" section on the target page that we can use to simplify things. Here's a brief summary applying it:

# Values from https://vsx.aavso.org/index.php?view=detail.top&oid=17922
let
    T_0 = 2453766.839 # HJD
    P_pulse = 0.12053525 # Pulsation period
    P_orb = 1146 # Binary period
    E = 60_784 # Cycle

    # Linear ephemeris reported by AAVSO
    ephem_lin = T_0 + P_pulse * E

    # Correction from GCVS Team in "Remarks" section
    ephem_orb = -0.00573 * cos(2 * π * (E * 0.120534920/1150 + 0.007))
    ephem = ephem_lin + ephem_orb

    @info "Linear prediction:" julian2datetime(ephem_lin)
    @info "Additional travel time from binary (minutes)" ephem_orb * 1440
    @info "Full prediction:" julian2datetime(ephem)
end

# Linear prediction: 2026-02-21T22:53:14.150
# Additional travel time from binary (minutes): 5.9416804304843955
# Full prediction: 2026-02-21T22:59:10.651
# 
# This appears to be an empirical approximation that they use. We could always do better by considering the elliptical motion of Sz Lyn about its barycenter based on updated orbital elements from, e.g., Table 3 Gazeas+ 2004, and also by accounting for the slight slowing in the pulsation period over time (discussed there as well, much smaller contribution than we can readily measure), but I think this is plenty precise enough as-is. Was a fun rabbit hole!
```
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.12.6"
manifest_format = "2.0"
project_hash = "71853c6197a6a7f222db0f1978c7cb232b87c5ee"

[deps]
"""

# ╔═╡ Cell order:
# ╟─1c24444a-4274-485a-91fa-9584be38a891
# ╟─193adfcc-3ab9-11f1-b7d0-5b93798eec02
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
