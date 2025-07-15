# Clear Environment
rm(list=ls())

# Enter EITHER a REDCap data request ID (dr_id) to obtain the data request
# name from REDCap or directly enter the data request name below
dr_id = "1027"
data_request_name = NULL

og_submit_date <- "2025_05_20"
resubmit_date <- "2025_07_09"

# * Packages and Pathways: ----

# Load Packages:
library(tidyverse)
library(redcapAPI)
library(writexl)
library(readxl)
library(arsenal) # comparedf
library(data.table) # to read in files with commas in text stings (fread)
if ("plyr" %in% (.packages())){detach("package:plyr")}
if ("reshape" %in% (.packages())){detach("package:reshape")}

# Determine if the current machine running this program is a mac or a pc
# Identify the one drive and the Mesulam Share Point 
# location on the current machine to output files. 

# Windows:
if (Sys.info()[['sysname']]=="Windows"){
  netid = Sys.info()["user"]
  # identify the one drive path for the above user:
  od_loc = paste("C:/Users/",netid,"/OneDrive - Northwestern University/", sep="")
}
# Mac:
if (Sys.info()[['sysname']]=="Darwin"){
  netid = Sys.info()["user"]
  # identify the one drive path for the above identified user:
  od_loc = paste("/Users/",netid,"/OneDrive - Northwestern University/", sep="")
}

# Read in REDCap Token information saved on OneDrive to access REDCap API
# Add SOP Saved on Share Point: 
source(paste(od_loc, "redcap_api_info.R", sep=""))

#___________________________________________

# * File locations:----

if (!is.null(dr_id)){
  # Specify static parameters for REDCap API pull:
  formData <- list("token" = dr_token,
                   content='record',
                   format='csv',
                   type='flat',
                   'records[0]'=dr_id,
                   returnFormat='csv')
  # List all fields, forms, and events to be pulled from REDCap:
  fields = c("record_id", "rqst_file_name")
  forms = NULL
  events = NULL
  # Add fields, forms, events to the "formData" parameters list. 
  load_fields_forms_events(fields, forms, events)
  # Pull Data According to the parameters of "formData"
  response <- httr::POST(url, body = formData, encode = "form")
  dr_filename <- httr::content(response, col_types = cols(.default = "c"))
  
  data_request_name = dr_filename$rqst_file_name[1]
}

data_rqst_loc = paste(od_loc, "MC Data Management/Data Requests/", sep="")
request_loc = paste(data_rqst_loc,data_request_name, "/", sep="")
program_loc = paste(request_loc, "Program/", sep="")
input_loc = paste(program_loc, "Input/", sep="")
output_loc = paste(program_loc, "Output/", sep="")
past_data_loc = paste(od_loc, "MC Data Management/Uploading to Nacc/",
                      "Program/Past Uploaded NACC Data/", sep="")

# Create Request Folders
if (file.exists(request_loc)) {
  cat("The folder already exists")
} else {
  dir.create(request_loc)
  dir.create(program_loc)
  dir.create(input_loc)
  dir.create(output_loc)
}

# * Variable Look Up ----
# Does not need to be run unless the first lookup table that the 
# below code generated is missing
run = F
if (run == T){
  path <- paste(od_loc, "MC Data Management/",
                "Uploading to Nacc/Program/Input/", sep="")
  sheets <- str_remove(excel_sheets(path = paste(path, "NACC_UDS_2022_06_02.xlsx", sep="")), "frmc")
  
  var_lookup = NULL
  x = "a1"
  for (x in sheets){
    temp <- read_excel(paste(path, "NACC_UDS_2022_06_02.xlsx", sep="")
                       , sheet=paste("frmc", x, sep=""))
    cols <- as.data.frame(tolower(colnames(temp))) %>%
      dplyr::rename(Variable=1) %>%
      mutate(Var = paste("V", row_number(), sep="")) %>%
      mutate(V2_Form_Name = x, .before="Variable")
    if (is.null(var_lookup)){
      var_lookup <- cols
    } else {
      var_lookup <- bind_rows(var_lookup, cols)
    }
  }
  write.csv(var_lookup, paste(path, "NACC_Variable_Lookup.csv", sep=""), row.names=F)
}

# * Start Data Request: ----

#list of all files
all_forms <- list.files(paste(past_data_loc, "Upload Data ", 
                              resubmit_date, sep=""))
all_forms <- all_forms[-which(all_forms=="NP.csv")]
# Because the D2 data ends in a column with commas in the text, 
# it was reformatted, so that the last a second to last column 
# were switched so that it can be read in. The csv that 
# will be read in for D2 is the "D2_Reformatted.csv"
# The columns will be switch back once it is read in. 
all_forms <- all_forms[-which(all_forms=="D2.csv")]
# Currently there is not a way to distinguish different drugs 
# listed in the A4G, so the entire A4G csv will be uploaded, and 
# does not need to be included here. 
all_forms <- all_forms[-which(all_forms=="A4D.csv")]
all_forms <- all_forms[-which(all_forms=="A3A.csv")]


readVariableWidthFile <- function(filePath){
  #filePath = og_path
  con <-file(filePath)
  lines<- readLines(con)
  close(con)
  slines <- strsplit(lines,",")
  colCount <- max(unlist(lapply(slines, length)))
  
  FileContent <- read.csv(filePath,
                          header = FALSE,
                          col.names = paste0("V",seq_len(colCount)),
                          fill = TRUE, 
                          quote='"')
  return(FileContent)
}

upload_to_nacc <- NULL
data_check <- NULL
new_visits <- NULL
for (x in 1:length(all_forms)){
  #x = 3
  og_path = paste(past_data_loc, "Upload Data ", 
                  og_submit_date,"/", all_forms[x], sep="")
  re_path = paste(past_data_loc, "Upload Data ", 
                  resubmit_date,"/", all_forms[x], sep="")
  
  og_submit_data <- readVariableWidthFile(og_path) %>%
    filter(!is.na(V5) & V5!="." & !V5 %in% c(0, 1) & !is.na(V9) & V9!=".") %>%
    mutate_all(~ as.character(.)) %>%
    mutate_all(~str_replace_na(., ""))
  
  if (all_forms[x]=="D2_reformatted.csv"){
    og_submit_data <- og_submit_data %>%
      relocate(V43, .before=V42) %>%
      dplyr::rename(V43=V42, V42=V43)
  }
  
  resubmit_data <- readVariableWidthFile(re_path) %>%
    filter(!is.na(V5) & V5!="." & !V5 %in% c(0, 1) & !is.na(V9) & V9!=".")  %>%
    mutate_all(~ as.character(.)) %>%
    mutate_all(~str_replace_na(., ""))
  
  if (all_forms[x]=="D2_reformatted.csv"){
    resubmit_data <- resubmit_data %>%
      relocate(V43, .before=V42) %>%
      dplyr::rename(V43=V42, V42=V43)
  }
  
  # Form A4D needs to by evaluated on V5 (NACC ID), V9 (Visit Numbers), 
  # and V11, all other forms only need to be evaulated on V5 and V9
  if (all_forms[x] != "A4D.csv"){
    #Compare two dfs
    changed <- summary(comparedf(og_submit_data, resubmit_data, by = c("V5", "V9"), 
                                 factor.as.char = TRUE, int.as.num = TRUE))
    changed <- changed[["diffs.table"]] 
    
    changed_ids <- changed %>%
      select(V5, V9) %>%
      distinct(V5, V9)
    
    new_ids <- resubmit_data %>%
      select(V1, V2, V3, V5, V9, V6, V7, V8) %>%
      anti_join(og_submit_data[c("V5", "V9")])
    
    include <- changed_ids %>%
      full_join(new_ids[c("V5", "V9")])
    
    add_to_upload <- resubmit_data %>%
      right_join(include) 
    og_data_check <- og_submit_data %>%
      right_join(include)
    
  } 
  # else {
  #   Compare two dfs
  #   changed <- summary(comparedf(og_submit_data, resubmit_data, by = c("V5", "V9", "V11"),
  #                                factor.as.char = TRUE, int.as.num = TRUE))
  #   changed <- changed[["diffs.table"]]
  # 
  #   changed_ids <- changed %>%
  #     select(V5, V9) %>%
  #     distinct(V5, V9)
  # 
  #   new_ids <- resubmit_data %>%
  #     select(V1, V2, V3, V5, V9, V6, V7, V8) %>%
  #     anti_join(og_submit_data[c("V5", "V9")])
  # 
  #   include <- changed_ids %>%
  #     full_join(new_ids[c("V5", "V9")])
  # 
  #   add_to_upload <- resubmit_data %>%
  #     right_join(include)
  #   og_data_check <- og_submit_data %>%
  #     right_join(include)
  # }
  
  
  if (is.null(upload_to_nacc)){
    upload_to_nacc <- add_to_upload
    data_check <- og_data_check
    new_visits <- new_ids
  } else{
    upload_to_nacc <- bind_rows(upload_to_nacc, add_to_upload)
    data_check <- bind_rows(data_check, og_data_check)
    new_visits <- bind_rows(new_visits, new_ids) %>%
      distinct(V5, V9, .keep_all=T)
  }
  print(all_forms[x])
}


# read in variable look up:
path = paste(od_loc, "MC Data Management/Uploading to Nacc/Program/",
             "Input/NACC_Variable_Lookup.csv", sep="")
var_lookup <- read.csv(path) %>%
  mutate(V2_Form_Name = toupper(V2_Form_Name))

#Compare two dfs
changed_qa <- summary(comparedf(upload_to_nacc, data_check, by = c("V5", "V9", "V2"), 
                             factor.as.char = TRUE, int.as.num = TRUE))
changed_qa <- changed_qa[["diffs.table"]] %>%
  dplyr::rename(Changed_Value=values.x, OG_Value=values.y, 
               Var=var.x, OG_Var=var.y, 
               Row=row.x, OG_Row=row.y, 
               V5_ID=V5, V9_Visit_Num=V9, V2_Form_Name=V2) %>%
  select(-OG_Var, -OG_Row) %>%
  left_join(var_lookup) %>%
  relocate(Variable, .after=Var)
  


  

upload_to_nacc <- upload_to_nacc %>%
  mutate(V5 = sprintf("%010s", V5)) %>%
  mutate(V9 = case_when(
    str_detect(tolower(V9), "m", negate=T) ~ sprintf("%03s", V9), 
    T ~ V9
    )) %>%
  mutate_all(na_if,"")




write.table(upload_to_nacc, paste(past_data_loc, "Upload Data ", 
                                resubmit_date, "/nacc_upload_", 
                                Sys.Date(), ".csv", sep=""), 
          row.names = F, col.names=F, sep=",", na="")



write.table(upload_to_nacc, paste(past_data_loc, "Upload Data ", 
                                  resubmit_date, "/nacc_upload_test", 
                                  Sys.Date(), ".csv", sep=""), 
            row.names = F, col.names=F, sep=",", na="")

print("DONT FORGET TO UPLOAD A4D SEPARATLY!!!")

# APARENTLY THERE CAN BE NO & SYMBOLES, ADD CODE TO REPLACE ALL & WITH "AND"
  

  