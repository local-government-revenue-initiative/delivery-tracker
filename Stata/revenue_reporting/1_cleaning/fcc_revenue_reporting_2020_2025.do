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

	import excel "${Input}/Freetown/RDN/rdn_payments_1900_2025_12.xlsx", ///
		firstrow clear
	save "${Build}/Freetown/RDN/FCC_revenue_RDN_December.dta", replace

*==============================================================================*
*																			   *
*	SECTION 02:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

use "${Build}/Freetown/RDN/FCC_revenue_RDN_December.dta", clear

*------------------------------------------------------------------------------*																	   
*	SUBSECTION 201:	Roster ID Variables										   *   																		   														                       													                       
*------------------------------------------------------------------------------*  

	rename *, lower
	rename propertycode property_code
	rename operator bank
	rename transactionid bank_ref
	drop payablereferenceid street streetnumber
	*codebook
	drop if property_code==""
	replace bank = lower(bank)
	replace bank_ref = lower(bank_ref)
	replace paymentnotes = lower(paymentnotes)

	replace bank = "Rokel Bank" if strmatch(bank, "*rokel*")
	replace bank = "Eco Bank" if strmatch(bank, "*eco*")
	replace bank = "Zenith Bank" if strmatch(bank, "*zenith*")
	replace bank = "SLCB" if strmatch(bank, "*slcb*")
	replace bank = "" if bank != "Rokel Bank" & bank != "Eco Bank" & bank != "Zenith Bank" & bank != "SLCB"
	replace bank = bank_ref if bank == "" & bank_ref != ""
	replace bank = "Rokel Bank" if strmatch(bank, "*rokel*") | strmatch(bank, "*rcb*") | strmatch(bank, "*rc bank*")
	replace bank = "Eco Bank" if strmatch(bank, "*eco*")
	replace bank = "Zenith Bank" if strmatch(bank, "*zenith*") | strmatch(bank, "*zen*")
	replace bank = "SLCB" if strmatch(bank, "*slcb*") | strmatch(bank, "*slc*") | strmatch(bank, "*s.l*")
	replace bank = "Access Bank" if bank == "SLCB" & paymentdate < td(01jul2025) //coding error in MopTax
	replace bank = "FCC" if strmatch(bank, "*city council*") | strmatch(bank, "*cmb*") | strmatch(bank, "*fcc*")
	replace bank = "Access Bank" if strmatch(bank, "*access*") | strmatch(bank_ref, "*standard*") | strmatch(bank_ref, "*scb*")
	replace bank = "Afrimoney" if strmatch(bank, "*afrimoney*")
	replace bank = "GTBank" if strmatch(bank, "*gt*")
	replace bank = "Skye Bank" if strmatch(bank_ref, "*sky*")
	replace bank = "UTB" if strmatch(bank, "*utb*") | strmatch(bank, "*union*")
	replace bank = "UBA" if strmatch(bank, "*uba*")
	replace bank = "First Bank" if strmatch(bank, "*first*")
	replace bank = "Star Afrik Bank" if strmatch(bank, "*star*")
	replace bank = "FCC" if bank != "Rokel Bank" & bank != "Eco Bank" & bank != "Zenith Bank" & bank != "SLCB" & bank != "FCC" & bank != "Access Bank" & bank != "Afrimoney" & bank != "GTBank" ///
							& bank != "Skye Bank" & bank != "UTB" & bank != "UBA" & bank != "First Bank" & bank != "Star Afrik Bank"
	replace bank = "Other" if ( ///
		!strmatch(bank, "Access Bank") & !strmatch(bank, "Eco Bank") & !strmatch(bank, "FCC") & ///
		!strmatch(bank, "Rokel Bank") & !strmatch(bank, "Zenith Bank"))

	rename paymentdate date
	rename paymentamount payment
	keep property_code date bank payment
	gen type = "property"
	label var type "RDN or Business license"

save "${Build}/Freetown/RDN/FCC_revenue_RDN_December.dta", replace


*==============================================================================*
*																			   *
*	SECTION 01:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

	import excel "${Input}/Freetown/Business/business_license_payments_1900_2025_12.xlsx", ///
					firstrow clear
	save "${Build}/Freetown/Business/FCC_revenue_business_license_December.dta", replace

*==============================================================================*
*																			   *
*	SECTION 02:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

*** Generate harmonized variables (to match with Edoardo's R cleaning) ***

use "${Build}/Freetown/Business/FCC_revenue_business_license_December.dta", clear

*------------------------------------------------------------------------------*																	   
*	SUBSECTION 201:	Roster ID Variables										   *   																		   														                       													                       
*------------------------------------------------------------------------------*  

	rename *, lower
	rename licensecode license_code
	rename associatedproperty property_code
	rename operator bank
	rename transactionid bank_ref
	keep paymentdate license_code bank_ref totalpayable paymentamount property_code businesscategory businesssubcategory bank
	rename paymentdate date
	rename totalpayable total_payable
	rename paymentamount payment_amount
	rename businesscategory business_category
	rename businesssubcategory business_subcategory
*codebook
	drop if license_code==""
	replace bank = lower(bank)
	replace bank_ref = lower(bank_ref)
	

	replace bank = "Rokel Bank" if strmatch(bank, "*rokel*")
	replace bank = "Eco Bank" if strmatch(bank, "*eco*")
	replace bank = "Zenith Bank" if strmatch(bank, "*zenith*")
	replace bank = "SLCB" if strmatch(bank, "*slcb*")
	replace bank = "" if bank != "Rokel Bank" & bank != "Eco Bank" & bank != "Zenith Bank" & bank != "SLCB"
	replace bank = bank_ref if bank == "" & bank_ref != ""
	replace bank = "Rokel Bank" if strmatch(bank, "*rokel*") | strmatch(bank, "*rcb*") | strmatch(bank, "*rc bank*")
	replace bank = "Eco Bank" if strmatch(bank, "*eco*")
	replace bank = "Zenith Bank" if strmatch(bank, "*zenith*") | strmatch(bank, "*zen*")
	replace bank = "SLCB" if strmatch(bank, "*slcb*") | strmatch(bank, "*slc*") | strmatch(bank, "*s.l*")
	replace bank = "Access Bank" if bank == "SLCB" & date < td(01jul2025) //coding error in MopTax
	replace bank = "FCC" if strmatch(bank, "*city council*") | strmatch(bank, "*cmb*") | strmatch(bank, "*fcc*")
	replace bank = "Access Bank" if strmatch(bank, "*access*") | strmatch(bank_ref, "*standard*") | strmatch(bank_ref, "*scb*")
	replace bank = "Afrimoney" if strmatch(bank, "*afrimoney*")
	replace bank = "GTBank" if strmatch(bank, "*gt*")
	replace bank = "Skye Bank" if strmatch(bank_ref, "*sky*")
	replace bank = "UTB" if strmatch(bank, "*utb*") | strmatch(bank, "*union*")
	replace bank = "UBA" if strmatch(bank, "*uba*")
	replace bank = "Vista Bank" if strmatch(bank, "*vista*")
	replace bank = "Keystone Bank" if strmatch(bank, "*keystone*")
	replace bank = "First Bank" if strmatch(bank, "*first*") | strmatch(bank, "*fnb*")
	replace bank = "Star Afrik Bank" if strmatch(bank, "*star*")
	replace bank = "FCC" if bank != "Rokel Bank" & bank != "Eco Bank" & bank != "Zenith Bank" & bank != "SLCB" & bank != "FCC" & bank != "Access Bank" & bank != "Afrimoney" & bank != "GTBank" ///
							& bank != "Skye Bank" & bank != "UTB" & bank != "UBA" & bank != "First Bank" & bank != "Star Afrik Bank"
	replace bank = "Other" if ( ///
		!strmatch(bank, "Access Bank") & !strmatch(bank, "Eco Bank") & !strmatch(bank, "FCC") & ///
		!strmatch(bank, "Rokel Bank") & !strmatch(bank, "Zenith Bank"))

	rename payment_amount payment
	keep license_code property_code date bank payment total_payable business_category business_subcategory
	gen type = "business"
	label var type "RDN or Business license"

save "${Build}/Freetown/Business/FCC_revenue_business_license_December.dta", replace







*==============================================================================*
*																			   *
*	SECTION 03:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*
replace date = td(05may2022) if payment == 211 & property_code == "FCC0049435"
replace date = td(30jun2025) if payment == 842 & property_code == "FCC0006935"

append using "${Build}/Freetown/RDN/FCC_revenue_RDN_December.dta"
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
