**********************************************************************
*AUTHOR: Zhuangyuan Fan
*DATE CREATED: 3/27/2025
* For final submission
* short version of the 01_road_fatality_hex
**********************************************************************

set more off

clear all
* Set directory to location of data, better use the global path
global setting "../_data"
global project "${setting}/_data/_curated/c_analysis"
* REPLACE ALL OF THESE FOLDER FOR YOUR OWN PURPOSE
cd "${project}"
global graphic "${setting}/_graphics"
global supple_graphic "${setting}/_graphic/_supplemental/_raw"
global savefile "${setting}/_table"
global comment ""
import delimited using "${project}/c_city_built_environment_full_cluster=7_ncat=27${comment}.csv"

gen logpop = log(urban_pop)
gen loggdp = log(gdp_per_cap_country_2022)
gen logflux = log(total_flux)
gen logfatality = log(num_person_killed_per_lakh_city)
gen logfatality_c = log(num_person_killed_per_lakh_count)
gen logheart = log(cardiovascular_diseases_cap)
gen logmental = log(mental_and_substance_use_disorde)
gen logdiabetes = log(diabetes_mellitus_cap)
gen logroadinjury = log(road_injury_cap)
gen logroadinjury_teen = log(road_injury_514_cap)
gen logroadinjury_adult = log(road_injury_1529_cap)
gen logwazeacc = log(waze_accident_count+1)
replace waze_major_count =0 if (waze_accident_count!=.) & (waze_major_count ==.)
gen logwazemajor = log(waze_major_count+1)
drop if city_lower == "chicago" // data too sparse
drop if city_lower == "jalna" // only natural scene available in the city

* Generate fixed effect parameter using continent
egen connum = group(continent)
tabulate continent, summarize(connum)

gen cluster_natural = cluster_2+cluster_6
global cvari_all cluster_natural cluster_2 cluster_0 cluster_5 cluster_1 cluster_6 diversity // built environment only
global cvari cluster_4 cluster_5 cluster_0 cluster_3 cluster_1 diversity
global exposure obj_person obj_bicycle obj_motorcycle obj_car obj_bus obj_truck
global exposure2 person_exposure bicycle_exposure motorcycle_exposure
global allvaris_plain $cvari_all $exposure num_person_killed_per_lakh road_injury_cap length_intersection_meter sprawl_sndi
global allvaries  $cvari_all $exposure sidewalk_presence logpop loggdp logflux center_lat center_lng
global logexposure_full logobj_person logobj_bicycle logobj_motorcycle logobj_bus logobj_car logobj_truck
global logexposure logobj_bicycle logobj_motorcycle logobj_bus logobj_truck
global seg sky road sidewalk building skyscraper



* Transform the variable
foreach v of varlist $cvari $exposure { 
    gen log`v' = log(`v'+1)
}

foreach v of varlist $seg {
	gen log`v' = log(`v'+1)
}
gen logroad_length = log(length_intersection_meter)


label var logpop "Log(Pop)"
label var loggdp "Log(GDP)"
label var logflux "Log(CO2)"
label var logfatality "Log(\#Pers. Killed)"
label var logfatality_c "Log(\#Pers. Killed C.)"
label var logheart "Log(Daly Cardio. Cap)"
label var logmental "Log(Daly Mental. Cap)"
label var logdiabetes "Log(Daly Diabetes. Cap)"
label var logroadinjury "Log(Daly Road Injury)"
label var road_injury_cap "DALY Road Injury"
label var num_person_killed_per_lakh "\# Person Killed (lakh)"

label var cluster_natural "Scenic View"
label var cluster_4 "Dense Road"
label var cluster_1 "High-rise Community"
label var cluster_0 "Open Arterials"
label var cluster_5 "Fine-Grain Community"
label var cluster_3 "Suburban Fringe"

label var obj_person "\# Person"
label var obj_bicycle "\# Bicycle"
label var obj_bus "\# Bus"
label var obj_car "\# Car"
label var obj_motorcycle "\# Motorcycle"
label var obj_truck "\# Truck"
label var diversity "Cluster Diversity"
label var logobj_person "Log(Person)"
label var logobj_bicycle "Log(Bicycle)"
label var logobj_bus "Log(Bus)"
label var logobj_car "Log(Car)"
label var logobj_motorcycle "Log(Motorcycle)"
label var logobj_truck "Log(Truck)"
label var bicycle_exposure "Exp. Bicycle"
label var person_exposure "Exp. Person"
label var motorcycle_exposure "Exp. Motorcycle"
label var sprawl_sndi "SNDi"
label var length_intersection_meter "Mean(Road Length)"

corr logpop logflux loggdp $cvari  $logexposure $exposure2

////////////////////////////////////////////////////////////////////////
////// 1. simple data summary
//////////////////////////////////////////////////////////////////////////
eststo clear
eststo all_summary: estpost summarize $allvaris_plain
esttab all_summary using "${savefile}/variable_summary_cluster=7_hex=9${comment}.tex", replace booktabs label ///
cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") ///
title(Summary Statistics)


////////////////////////////////////////////////////////////////////////
////// 1. Main regression results + Fixed Effects (Equation 2)
//////////////////////////////////////////////////////////////////////////
eststo clear

* Predict road fatality with demographics
eststo seg1: reg logfatality logpop logflux loggdp i.connum, cluster(country_clean) // demo

eststo seg10: reg logfatality logpop logflux loggdp i.connum, cluster(country_clean) // demo

* Predict road fatality with cluster types
eststo seg2: reg logfatality $cvari i.connum, cluster(country_clean) // cluster
* Predict road fatality with exposure factor proxy
eststo seg3: reg logfatality $logexposure i.connum, cluster(country_clean) // object

eststo seg12: reg logfatality logpop logflux loggdp $cvari i.connum, cluster(country_clean) // demo+cluster
eststo seg23: reg logfatality $cvari $logexposure i.connum, cluster(country_clean) // cluster+object

eststo seg13: reg logfatality logpop logflux loggdp $logexposure i.connum, cluster(country_clean) // demo+object

eststo seg123: reg logfatality logpop logflux loggdp $cvari $logexposure i.connum, cluster(country_clean) // demo+cluster+object

esttab seg* using "${savefile}/road_fatality_built_env_res=9_cluster=7_fixed_effect_all.csv", replace label plain r2

eststo seg123b: reg logroadinjury logpop logflux loggdp $cvari , cluster(country_clean)
// Adding the full street view features
eststo svf1: reg logfatality $cvari  $logexposure_full, cluster(country_clean)
eststo svf2: reg logfatality logpop logflux loggdp $cvari  $logexposure_full i.connum, cluster(country_clean) // high multi-colinearity
// export tex for presentation in the paper
esttab seg1 seg12 seg123 svf1 svf2 using "${savefile}/road_fatality_built_env_res=9_cluster=7${comment}_fixed_effect.tex", replace booktabs label ///
		 cells(b(star fmt(%9.3f)) se(par)) stats(N r2, fmt(%7.0f %7.4f) ///
		 labels("Observations" "R-squared")) starlevels(\sym{*} 0.1 \sym{**} 0.05 \sym{***} 0.005)
esttab seg1 seg12 seg123 svf1 svf2 using "${savefile}/road_fatality_built_env_res=9_cluster=7${comment}_fixed_effect.csv", replace label r2 ///
		 cells(b(star fmt(%9.3f)) se(par)) stats(N r2, fmt(%7.0f %7.4f) ///
		 labels("Observations" "R-squared")) starlevels(\sym{*} 0.1 \sym{**} 0.05 \sym{***} 0.005)
//////////////////////////////////////////////////////////////////////////////////////
////// 2. Main regression results + Fixed Effects + Street Sprawling (Equation 4 and 5)
////////////////////////////////////////////////////////////////////////////////////////
eststo clear
eststo seg00: reg logfatality logpop logflux loggdp i.connum, cluster(country_clean)

label var logroad_length "Log(Network Density)"
eststo seg1: reg logfatality logroad_length i.connum, cluster(country_clean)
eststo seg2: reg logfatality logpop logflux loggdp $cvari $logexposure i.connum, cluster(country_clean)
eststo seg0: reg logfatality logpop logflux loggdp logroad_length i.connum, cluster(country_clean)
eststo seg12: reg logfatality logpop logflux loggdp logroad_length $cvari $logexposure i.connum, cluster(country_clean)

eststo seg00b: reg logfatality logpop logflux loggdp i.connum if sprawl_sndi!=. , cluster(country_clean)
eststo seg2b: reg logfatality logpop logflux loggdp $cvari $logexposure i.connum if sprawl_sndi!=. , cluster(country_clean)

eststo seg1b: reg logfatality sprawl_sndi i.connum if sprawl_sndi!=. , cluster(country_clean)
eststo seg0b: reg logfatality logpop logflux loggdp sprawl_sndi i.connum if sprawl_sndi!=., cluster(country_clean)
eststo seg12b: reg logfatality logpop logflux loggdp sprawl_sndi i.connum $cvari $logexposure if sprawl_sndi!=., cluster(country_clean)

esttab seg* using "${savefile}/road_fatality_built_env_sprawl${comment}.csv", replace wide plain r2
esttab seg0 seg2 seg12 seg0b seg2b seg12b using "${savefile}/roadfatality_sprawl_cluster=7${comment}.tex", replace booktabs label ///
		 cells(b(star fmt(%9.3f)) se(par)) stats(N r2, fmt(%7.0f %7.4f) ///
		 labels("Observations" "R-squared")) starlevels(\sym{*} 0.1 \sym{**} 0.05 \sym{***} 0.005)