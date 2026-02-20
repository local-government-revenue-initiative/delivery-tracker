********************************************************************************
********************************************************************************
* 	Filename:		0_Master.do
*	Description:	Setting_up LSMS-ISA Harmonised Panel Analysis Code. 
*  	Modified by:	Robin Benabid Jegaden (r.benabidjegaden@gmail.com)
*   Modified on:	11 Feb 2025
*	Stata version:	15.1
********************************************************************************
********************************************************************************

cap log close _all
clear all
set more off
*set maxvar 5000 //if needed
*set matsize 11000 //if needed
set type double
set trace off 
pause on //to keep to be able to define parameters

//Please add your directory below to reflect your system path. This will apply the path to all files.

* 0. Select user.
*****************

	if "`c(username)'" == "robin" {
		global projdir "D:/Dropbox/LoGRI/Sierra_Leone"
	}	

* 1. Global Pathways.
*********************
	global Do = "${projdir}/code/Stata" //dofiles
	global Input = "${projdir}/data/1_Raw" //raw data
	global Build = "${projdir}/data/2_Build" //temporary data
	global Final = "${projdir}/data/3_Final" //cleaned data

	
*==============================================================================*
*																			   *
*	SECTION 01:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

	* Importer et sauvegarder chaque fichier
	import excel "${Input}/Freetown/freetown_business_data.xlsx", firstrow clear
		replace area = "0" if area == "NULL"
		destring area, replace
		gen city_council ="freetown"
	save "${Build}/Freetown/freetown_business_data.dta", replace

	import excel "${Input}/Makeni/makeni_business_data.xlsx", firstrow clear
		gen city_council ="makeni"
	save "${Build}/Makeni/makeni_business_data.dta", replace

	import excel "${Input}/Kenema/kenema_business_data.xlsx", firstrow clear
		gen city_council ="kenema"
	save "${Build}/Kenema/kenema_business_data.dta", replace

	* Recharger la première base (Freetown) et y ajouter les autres
	use "${Build}/Freetown/freetown_business_data.dta", clear
	append using "${Build}/Makeni/makeni_business_data.dta"
	append using "${Build}/Kenema/kenema_business_data.dta"

	* Sauvegarder la base fusionnée
	save "${Final}/SL_business_data.dta", replace

*==============================================================================*
*																			   *
*	SECTION 02:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

*** Generate harmonized variables (to match with Edoardo's R cleaning) ***

use "${Final}/SL_business_data.dta", clear

*------------------------------------------------------------------------------*																	   
*	SUBSECTION 201:	Roster ID Variables										   *   																		   														                       													                       
*------------------------------------------------------------------------------*  

drop if area == 0 

sum area, detail

gen log_area = log10(area + 1)
histogram log_area, bin(50) name(hist_log, replace) ///
    title("Distribution log des surfaces")

levelsof city_council, local(cities)

foreach city in `cities' {
    di _newline(2) "======================================"
    di "CITY: `city'" 
    di "======================================"
    
    centile area if city_council == "`city'", ///
        centile(5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 98 99)
}

* Version minimale pour tester
levelsof city_council, local(cities)
foreach city in `cities' {
    di _newline "=== " upper("`city'") " ==="
    
    * Juste les percentiles clés avec variations
    quietly _pctile area if city_council == "`city'", p(42 85 98 100)
    local p42 = r(r1)
    local p85 = r(r2)
    local p98 = r(r3)
    local p100 = r(r4)
    
    di "p42: " round(`p42', 1)
    di "p85: " round(`p85', 1) " (+" round(((`p85'-`p42')/`p42')*100, 1) "% vs P10)"
    di "p85: " round(`p98', 1) " (+" round(((`p98'-`p85')/`p85')*100, 1) "% vs P35)"
    di "p100: " round(`p100', 1) " (+" round(((`p100'-`p98')/`p98')*100, 1) "% vs P65)"
}


* Préserve
preserve

levelsof city_council, local(cities)

tempfile pctsum
tempname mem2
postfile `mem2' str60 city p5 p25 p50 p75 p95 using "`pctsum'", replace

foreach city of local cities {
    quietly centile area if city_council == "`city'", centile(5 25 50 75 95)
    post `mem2' ("`city'") (r(c_1)) (r(c_2)) (r(c_3)) (r(c_4)) (r(c_5))
}
postclose `mem2'
use "`pctsum'", clear

* Encodage pour tracer sur l’axe des x
encode city, gen(city_id)

* Graphique : barres + médiane
twoway ///
 (rcap p95 p5 city_id,  lwidth(vthin)) ///
 (rcap p75 p25 city_id, lwidth(medthick)) ///
 (scatter p50 city_id,  msize(small) msymbol(O)), ///
    xtitle("") ytitle("area") ///
    xlabel(, valuelabel angle(30)) ///
    legend(order(1 "5–95" 2 "25–75 (IQR)" 3 "médiane") pos(6) ring(0)) ///
    title("Distribution d'area par ville (centiles)")

restore


