## Script for making excel file of climate aid and climaet finance
## Using multiple data soruces from noradstats@gmail.com. Sourcing get_data.R and norfund.
## Written by Einar Tornes

# Load packages and data ----
library(tidyverse)
library(janitor)
library(noradstats)
library(here)
library(readxl)
library(writexl)

#devtools::install_github("einartornes/noradstats", force = TRUE)

# # Download data
source(here("src", "get_data.R"))

# Norfund data from separate script
source(here("src" ,"norfund.R"))

# Imputed data from separate script
source(here("src" ,"get_imputed.R"))

# Laster ned data på imputed shares og Norfund
df_multi <- read_csv(here("output", "imputed_multilateral_climate.csv"))

df_norfund <- read_csv(here("output/df_norfund.csv"))

# ODA data
df_orig <- read_aiddata(here("data", "statsys_ten.csv"))

df_oda <- noradstats::add_cols_climate(df_orig)

df_oda <- noradstats::add_cols_climate(df_orig) %>%
  janitor::clean_names() %>%
  filter(type_of_flow == "ODA") %>%
  filter(type_of_agreement != "Rammeavtale") %>%
  filter(year >= 2014)

df_oda_oof <- noradstats::add_cols_climate(df_orig) %>%
  janitor::clean_names() %>%
  filter(type_of_flow == "ODA" | type_of_flow == "OOF" & extending_agency == "Norfund") %>%
  filter(type_of_agreement != "Rammeavtale") %>%
  filter(year >= 2014)

rm(df_orig)
# Total climate ODA -------------------------------------------------------

# Earmarked climate aid ex. Norfund
df_earmarked_ex_nf <- df_oda %>%
  group_by(year) %>%
  summarise(mnok = sum(climate_aid_nok_mill)) %>%
  ungroup() %>%
  add_column("channel" = "Earmarked climate aid (ex. Norfund)")

# Norfund capitalisation climate share
df_norfund_cap <- df_norfund %>%
  filter(year >= 2014) %>%
  select(year, mitigation_share_capitalisation_2yr_avg_mnok) %>%
  add_column("channel" = "Norfund capitalisation (climate share)") %>%
  rename("mnok" = mitigation_share_capitalisation_2yr_avg_mnok)

# Multilateral climate aid
df_multi_total <- df_multi %>%
  filter(!is.na(climate_aid_mnok)) |> 
  filter(year >= 2014) %>%
  mutate(year = as.numeric(year)) %>%
  group_by(year) %>%
  summarise(mnok = sum(climate_aid_mnok)) %>%
  ungroup() %>%
  add_column("channel" = "Imputed multialteral climate share")

# Bind data frames
df_total <- bind_rows(df_earmarked_ex_nf, df_norfund_cap, df_multi_total)

# Table format
df_total_tbl <- df_total %>%
  pivot_wider(names_from = "year", values_from = "mnok") %>%
  adorn_totals("row", name = "Total climate aid")

rm(df_earmarked_ex_nf, df_multi_total)


# Adaptation and mitigation -----------------------------------------------------

df_adaptation <- df_oda %>%
  group_by(year) %>%
  summarise(mnok = sum(climate_adaptation_nok_mill)) %>%
  ungroup() %>%
  add_column("climate_aid_type" = "Adaptation")

df_mitigation <- df_oda %>%
  group_by(year) %>%
  summarise(mnok = sum(climate_mitigation_nok_mill)) %>%
  ungroup() %>%
  add_column("climate_aid_type" = "Mitigation")

df_mitigation <- bind_rows(df_mitigation, df_norfund_cap)

df_mitigation <- df_mitigation %>%
  group_by(year) %>%
  summarise(mnok = sum(mnok)) %>%
  add_column("climate_aid_type" = "Mitigation")

df_climate_aid_type <- bind_rows(df_adaptation, df_mitigation)

df_climate_aid_type_tbl <- df_climate_aid_type %>%
  pivot_wider(names_from = "year", values_from = "mnok")

rm(df_adaptation, df_mitigation)

# Share of earmarked aid
df_total_earmarked <- df_oda %>%
  filter(type_of_assistance %in% c("Bilateral", "Earmarked to multilaterals", "Triangular co-operation")) %>%
  group_by(year) %>%
  summarise(total_earmarked = sum(disbursed_mill_nok))

df_climate_aid_type_pst <- left_join(df_climate_aid_type, df_total_earmarked, by = "year")
df_climate_aid_type_pst <- df_climate_aid_type_pst %>%
  mutate(pst_of_earmarked = mnok / total_earmarked) %>%
  select(year, climate_aid_type, pst_of_earmarked)

df_climate_aid_type_pst_tbl <- df_climate_aid_type_pst %>%
  pivot_wider(names_from = "year", values_from = "pst_of_earmarked")

# Adaptation, mitigation, cross-cutting -----------------------------------

df_climate_aid_type_3levels <- df_oda %>%
  filter(climate_aid_type != "None") %>%
  group_by(climate_aid_type, year) %>%
  summarise(mnok = sum(climate_aid_nok_mill)) %>%
  ungroup()

df_norfund_cap_type <- df_norfund_cap %>%
  mutate(climate_aid_type = "Mitigation") %>%
  select(year, climate_aid_type, mnok)

df_climate_aid_type_3levels <- bind_rows(df_climate_aid_type_3levels, df_norfund_cap_type)

df_climate_aid_type_3levels <- df_climate_aid_type_3levels %>%
  group_by(year, climate_aid_type) %>%
  summarise(mnok = sum(mnok)) %>%
  ungroup()


df_climate_aid_type_3levels_tbl <- df_climate_aid_type_3levels %>%
  pivot_wider(names_from = "year", values_from = "mnok") %>%
  mutate(climate_aid_type = fct_relevel(climate_aid_type, "Adaptation", "Mitigation", "Cross-cutting")) %>%
  arrange(climate_aid_type) %>%
  adorn_totals("row", name = "Total earmarked climate aid")


# Share of earmarked aid
df_climate_aid_type_3levels_pst <- left_join(df_climate_aid_type_3levels, df_total_earmarked, by = "year")

df_climate_aid_type_3levels_pst <- df_climate_aid_type_3levels_pst %>%
  mutate(pst_of_earmarked = mnok / total_earmarked) %>%
  select(year, climate_aid_type, pst_of_earmarked)

df_climate_aid_type_3levels_pst_tbl <- df_climate_aid_type_3levels_pst %>%
  pivot_wider(names_from = "year", values_from = "pst_of_earmarked") %>%
  mutate(climate_aid_type = fct_relevel(climate_aid_type, "Adaptation", "Mitigation", "Cross-cutting")) %>%
  arrange(climate_aid_type)

# Climate finance (UNFCCC-metholology) ---------------------------------------------------------

# Earmarked climate aid ex. Norfund
# Making sure to exclude the capitalisation of Norfund CIF as it is mitigation marked
df_earmarked_gross_ex_nf <- df_oda %>%
  filter(agreement_number != "QZA-22/0133") |> 
  group_by(year) %>%
  summarise(mnok = sum(climate_aid_nok_gross_fix) / 1e6) %>%
  ungroup() %>%
  add_column("channel" = "Earmarked climate finance (ex. Norfund)")


# Norfund (DIM and CIM) estimated climate investments (both adaptation or mitigation).
df_norfund_climate_finance <- df_oda_oof %>%
  filter(type_of_flow == "OOF") %>%
  filter(type_of_assistance != "Administration") %>%
  filter(extending_agency == "Norfund") %>%
  filter(year >= 2014) %>%
  group_by(year) %>%
  summarise(total_gross_climate_investment_mnok = sum(climate_aid_nok_gross_fix / 1e6)) |> 
  add_column("channel" = "Norfund investments (climate share)") |> 
  rename("mnok" = "total_gross_climate_investment_mnok")

# Multilateral climate aid
df_multi_total <- df_multi %>%
  filter(!is.na(climate_aid_mnok)) |> 
  filter(year >= 2014) %>%
  mutate(year = as.numeric(year)) %>%
  group_by(year) %>%
  summarise(mnok = sum(climate_aid_mnok)) %>%
  ungroup() %>%
  add_column("channel" = "Imputed multialteral climate share")

# Bind data frames
df_total_gross <- bind_rows(df_earmarked_gross_ex_nf, df_norfund_climate_finance, df_multi_total)

# Table format
df_total_gross_tbl <- df_total_gross %>%
  pivot_wider(names_from = "year", values_from = "mnok") %>%
  adorn_totals("row", name = "Total climate finance")

rm(df_earmarked_gross_ex_nf, df_norfund_climate_finance, df_multi_total)

# Climate finance type (UNFCCC-methodology) adaptation, mitigation ----

# Mitigation: removing capitalisation of CIF as it is mitigation marked
df_mitigation_oda_oof <- df_oda_oof |>
  filter(agreement_number != "QZA-22/0133") |> 
  filter(year >= 2014) %>%
  group_by(year) |> 
  summarise(mnok = sum(climate_mitigation_nok_mill_gross_fix)) |> 
  add_column("climate_aid_type" = "Mitigation") %>%
  ungroup()

# Adaptation
df_adaptation_oda_oof <- df_oda_oof |>
  filter(agreement_number != "QZA-22/0133") |> 
  filter(year >= 2014) %>%
  group_by(year) |> 
  summarise(mnok = sum(climate_adaptation_nok_mill_gross_fix)) |> 
  add_column("climate_aid_type" = "Adaptation") %>%
  ungroup()

df_climate_aid_type_oda_oof <- bind_rows(df_adaptation_oda_oof, df_mitigation_oda_oof)

df_climate_aid_type_oda_oof_tbl <- df_climate_aid_type_oda_oof %>%
  pivot_wider(names_from = "year", values_from = "mnok")

rm(df_mitigation_oda_oof, df_adaptation_oda_oof)


# Climate finance type (UNFCCC-methodology) adaptation, mitigation, cross-cutting ----
df_climate_finance_type_3levels <- df_oda_oof %>%
  filter(agreement_number != "QZA-22/0133") |> 
  filter(climate_aid_type != "None") %>%
  filter(year >= 2014) %>%
  group_by(climate_aid_type, year) %>%
  summarise(mnok = sum(climate_aid_nok_gross_fix / 1e6)) %>%
  ungroup()

df_climate_finance_type_3levels_tbl <- df_climate_finance_type_3levels %>%
  pivot_wider(names_from = "year", values_from = "mnok") %>%
  mutate(climate_aid_type = fct_relevel(climate_aid_type, "Adaptation", "Mitigation", "Cross-cutting")) %>%
  arrange(climate_aid_type) %>%
  adorn_totals("row", name = "Total earmarked climate finance")

# Write tables to xlsx file ----------------------------------------------

if(file.exists(here("output")) == FALSE) {
  dir.create(here("output"))
}

write_xlsx(x = list(
  oda_climate = df_total_tbl,
  oda_climate_type_2levs = df_climate_aid_type_tbl,
  oda_climate_type_2levs_pst = df_climate_aid_type_pst_tbl,
  oda_climate_type_3levs = df_climate_aid_type_3levels_tbl,
  oda_climate_type_3levs_pst = df_climate_aid_type_3levels_pst_tbl,
  climate_finance = df_total_gross_tbl,
  climate_finance_type_2levs = df_climate_aid_type_oda_oof_tbl,
  climate_finance_type_3levs = df_climate_finance_type_3levels_tbl),
  path = here("output", "klimatabeller.xlsx")
)
