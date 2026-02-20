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
	global Do = "${projdir}/code/Stata/revenue_reporting" //dofiles
	global Input = "${projdir}/data/1_Raw/revenue_reporting" //raw data
	global Build = "${projdir}/data/2_Build/revenue_reporting" //temporary data
	global Final = "${projdir}/data/3_Final/revenue_reporting" //cleaned data
	global Out = "${projdir}/output/revenue_reporting" //cleaned data

	
*==============================================================================*
*																			   *
*	SECTION 01:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

	import excel "${Input}/Freetown/RDN/rdn_payments_2021_2025.xlsx", ///
		sheet("Page 1") cellrange(A4) firstrow clear
	save "${Build}/Freetown/RDN/FCC_revenue_RDN.dta", replace

*==============================================================================*
*																			   *
*	SECTION 02:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

*** Generate harmonized variables (to match with Edoardo's R cleaning) ***

use "${Build}/Freetown/RDN/FCC_revenue_RDN.dta", clear

*------------------------------------------------------------------------------*																	   
*	SUBSECTION 201:	Roster ID Variables										   *   																		   														                       													                       
*------------------------------------------------------------------------------*  

	rename *, lower
	rename propertycode property_code
	rename moptaxref moptax_ref
	rename bankref bank_ref
	codebook
	drop if property_code==""
	
	*Labelling
	label var ward Ward
	label var community Community
	
	replace bank = lower(bank)
	replace bank = "FCC" if strmatch(bank, "*freetown*") | strmatch(bank, "*consultant*") | strmatch(bank, "*support*")	
	replace bank = "Rokel Bank" if strmatch(bank, "*rokel*")
	replace bank = "EcoBank" if strmatch(bank, "*eco*")
	replace bank = "Zenith Bank" if strmatch(bank, "*zenith*")
	replace bank = "SLCB" if strmatch(bank, "*slc*")
	*replace bank = "Other" if strmatch(bank, "*consultant*") | strmatch(bank, "*support*")

	replace bank_ref = lower(bank_ref)
	replace bank_ref = "Rokel Bank" if strmatch(bank_ref, "*rokel*") | strmatch(bank_ref, "*rcb*") | strmatch(bank_ref, "*rc bank*") | strmatch(bank_ref, "*r c bank*") | strmatch(bank_ref, "*rco*") | strmatch(bank_ref, "*rcank*") | strmatch(bank_ref, "*f'char*") | strmatch(bank_ref, "*fchar*")
	replace bank_ref = "EcoBank" if strmatch(bank_ref, "*eco*") | strmatch(bank_ref, "*ec0*") | strmatch(bank_ref, "*ecc*") | strmatch(bank_ref, "*edco*") | strmatch(bank_ref, "*eobank*") | strmatch(bank_ref, "*ec o*") | strmatch(bank_ref, "*ecvo*")
	replace bank_ref = "Zenith Bank" if strmatch(bank_ref, "*zenith*") | strmatch(bank_ref, "*zen*") | strmatch(bank_ref, "*zn*") | strmatch(bank_ref, "*zei*")
	replace bank_ref = "SLCB" if strmatch(bank_ref, "*slcb*") | strmatch(bank_ref, "*s.l.*")
	replace bank_ref = "GTBank" if strmatch(bank_ref, "*gt*")
	replace bank_ref = "Access Bank" if strmatch(bank_ref, "*access*") | strmatch(bank_ref, "*standard*") | strmatch(bank_ref, "*scb*")
	replace bank_ref = "Skye Bank" if strmatch(bank_ref, "*sky*")
	replace bank_ref = "UTB" if strmatch(bank_ref, "*utb*") | strmatch(bank_ref, "*union*")
	replace bank_ref = "UBA" if strmatch(bank_ref, "*uba*")
	replace bank_ref = "Vista Bank" if strmatch(bank_ref, "*vista*") | strmatch(bank_ref, "*fib*") | strmatch(bank_ref, "*first*")
	replace bank_ref = "CMB" if strmatch(bank_ref, "*cmb*")
	replace bank_ref = "FCC" if strmatch(bank_ref, "*freetown*") | strmatch(bank_ref, "*fcc*")


	replace bank = bank_ref if bank =="" & bank_ref!=""
	replace bank = bank_ref if bank =="FCC" & bank_ref!=""
	replace bank = "FCC" if strmatch(bank, "*moptax*") | strmatch(bank, "*frettown*") 
	replace bank = "Other" if ( ///
		!strmatch(bank, "Access Bank") & !strmatch(bank, "EcoBank") & !strmatch(bank, "FCC") & ///
		!strmatch(bank, "Rokel Bank") & !strmatch(bank, "SLCB") & !strmatch(bank, "Zenith Bank"))
	replace bank = "Access Bank" if bank == "SLCB" & year(date) < 2025 //coding error in MopTax

	replace community = "Juba / Kaningo" if community =="Juba/Kaningo"
	replace community = "Malama / Kamayama" if community =="Malama/Kamayama" | community =="Malama / "
	replace community = "Cockle-Bay" if community =="Cockle-Bay / "
	replace community = "New England-Hill " if community =="New England-"
	replace community = "" if community =="null" 
	replace community = strtrim(community)

	keep date bank payment ward community
	gen type = "property"
	label var type "RDN or Business license"

save "${Build}/Freetown/RDN/FCC_revenue_RDN.dta", replace

*==============================================================================*
*																			   *
*	SECTION 01:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

	import excel "${Input}/Freetown/Business/business_license_payments_2021_2025.xlsx", ///
		sheet("Page 1") cellrange(A4) firstrow clear
	save "${Build}/Freetown/Business/FCC_revenue_business_license.dta", replace

*==============================================================================*
*																			   *
*	SECTION 02:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

*** Generate harmonized variables (to match with Edoardo's R cleaning) ***

use "${Build}/Freetown/Business/FCC_revenue_business_license.dta", clear

*------------------------------------------------------------------------------*																	   
*	SUBSECTION 201:	Roster ID Variables										   *   																		   														                       													                       
*------------------------------------------------------------------------------*  

	rename *, lower
	rename propertycode property_code
	rename moptaxref moptax_ref
	rename bankref bank_ref
	codebook
	drop if property_code==""
	
	*Labelling
	label var ward Ward
	label var community Community
	
	replace bank = lower(bank)
	replace bank = "FCC" if strmatch(bank, "*freetown*") | strmatch(bank, "*consultant*") | strmatch(bank, "*support*")	
	replace bank = "Rokel Bank" if strmatch(bank, "*rokel*")
	replace bank = "EcoBank" if strmatch(bank, "*eco*")
	replace bank = "Zenith Bank" if strmatch(bank, "*zenith*")
	replace bank = "SLCB" if strmatch(bank, "*slc*")
	replace bank = "Access Bank" if strmatch(bank, "*access*") | strmatch(bank, "*standard*") | strmatch(bank, "*scb*")
	*replace bank = "Other" if strmatch(bank, "*consultant*") | strmatch(bank, "*support*")

	replace bank_ref = lower(bank_ref)
	replace bank_ref = "Rokel Bank" if strmatch(bank_ref, "*rokel*") | strmatch(bank_ref, "*rcb*") | strmatch(bank_ref, "*rc bank*") | strmatch(bank_ref, "*r c bank*") | strmatch(bank_ref, "*rco*") | strmatch(bank_ref, "*rcank*") | strmatch(bank_ref, "*f'char*") | strmatch(bank_ref, "*fchar*")
	replace bank_ref = "EcoBank" if strmatch(bank_ref, "*eco*") | strmatch(bank_ref, "*ec0*") | strmatch(bank_ref, "*ecc*") | strmatch(bank_ref, "*edco*") | strmatch(bank_ref, "*eobank*") | strmatch(bank_ref, "*ec o*") | strmatch(bank_ref, "*ecvo*")
	replace bank_ref = "Zenith Bank" if strmatch(bank_ref, "*zenith*") | strmatch(bank_ref, "*zen*") | strmatch(bank_ref, "*zn*") | strmatch(bank_ref, "*zei*")
	replace bank_ref = "SLCB" if strmatch(bank_ref, "*slcb*") | strmatch(bank_ref, "*s.l.*")
	replace bank_ref = "GTBank" if strmatch(bank_ref, "*gt*")
	replace bank_ref = "Access Bank" if strmatch(bank_ref, "*access*") | strmatch(bank_ref, "*standard*") | strmatch(bank_ref, "*scb*")
	replace bank_ref = "Skye Bank" if strmatch(bank_ref, "*sky*")
	replace bank_ref = "UTB" if strmatch(bank_ref, "*utb*") | strmatch(bank_ref, "*union*")
	replace bank_ref = "UBA" if strmatch(bank_ref, "*uba*")
	replace bank_ref = "Vista Bank" if strmatch(bank_ref, "*vista*") | strmatch(bank_ref, "*fib*") | strmatch(bank_ref, "*first*")
	replace bank_ref = "CMB" if strmatch(bank_ref, "*cmb*")
	replace bank_ref = "FCC" if strmatch(bank_ref, "*freetown*") | strmatch(bank_ref, "*fcc*")

	replace bank = bank_ref if bank =="" & bank_ref!=""
	replace bank = bank_ref if bank =="FCC" & bank_ref!=""
	replace bank = "FCC" if strmatch(bank, "*moptax*") | strmatch(bank, "*frettown*") 
	replace bank = "Other" if ( ///
		!strmatch(bank, "Access Bank") & !strmatch(bank, "EcoBank") & !strmatch(bank, "FCC") & ///
		!strmatch(bank, "Rokel Bank") & !strmatch(bank, "SLCB") & !strmatch(bank, "Zenith Bank"))

	replace bank = "Access Bank" if bank == "SLCB" & year(date) < 2025 //coding error in MopTax

	replace community = "Juba / Kaningo" if community =="Juba/Kaningo"
	replace community = "Malama / Kamayama" if community =="Malama/Kamayama" | community =="Malama / "
	replace community = "Cockle-Bay" if community =="Cockle-Bay / "
	replace community = "New England-Hill " if community =="New England-"
	replace community = "" if community =="null" 
	replace community = strtrim(community)

	keep date bank payment ward community
	gen type = "business"
	label var type "RDN or Business license"

	
save "${Build}/Freetown/Business/FCC_revenue_business_license.dta", replace


*==============================================================================*
*																			   *
*	SECTION 01:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*


append using "${Build}/Freetown/RDN/FCC_revenue_RDN.dta"
save "${Final}/Freetown/FCC_revenue_analysis.dta", replace


*==============================================================================*
*																			   *
*	SECTION 01:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

	import excel "${Input}/Freetown/RDN/property_defaulters_14-Oct-2025.xlsx", ///
		sheet("Page 1") cellrange(A5) firstrow clear
	save "${Build}/Freetown/RDN/FCC_default_RDN.dta", replace
	keep Property Ward Description OutstandingLe		
	drop if OutstandingLe <= 25 
	drop if Property ==""
	drop Property
		gen type = "property"
	save "${Build}/Freetown/RDN/FCC_default_RDN.dta", replace

	
	import excel "${Input}/Freetown/Business/business_defaulters_14-Oct-2025.xlsx", ///
		sheet("Page 1") cellrange(A5) firstrow clear
	save "${Build}/Freetown/Business/FCC_default_business.dta", replace
	keep Property Ward OutstandingLe		
	drop if OutstandingLe <= 25 
	drop if Property ==""
	drop Property
		gen type = "business"
replace OutstandingLe = OutstandingLe / 1000 if OutstandingLe > 200000 & !missing(OutstandingLe)
	save "${Build}/Freetown/Business/FCC_default_business.dta", replace

append using "${Build}/Freetown/RDN/FCC_default_RDN.dta"
save "${Final}/Freetown/FCC_default_analysis.dta", replace
