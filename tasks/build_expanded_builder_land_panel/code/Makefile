SHELL := bash
include ../../shell_functions.make

all: ../output/expanded_builder_2004_2025_land_panel.csv ../output/expanded_builder_land_coverage_by_firm.csv ../output/expanded_builder_land_coverage_by_year.csv ../output/expanded_builder_land_plot_data.csv ../output/expanded_builder_land_review_queue.csv ../output/expanded_builder_land_gap_audit.csv

../output/expanded_builder_2004_2025_land_panel.csv: build_expanded_builder_land_panel.R ../../_lib/homebuilder_pipeline_utils.R ../input/builder_universe_sec_crosswalk.csv ../input/land_light_firm_year_measures.csv ../input/six_firm_2006_2025_manual_land_panel.csv ../input/tol_2004_2025_land_panel.csv ../input/mho_2004_2025_land_panel.csv ../input/mdc_2004_2025_land_panel.csv ../input/grbk_2014_2025_land_panel.csv ../input/grbk_prebuilder_filing_exclusions.csv ../input/mth_2004_2025_land_panel.csv ../input/tmhc_2013_2025_land_panel.csv ../input/tph_2012_2025_land_panel.csv ../input/nvr_2004_2009_early_land_panel.csv ../input/lsea_2020_2024_land_panel.csv ../input/lsea_2018_2019_prebuilder_filing_exclusions.csv ../input/dfh_2020_2025_land_panel.csv ../input/sdhc_2022_2025_land_panel.csv ../input/uhg_2022_2025_land_panel.csv ../input/uhg_2020_2021_prebuilder_filing_exclusions.csv ../input/tier1_early_2004_2005_land_panel.csv ../input/ctx_2004_2009_land_panel.csv ../input/toa_2004_2007_land_panel.csv ../input/ohb_2004_2008_land_panel.csv ../input/ucp_2013_2016_land_panel.csv ../input/dhom_2004_2007_land_panel.csv ../input/bhs_2004_2010_land_panel.csv ../input/wci_2004_2015_land_panel.csv ../input/nwhm_2013_2020_land_panel.csv ../input/ryl_2004_2014_land_panel.csv ../input/avhi_2004_2017_land_panel.csv ../input/wlh_2004_2018_land_panel.csv ../input/spf_caa_2004_2016_land_panel.csv ../input/chci_2006_2016_land_panel.csv ../input/lev_2004_2007_land_panel.csv | ../output
	$(R) $<

../output/expanded_builder_land_coverage_by_firm.csv: ../output/expanded_builder_2004_2025_land_panel.csv
	@test -s "$@"

../output/expanded_builder_land_coverage_by_year.csv: ../output/expanded_builder_2004_2025_land_panel.csv
	@test -s "$@"

../output/expanded_builder_land_plot_data.csv: ../output/expanded_builder_2004_2025_land_panel.csv
	@test -s "$@"

../output/expanded_builder_land_review_queue.csv: ../output/expanded_builder_2004_2025_land_panel.csv
	@test -s "$@"

../output/expanded_builder_land_gap_audit.csv: ../output/expanded_builder_2004_2025_land_panel.csv
	@test -s "$@"

../input/builder_universe_sec_crosswalk.csv: ../../stage_builder_universe_roster/output/builder_universe_sec_crosswalk.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/land_light_firm_year_measures.csv: ../../build_land_light_measures/output/land_light_firm_year_measures.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/six_firm_2006_2025_manual_land_panel.csv: ../../build_six_firm_manual_land_panel/output/six_firm_2006_2025_manual_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tol_2004_2025_land_panel.csv: ../../extract_tol_land_disclosures/output/tol_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/mho_2004_2025_land_panel.csv: ../../extract_mho_land_disclosures/output/mho_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/mdc_2004_2025_land_panel.csv: ../../extract_mdc_land_disclosures/output/mdc_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/grbk_2014_2025_land_panel.csv: ../../extract_grbk_land_disclosures/output/grbk_2014_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/grbk_prebuilder_filing_exclusions.csv: ../../extract_grbk_land_disclosures/output/grbk_prebuilder_filing_exclusions.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/mth_2004_2025_land_panel.csv: ../../extract_mth_land_disclosures/output/mth_2004_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tmhc_2013_2025_land_panel.csv: ../../extract_tmhc_land_disclosures/output/tmhc_2013_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tph_2012_2025_land_panel.csv: ../../extract_tph_land_disclosures/output/tph_2012_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/nvr_2004_2009_early_land_panel.csv: ../../extract_nvr_early_land_disclosures/output/nvr_2004_2009_early_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/lsea_2020_2024_land_panel.csv: ../../extract_lsea_land_disclosures/output/lsea_2020_2024_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/lsea_2018_2019_prebuilder_filing_exclusions.csv: ../../extract_lsea_land_disclosures/output/lsea_2018_2019_prebuilder_filing_exclusions.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/dfh_2020_2025_land_panel.csv: ../../extract_dfh_land_disclosures/output/dfh_2020_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/sdhc_2022_2025_land_panel.csv: ../../extract_sdhc_land_disclosures/output/sdhc_2022_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/uhg_2022_2025_land_panel.csv: ../../extract_uhg_land_disclosures/output/uhg_2022_2025_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/uhg_2020_2021_prebuilder_filing_exclusions.csv: ../../extract_uhg_land_disclosures/output/uhg_2020_2021_prebuilder_filing_exclusions.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/tier1_early_2004_2005_land_panel.csv: ../../extract_tier1_early_land_disclosures/output/tier1_early_2004_2005_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/ctx_2004_2009_land_panel.csv: ../../extract_centex_land_disclosures/output/ctx_2004_2009_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/toa_2004_2007_land_panel.csv: ../../extract_tousa_land_disclosures/output/toa_2004_2007_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/ohb_2004_2008_land_panel.csv: ../../extract_orleans_land_disclosures/output/ohb_2004_2008_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/ucp_2013_2016_land_panel.csv: ../../extract_ucp_land_disclosures/output/ucp_2013_2016_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/dhom_2004_2007_land_panel.csv: ../../extract_dominion_land_disclosures/output/dhom_2004_2007_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/bhs_2004_2010_land_panel.csv: ../../extract_brookfield_homes_land_disclosures/output/bhs_2004_2010_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/wci_2004_2015_land_panel.csv: ../../extract_wci_land_disclosures/output/wci_2004_2015_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/nwhm_2013_2020_land_panel.csv: ../../extract_new_home_company_land_disclosures/output/nwhm_2013_2020_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/ryl_2004_2014_land_panel.csv: ../../extract_ryland_land_disclosures/output/ryl_2004_2014_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/avhi_2004_2017_land_panel.csv: ../../extract_av_homes_land_disclosures/output/avhi_2004_2017_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/wlh_2004_2018_land_panel.csv: ../../extract_william_lyon_land_disclosures/output/wlh_2004_2018_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/spf_caa_2004_2016_land_panel.csv: ../../extract_standard_pacific_calatlantic_land_disclosures/output/spf_caa_2004_2016_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/chci_2006_2016_land_panel.csv: ../../extract_comstock_land_disclosures/output/chci_2006_2016_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

../input/lev_2004_2007_land_panel.csv: ../../extract_levitt_land_disclosures/output/lev_2004_2007_land_panel.csv | ../input
	@test "$$(readlink "$@")" = "$<" || ln -sf "$<" "$@"

link-inputs: ../input/builder_universe_sec_crosswalk.csv ../input/land_light_firm_year_measures.csv ../input/six_firm_2006_2025_manual_land_panel.csv ../input/tol_2004_2025_land_panel.csv ../input/mho_2004_2025_land_panel.csv ../input/mdc_2004_2025_land_panel.csv ../input/grbk_2014_2025_land_panel.csv ../input/grbk_prebuilder_filing_exclusions.csv ../input/mth_2004_2025_land_panel.csv ../input/tmhc_2013_2025_land_panel.csv ../input/tph_2012_2025_land_panel.csv ../input/nvr_2004_2009_early_land_panel.csv ../input/lsea_2020_2024_land_panel.csv ../input/lsea_2018_2019_prebuilder_filing_exclusions.csv ../input/dfh_2020_2025_land_panel.csv ../input/sdhc_2022_2025_land_panel.csv ../input/uhg_2022_2025_land_panel.csv ../input/uhg_2020_2021_prebuilder_filing_exclusions.csv ../input/tier1_early_2004_2005_land_panel.csv ../input/ctx_2004_2009_land_panel.csv ../input/toa_2004_2007_land_panel.csv ../input/ohb_2004_2008_land_panel.csv ../input/ucp_2013_2016_land_panel.csv ../input/dhom_2004_2007_land_panel.csv ../input/bhs_2004_2010_land_panel.csv ../input/wci_2004_2015_land_panel.csv ../input/nwhm_2013_2020_land_panel.csv ../input/ryl_2004_2014_land_panel.csv ../input/avhi_2004_2017_land_panel.csv ../input/wlh_2004_2018_land_panel.csv ../input/spf_caa_2004_2016_land_panel.csv ../input/chci_2006_2016_land_panel.csv ../input/lev_2004_2007_land_panel.csv

include ../../generic.make
