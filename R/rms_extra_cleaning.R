# Applying the cleaning log to clean the data
library(tidyverse)
library(lubridate)
library(glue)
library(checksupporteR)

source("R/support_functions.R")

# handle data -------------------------------------------------------------

data_path <- "inputs/RMS_Uganda_2022_Data.xlsx"

# main data
cols_to_escape <- c("index", "start", "end", "today", "starttime",	"endtime", "_submission_time", "_submission__submission_time")

data_nms <- names(readxl::read_excel(path = data_path, n_max = 2000))
c_types <- ifelse(str_detect(string = data_nms, pattern = "_other$"), "text", "guess")

df_raw_data <- readxl::read_excel(path = data_path, sheet = "UGA2207_PA", col_types = c_types) |> 
  mutate(number = "NA") |> 
  mutate(across(.cols = -c(contains(cols_to_escape)), 
                .fns = ~ifelse(str_detect(string = ., 
                                          pattern = fixed(pattern = "N/A", ignore_case = TRUE)), "NA", .))) |> 
  mutate(i.check.uuid = `_uuid`,
         i.check.start_date = as_date(start),
         i.check.enumerator_id = enumerator_id,
         i.check.district_name = case_when(settlement %in% c("rhino_camp") ~ "madi_okollo",
                                           settlement %in% c("bidibidi") ~ "yumbe",
                                           settlement %in% c("imvepi") ~ "terego",
                                           settlement %in% c("palabek") ~ "lamwo",
                                           settlement %in% c("kyangwali") ~ "kikube",
                                           settlement %in% c("lobule") ~ "koboko",
                                           settlement %in% c("nakivale") ~ "isingiro",
                                           settlement %in% c("oruchinga") ~ "isingiro",
                                           settlement %in% c("palorinya") ~ "obongi",
                                           settlement %in% c("rwamwanja") ~ "kamwenge",
                                           settlement %in% c("kyaka_ii") ~ "kyegegwa",
                                           settlement %in% c("any_adjumani_settlements") ~ "adjumani",
                                           TRUE ~ settlement),
         district_name = i.check.district_name,
         i.check.settlement = settlement,
         # i.check.point_number = household_id,
         start = as_datetime(start),
         end = as_datetime(end)
         )

# loops
# hh_roster
hh_roster <- readxl::read_excel(path = data_path, sheet = "hh_roster") |> 
  mutate(name_hh = openssl::md5(name_hh)) 

df_raw_data_hh_roster <- df_raw_data |> 
  select(-`_index`) |> 
  inner_join(hh_roster, by = c("_uuid" = "_submission__uuid") )

# tool
df_survey <- readxl::read_excel("inputs/RMS_tool.xlsx", sheet = "survey")
df_choices <- readxl::read_excel("inputs/RMS_tool.xlsx", sheet = "choices")

# output holder -----------------------------------------------------------

logic_output <- list()

# check duplicate uuids

df_c_duplicate_uuid <- check_duplicates_by_uuid(input_tool_data = df_tool_data)

add_checks_data_to_list(input_list_name = "logic_output", input_df_name = "df_c_duplicate_uuid")

# testing_data
df_testing_data <- df_raw_data %>% 
  filter(i.check.start_date < as_date("2022-11-22") | str_detect(string = household_id, pattern = fixed('test', ignore_case = TRUE))) %>% 
  mutate(i.check.type = "remove_survey",
         i.check.name = "",
         i.check.current_value = "",
         i.check.value = "",
         i.check.issue_id = "logic_c_testing_data",
         i.check.issue = "testing_data",
         i.check.other_text = "",
         i.check.checked_by = "",
         i.check.checked_date = as_date(today()),
         i.check.comment = "", 
         i.check.reviewed = "1",
         i.check.adjust_log = "",
         i.check.so_sm_choices = "") %>% 
  dplyr::select(starts_with("i.check")) %>% 
  rename_with(~str_replace(string = .x, pattern = "i.check.", replacement = ""))

add_checks_data_to_list(input_list_name = "logic_output", input_df_name = "df_testing_data")

# host data
df_host_data <- df_raw_data %>% 
  filter(str_detect(string = status, pattern = fixed('host', ignore_case = TRUE))) %>% 
  mutate(i.check.type = "remove_survey",
         i.check.name = "",
         i.check.current_value = "",
         i.check.value = "",
         i.check.issue_id = "logic_c_host_data",
         i.check.issue = "Host community not samples for surveys",
         i.check.other_text = "",
         i.check.checked_by = "",
         i.check.checked_date = as_date(today()),
         i.check.comment = "", 
         i.check.reviewed = "1",
         i.check.adjust_log = "",
         i.check.so_sm_choices = "") %>% 
  dplyr::select(starts_with("i.check")) %>% 
  rename_with(~str_replace(string = .x, pattern = "i.check.", replacement = ""))

add_checks_data_to_list(input_list_name = "logic_output", input_df_name = "df_host_data")

# checks on hhids ----------------------------------------------------------

sample_hhid_nos <- df_sample_data %>% 
  pull(unique_hhid_number) %>% 
  unique()

# duplicate point numbers
df_c_duplicate_hhid_nos <- check_duplicate_hhid_numbers(input_tool_data = df_tool_data,
                                                        input_sample_hhid_nos_list = sample_hhid_nos)

add_checks_data_to_list(input_list_name = "logic_output", input_df_name = "df_c_duplicate_hhid_nos")

# pt id does not exist in sample
df_c_hhid_not_in_sample <- check_hhid_number_not_in_samples(input_tool_data = df_tool_data, 
                                                            input_sample_hhid_nos_list = sample_hhid_nos)

add_checks_data_to_list(input_list_name = "logic_output", input_df_name = "df_c_hhid_not_in_sample")