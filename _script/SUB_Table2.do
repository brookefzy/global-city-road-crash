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

summarize(logfatality)
summarize(num_person_killed_per_lakh_city)

* Generate fixed effect parameter using continent
egen connum = group(continent)
tabulate continent, summarize(connum)
***********************************************
* Generate the policy fixed effect parameters


tabulate policy_cat
tabulate policy_year_cat

* Create numeric version
egen policynum = group(policy_cat), label
egen policyyear = group(policy_year_cat), label

* Check the actual numeric values assigned
tabulate policy_cat, summarize(policynum)

gen cluster_natural = cluster_2+cluster_6
global cvari_all cluster_natural cluster_4 cluster_5 cluster_0 cluster_3 cluster_1 diversity // built environment only
global cvari cluster_4 cluster_5 cluster_0 cluster_3 cluster_1 diversity
global exposure obj_person obj_bicycle obj_motorcycle obj_car obj_bus obj_truck
global exposure2 person_exposure bicycle_exposure motorcycle_exposure
global allvaris_plain $cvari_all $exposure num_person_killed_per_lakh road_injury_cap length_intersection_meter sprawl_sndi
global allvaries  $cvari_all $exposure sidewalk_presence logpop loggdp logflux center_lat center_lng

global cvari_100 cluster_0100 cluster_5100 cluster_3100 cluster_1100 cluster_4100 diversity

global allvaris_plain_summary cluster_natural100 $cvari_100 $exposure num_person_killed_per_lakh road_injury_cap length_intersection_meter sprawl_sndi

global logexposure_full logobj_person logobj_bicycle logobj_motorcycle logobj_bus logobj_car logobj_truck
global logcvari logcluster_4 logcluster_5 logcluster_0 logcluster_3 logcluster_1 logdiversity
global logexposure logobj_bicycle logobj_motorcycle logobj_bus logobj_truck
global seg sky road sidewalk building skyscraper
global controlv2 logpop logflux loggdp logroad_length i.policyyear
global controlv3 logpop logflux loggdp logroad_length i.policynum
global controlv logpop logflux loggdp logroad_length

// i.policyyear i.policynum

* Transform the variable
foreach v of varlist $exposure { 
    gen log`v' = log(`v'+0.000001)

}

foreach v of varlist $cvari_all{ 
	gen `v'100 = `v'*100
    gen log`v' = log(`v'100)
	
}



foreach v of varlist $seg {
	gen log`v' = log(`v')
	
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
label var logroad_length "Log(Road Length)"
label var num_person_killed_per_lakh "\# Person Killed (lakh)"

label var cluster_natural "Scenic View"
label var cluster_4 "Dense Road Core"
label var cluster_1 "High-rise Community"
label var cluster_0 "Open Arterials"
label var cluster_5 "Low-rise Community"
label var cluster_3 "Suburban Fringe"

label var cluster_natural "Scenic View"
label var cluster_4100 "Dense Road Core"
label var cluster_1100 "High-rise Community"
label var cluster_0100 "Open Arterials"
label var cluster_5100 "Low-rise Community"
label var cluster_3100 "Suburban Fringe"


label var logcluster_4 "Log(Dense Road Core)"
label var logcluster_1 "Log(High-rise Community)"
label var logcluster_0 "Log(Open Arterials)"
label var logcluster_5 "Log(Low-rise Community)"
label var logcluster_3 "Log(Suburban Fringe)"

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




////////////////////////////////////////////////////////////////////////
////// 1. simple data summary
//////////////////////////////////////////////////////////////////////////
eststo clear
eststo all_summary: estpost summarize $allvaris_plain_summary
esttab all_summary using "${savefile}/variable_summary_cluster=7_hex=9${comment}.tex", replace booktabs label ///
cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") ///
title(Summary Statistics)

esttab all_summary using "${savefile}/variable_summary_cluster=7_hex=9${comment}.csv", replace label ///
cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") ///
title(Summary Statistics)

////////////////////////////////////////////////////////////////////////
////// 2. Check variable correlation
//////////////////////////////////////////////////////////////////////////
corr logpop logflux loggdp $logcvari  $logexposure_full logroad_length

		 
////////////////////////////////////////////////////////////////////////
////// 1. Main regression results + Fixed Effects
/////////////////////////////////////////////////////////////////////////

eststo clear

* Predict road fatality with demographics
eststo seg1: reg logfatality $controlv2 i.connum, cluster(country_clean) // demo

* Predict road fatality with cluster types
eststo seg2: reg logfatality $cvari_100, cluster(country_clean) // cluster
* Predict road fatality with exposure factor proxy
eststo seg3: reg logfatality $logexposure_full, cluster(country_clean) // object

// eststo seg01a: reg logfatality logpop logflux loggdp $cvari, r
eststo seg12: reg logfatality $controlv2 $cvari_100 i.connum, cluster(country_clean) // demo+cluster
eststo seg23: reg logfatality $cvari_100 $logexposure, cluster(country_clean) // cluster+object

eststo seg13: reg logfatality $controlv2 $logexposure_full i.connum, cluster(country_clean) // demo+object

eststo seg123: reg logfatality $controlv2 $cvari_100 $logexposure i.connum, cluster(country_clean) // demo+cluster+object
vif
// Adding the full street view features
eststo svf1: reg logfatality $cvari_100  $logexposure_full, cluster(country_clean)
eststo svf2: reg logfatality $controlv2 $cvari_100  $logexposure_full i.connum, cluster(country_clean) // high multi-colinearity
vif

esttab seg1 seg2 seg3 seg12 seg13 svf1 svf2 using "${savefile}/road_fatality_built_env_res=9_cluster=7_fixed_effect_all_policy.csv", replace label plain r2
vif
// export tex for presentation in the paper
esttab seg1 seg12 seg123 svf1 svf2 using "${savefile}/road_fatality_built_env_res=9_cluster=7${comment}_fixed_effect_policy_year.tex", replace booktabs label ///
		 cells(b(star fmt(%9.3f)) se(par)) stats(N r2, fmt(%7.0f %7.4f) ///
		 labels("Observations" "R-squared")) starlevels(\sym{*} 0.05 \sym{**} 0.01 \sym{***} 0.005)
esttab seg1 seg12 seg123 svf1 svf2 using "${savefile}/road_fatality_built_env_res=9_cluster=7${comment}_fixed_effect_policy_year.csv", replace label r2 ///
		 cells(b(star fmt(%9.3f)) se(par)) stats(N r2, fmt(%7.0f %7.4f) ///
		 labels("Observations" "R-squared")) starlevels(\sym{*} 0.05 \sym{**} 0.01 \sym{***} 0.005)

		 
////////////////////////////////////////////////////////////////////////
////// 2. Add the SNDi
/////////////////////////////////////////////////////////////////////////


eststo clear
global controladd $controlv2 sprawl_sndi
* Predict road fatality with demographics
eststo seg1: reg logfatality $controladd i.connum, r // demo

* Predict road fatality with cluster types
eststo seg2: reg logfatality $cvari_100, r // cluster
* Predict road fatality with exposure factor proxy
eststo seg3: reg logfatality $logexposure_full, r // object

// eststo seg01a: reg logfatality logpop logflux loggdp $cvari, r
eststo seg12: reg logfatality $controladd $cvari_100 i.connum , r // demo+cluster
eststo seg23: reg logfatality $cvari_100 $logexposure, r // cluster+object

eststo seg13: reg logfatality $controladd $logexposure_full i.connum, r // demo+object

eststo seg123: reg logfatality $controladd $cvari_100 $logexposure i.connum, r // demo+cluster+object

// Adding the full street view features
eststo svf1: reg logfatality $cvari_100  $logexposure_full if sprawl_sndi!=., r
eststo svf2: reg logfatality $controladd $cvari_100  $logexposure_full i.connum, r // high multi-colinearity

esttab seg1 seg2 seg3 seg12 seg13 svf1 svf2 using "${savefile}/road_fatality_built_env_res=9_cluster=7_fixed_effect_all_sndi.csv", replace label plain r2
vif
// export tex for presentation in the paper
esttab seg1 seg12 seg123 svf1 svf2 using "${savefile}/road_fatality_built_env_res=9_cluster=7${comment}_fixed_effect_sndi.tex", replace booktabs label ///
		 cells(b(star fmt(%9.3f)) se(par)) stats(N r2, fmt(%7.0f %7.4f) ///
		 labels("Observations" "R-squared")) starlevels(\sym{*} 0.05 \sym{**} 0.01 \sym{***} 0.005)
esttab seg1 seg12 seg123 svf1 svf2 using "${savefile}/road_fatality_built_env_res=9_cluster=7${comment}_fixed_effect_sndi.csv", replace label r2 ///
		 cells(b(star fmt(%9.3f)) se(par)) stats(N r2, fmt(%7.0f %7.4f) ///
		 labels("Observations" "R-squared")) starlevels(\sym{*} 0.05 \sym{**} 0.01 \sym{***} 0.005)
vif
////////////////////////////////////////////////////////////////////////
** 3. Dynamic feature alone
////////////////////////////////////////////////////////////////////////
gen un_category_sum = "Others" if un_category!="HI" 
replace un_category_sum = "HI" if un_category == "HI"
eststo clear
eststo seg0: reg loggdp $logexposure_full, r
eststo seg1: reg logfatality $logexposure_full, r
eststo seg10: reg logfatality loggdp, r
eststo seg2: reg logfatality loggdp $logexposure_full, cluster(country_clean)
vif
eststo seg3: reg logfatality loggdp $logexposure_full if un_category_sum=="HI", r
eststo seg4: reg logfatality loggdp $logexposure_full if un_category_sum!="HI", r
esttab seg* using "${savefile}/dynamic_feature_reg.tex", replace booktabs label ///
		 cells(b(star fmt(%9.3f)) se(par)) stats(N r2, fmt(%7.0f %7.4f) ///
		 labels("Observations" "R-squared")) starlevels(\sym{*} 0.5 \sym{**} 0.1 \sym{***} 0.001)
		 
* Get public transit rate estimate
eststo clear
eststo segbus: reg public_transit_access_rate $logexposure_full, r
eststo segbus2: reg public_transit_access_rate $logexposure_full loggdp, r
esttab seg* using "${savefile}/dynamic_feature_reg_public_transit.tex", replace booktabs label ///
		 cells(b(star fmt(%9.3f)) se(par)) stats(N r2, fmt(%7.0f %7.4f) ///
		 labels("Observations" "R-squared")) starlevels(\sym{*} 0.5 \sym{**} 0.1 \sym{***} 0.001)
		 