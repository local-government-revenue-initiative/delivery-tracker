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

	import excel "${Input}/Makeni/RDN/property_rates_payments.xlsx", ///
		firstrow clear
	save "${Build}/Makeni/RDN/MCC_revenue_RDN.dta", replace

*==============================================================================*
*																			   *
*	SECTION 02:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

use "${Build}/Makeni/RDN/MCC_revenue_RDN.dta", clear

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

	replace bank = "Rokel Bank" if strmatch(bank, "*rcb*")
	replace bank = "Afrimoney" if strmatch(bank, "*afrimoney*")
	replace bank = "Monime" if strmatch(bank, "*monime*")
	replace bank = "Other" if strmatch(bank, "*michael*")
	

	rename paymentdate date
	rename paymentamount payment
	keep property_code date bank payment
	gen type = "property"
	label var type "RDN or Business license"

	save "${Build}/Makeni/RDN/MCC_revenue_RDN.dta", replace


*==============================================================================*
*																			   *
*	SECTION 01:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

	import excel "${Input}/Makeni/Business/business_license_payments.xlsx", ///
					firstrow clear
	save "${Build}/Makeni/Business/MCC_revenue_business_license.dta", replace

*==============================================================================*
*																			   *
*	SECTION 02:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*

*** Generate harmonized variables (to match with Edoardo's R cleaning) ***

use "${Build}/Makeni/Business/MCC_revenue_business_license.dta", clear

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
	
	replace bank = "Rokel Bank" if strmatch(bank, "*rcb*")
	replace bank = "Afrimoney" if strmatch(bank, "*afrimoney*")
	replace bank = "Monime" if strmatch(bank, "*monime*")
	replace bank = "Other" if strmatch(bank, "*michael*") | strmatch(bank, "*api*") | strmatch(bank, "*sheku*")

	rename payment_amount payment
	keep license_code property_code date bank payment total_payable business_category business_subcategory
	gen type = "business"
	label var type "RDN or Business license"

save "${Build}/Makeni/Business/MCC_revenue_business_license.dta", replace

*==============================================================================*
*																			   *
*	SECTION 03:	Generating Input Variables									   *
*																			   *														                       													                       
*==============================================================================*


append using "${Build}/Makeni/RDN/MCC_revenue_RDN.dta"
save "${Final}/Makeni/MCC_revenue_analysis.dta", replace

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
