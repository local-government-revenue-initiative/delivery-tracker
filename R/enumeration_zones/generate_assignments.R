
# Author : Zoé Baudoin
# Creation date : 10/09/2025
# Last update : 17/11/2025


              #### Enumeration Zones Creation and Assignments ####

library(sf)
library(dplyr)
library(mapview)
library(spdep)
library(igraph)
library(leafpop)
library(purrr)
library(writexl)
library(readxl)


# Prepare all assignments for LoGRI survey -------------------------------------

## Prepare data ----------------------------------------------------------------
# Load city blocks sampling data
ilots <- st_read("D:/Dropbox/5. SHARED Dropbox ASE/3. Mapping/7.Sampling/Ilots_sampling/ilot_sampling.shp")

# Load building sampling data 
buildings <- st_read("D:/Dropbox/5. SHARED Dropbox ASE/3. Mapping/7.Sampling/Buildings_sampling/building_sampling.shp")

# Keep only LoGRI survey
ilots <- ilots %>% 
  filter(survey=="logri")

# Quartier data
ilots <- ilots %>% 
  rename(quartier=quartir,
         n_structure=n_strct) %>% 
  mutate(ordre = case_when(quartier == 'LOKOKOUKOUME' ~ 1,
                           quartier == 'AKPOKPOTA' ~ 2,
                           quartier == 'KADJAKOME' ~ 3,
                           quartier == 'DAVATIN' ~ 3,
                           quartier == 'MONDOCOME' ~ 3,
                           quartier == 'KPAKPAKANME' ~ 3,
                           quartier == 'AGBALILAME' ~ 4,
                           quartier == 'AGBLANGANDAN' ~ 5,
                           quartier == 'SEKANDJI' ~ 6,
                           quartier == 'SEKANDJI HOUEYOGBE' ~ 7,
                           quartier == 'SEKANDJI ALLANMANDOS' ~ 8))


mapview(ilots,zcol="ordre")

test <- ilots %>% 
  group_by(ordre) %>% 
  summarise(n_total=sum(n_structure))

#1. Write excel ilot
write_xlsx(ilots %>% st_drop_geometry(),"D:/Dropbox/5. SHARED Dropbox ASE/3. Mapping/7.Sampling/Assignements_LoGRI/ilot_logri.xlsx")

#2. Do the assignments manually 

#3. Load ilot assignments to put them in the good format
ilot_assi <- read_excel("D:/Dropbox/5. SHARED Dropbox ASE/3. Mapping/7.Sampling/Assignements_LoGRI/ilot_logri_assignements.xlsx")

#4. Assign buildings 
building_logri <- buildings %>% 
  filter(survey=="logri")

ilot_assi_info <- ilot_assi %>% 
  st_drop_geometry() 
  
buildings_assignements <- merge(buildings,ilot_assi_info, by = c("id","quartier","ilot","survey"))
  
buildings_assignements <- buildings_assignements %>% 
  select(Enqueteur_id,ordre,id,quartier,ilot,build_id) %>% 
  rename(zone=ordre,
         quartier_id=id,
         input_building_id = build_id,
         enum_assigned=Enqueteur_id)
  arrange(zone)

mapview(buildings_assignements,zcol="Enqueteur_id")

#5. Publish assignments in the inbox
write_sf(buildings_assignements,"D:/Dropbox/5. SHARED Dropbox ASE/3. Mapping/7.Sampling/Assignements_LoGRI/logri_assignments_all.shp" )

--------------------------------------------------------------------------------

  
# Prepare all assignments for DGI survey ---------------------------------------

# Load city blocks sampling data
ilots <- st_read("D:/Dropbox/LoGRI Master Folder/2. Projects/2. Country Projects/2. Benin/21. 2025 pilot GIZ DGI/5. SHARED Dropbox ASE/3. Mapping/7.Sampling/Ilots_sampling/ilot_sampling.shp")

# Load building sampling data 
buildings <- st_read("D:/Dropbox/LoGRI Master Folder/2. Projects/2. Country Projects/2. Benin/21. 2025 pilot GIZ DGI/5. SHARED Dropbox ASE/3. Mapping/7.Sampling/Buildings_sampling/building_sampling.shp")

# Keep only DGI survey
ilots <- ilots %>% 
  filter(survey=="dgi")

# Quartier data
ilots <- ilots %>% 
  rename(quartier=quartir,
         n_structure=n_strct) %>% 
  mutate(ordre = case_when(quartier == 'LOKOKOUKOUME' ~ 1,
                           quartier == 'AKPOKPOTA' ~ 2,
                           quartier == 'KADJAKOME' ~ 3,
                           quartier == 'DAVATIN' ~ 3,
                           quartier == 'MONDOCOME' ~ 3,
                           quartier == 'KPAKPAKANME' ~ 3,
                           quartier == 'AGBALILAME' ~ 4,
                           quartier == 'AGBLANGANDAN' ~ 5,
                           quartier == 'SEKANDJI' ~ 6,
                           quartier == 'SEKANDJI HOUEYOGBE' ~ 7,
                           quartier == 'SEKANDJI ALLANMANDOS' ~ 8))

# Order visualization
mapview(ilots, zcol = "ordre")

# Order data
table_order <- ilots %>% 
  group_by(ordre) %>% 
  summarise(n_structure=n())



## Cluster function for team -------------------------------------------------------------
cluster <- function(ilots, zone_id, n_clusters = 5, seed = 1234) {
  
  set.seed(seed)
  
  # Select zone
  zone_subset <- ilots[ilots[["ordre"]] == zone_id, ]
  
  # Take centroid coordinates
  coords <- st_coordinates(st_centroid(zone_subset))
  
  # Nombre de clusters ≤ nombre d’îlots
  n_centers <- min(n_clusters, nrow(zone_subset))
  
  # K-means
  km <- kmeans(coords, centers = n_centers)
  
  # Add team id
  zone_subset$team <- km$cluster
  
  return(zone_subset)
}

## Apply cluster function to the 8 work zones -----------------------------------
zone1 <- cluster(ilots, zone_id=1)
zone2 <- cluster(ilots, zone_id=2)
zone3 <- cluster(ilots, zone_id=3)
zone4 <- cluster(ilots, zone_id=4)
zone5 <- cluster(ilots, zone_id=5)
zone6 <- cluster(ilots, zone_id=6)
zone7 <- cluster(ilots, zone_id=7)
zone8 <- cluster(ilots, zone_id=8)

## visualization clusters  ------------------------------------------------------
mapview(zone1, zcol = "team")
mapview(zone2, zcol = "team")
mapview(zone3, zcol = "team")
mapview(zone4, zcol = "team")
mapview(zone5, zcol = "team")
mapview(zone6, zcol = "team")
mapview(zone7, zcol = "team") 
mapview(zone8, zcol = "team")


## Assign ilots to enum per team ------------------------------------------------
assign_ilots <- function(data, n_enum) {
  data <- data[order(-data$n_structure), ]
  
  enqueteurs <- paste0("E", 1:n_enum)
  charges <- setNames(rep(0, n_enum), enqueteurs)
  
  data$enum <- NA
  
  for (i in 1:nrow(data)) {
    e <- names(which.min(charges))
    data$enum[i] <- e
    charges[e] <- charges[e] + data$n_structure[i]
  }
  
  return(data)
}

## Apply assign function to the 8 work zones ------------------------------------
# Set enum parameters
n_enum <- 6

# Apply function
zone1 <- zone1 %>%
  group_by(team) %>%
  group_modify(~ assign_ilots(.x, n_enum)) %>%
  ungroup() %>% 
  rename(zone=ordre) %>% 
  select(zone,id,quartier,ilot,team,enum,n_structure,geometry)

zone2 <- zone2 %>%
  group_by(team) %>%
  group_modify(~ assign_ilots(.x, n_enum)) %>%
  ungroup() %>% 
  rename(zone=ordre) %>% 
  select(zone,id,quartier,ilot,team,enum,n_structure,geometry)


zone3 <- zone3 %>%
  group_by(team) %>%
  group_modify(~ assign_ilots(.x, n_enum)) %>%
  ungroup() %>% 
  rename(zone=ordre) %>% 
  select(zone,id,quartier,ilot,team,enum,n_structure,geometry)


zone4 <- zone4 %>%
  group_by(team) %>%
  group_modify(~ assign_ilots(.x, n_enum)) %>%
  ungroup() %>% 
  rename(zone=ordre) %>% 
  select(zone,id,quartier,ilot,team,enum,n_structure,geometry)


zone5 <- zone5 %>%
  group_by(team) %>%
  group_modify(~ assign_ilots(.x, n_enum)) %>%
  ungroup() %>% 
  rename(zone=ordre) %>% 
  select(zone,id,quartier,ilot,team,enum,n_structure,geometry)


zone6 <- zone6 %>%
  group_by(team) %>%
  group_modify(~ assign_ilots(.x, n_enum)) %>%
  ungroup() %>% 
  rename(zone=ordre) %>% 
  select(zone,id,quartier,ilot,team,enum,n_structure,geometry)


zone7 <- zone7 %>%
  group_by(team) %>%
  group_modify(~ assign_ilots(.x, n_enum)) %>%
  ungroup() %>% 
  rename(zone=ordre) %>% 
  select(zone,id,quartier,ilot,team,enum,n_structure,geometry)


zone8 <- zone8 %>%
  group_by(team) %>%
  group_modify(~ assign_ilots(.x, n_enum)) %>%
  ungroup() %>%   rename(zone=ordre) %>% 
  select(zone,id,quartier,ilot,team,enum,n_structure,geometry)


# Convert back into sf object
zone1 <- st_as_sf(zone1)
zone2 <- st_as_sf(zone2)
zone3 <- st_as_sf(zone3)
zone4 <- st_as_sf(zone4)
zone5 <- st_as_sf(zone5)
zone6 <- st_as_sf(zone6)
zone7 <- st_as_sf(zone7)
zone8 <- st_as_sf(zone8)

mapview(zone1, zcol="enum")


## Check enum balance ----------------------------------------------------------------

zone1_check <- zone1 %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_1 = sum(n_structure,na.rm=T)) 

zone2_check <- zone2 %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_2 = sum(n_structure,na.rm=T))

zone3_check <- zone3 %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_3 = sum(n_structure,na.rm=T))

zone4_check <- zone4 %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_4 = sum(n_structure,na.rm=T))

zone5_check <- zone5 %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_5 = sum(n_structure,na.rm=T))

zone6_check <- zone6 %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_6 = sum(n_structure,na.rm=T))

zone7_check <- zone7 %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_7 = sum(n_structure,na.rm=T))

zone8_check <- zone8 %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_8 = sum(n_structure,na.rm=T))

list_datasets <- list(zone1_check,zone2_check,zone3_check,zone4_check,zone5_check,zone6_check,zone7_check,zone8_check)

check_enum <- reduce(list_datasets, ~ full_join(.x, .y, by = c("team", "enum")))

check_enum <- check_enum %>% 
  ungroup() %>% 
  mutate(sum = rowSums(select(., starts_with("total_structure")), na.rm = TRUE)) %>% 
  mutate(diff_structure = sum - mean(sum))

## Check team balance -----------------------------------------------------------
zone1_team <- zone1_check %>% 
  group_by(team) %>% 
  summarize(total_team1 = sum(total_structure_1))
zone2_team <- zone2_check %>% 
  group_by(team) %>% 
  summarize(total_team2 = sum(total_structure_2))
zone3_team <- zone3_check %>% 
  group_by(team) %>% 
  summarize(total_team3 = sum(total_structure_3))
zone4_team <- zone4_check %>% 
  group_by(team) %>% 
  summarize(total_team4 = sum(total_structure_4))
zone5_team <- zone5_check %>% 
  group_by(team) %>% 
  summarize(total_team5 = sum(total_structure_5))
zone6_team <- zone6_check %>% 
  group_by(team) %>% 
  summarize(total_team6 = sum(total_structure_6))
zone7_team <- zone7_check %>% 
  group_by(team) %>% 
  summarize(total_team7 = sum(total_structure_7))
zone8_team <- zone8_check %>% 
  group_by(team) %>% 
  summarize(total_team8 = sum(total_structure_8))


list_team <- list(zone1_team,zone2_team,zone3_team,zone4_team,
                  zone5_team,zone6_team,zone7_team,zone8_team)

check_team <- reduce(list_team, ~ full_join(.x, .y, by = "team"))


check_team <- check_team %>% 
  ungroup() %>% 
  mutate(sum = rowSums(select(., starts_with("total_team")), na.rm = TRUE)) %>% 
  mutate(diff_structure = sum - mean(sum))

## Correct balance --------------------------------------------------------------
zone4_balance <- zone4 %>% 
  mutate(new_team = case_when(team==1 ~ 2,
                              team==2 ~ 5,
                              team==3 ~ 4,
                              team==4 ~ 3,
                              team==5 ~ 1)) %>% 
  select(-team) %>% 
  rename(team=new_team)

zone6_balance <- zone6 %>% 
  mutate(new_team = case_when(team==1 ~ 3,
                              team==2 ~ 4,
                              team==3 ~ 1,
                              team==4 ~ 2,
                              team==5 ~ 5)) %>% 
  select(-team) %>% 
  rename(team=new_team)

zone7_balance <- zone7 %>% 
  mutate(new_team = case_when(team==1 ~ 2,
                              team==2 ~ 5,
                              team==3 ~ 1,
                              team==4 ~ 3,
                              team==5 ~ 4)) %>% 
  select(-team) %>% 
  rename(team=new_team)

zone8_balance <- zone8 %>% 
  mutate(new_team = case_when(team==1 ~ 1,
                              team==2 ~ 5,
                              team==3 ~ 2,
                              team==4 ~ 4,
                              team==5 ~ 3)) %>% 
  select(-team) %>% 
  rename(team=new_team)



## Check correct balance --------------------------------------------------------
zone4_check_balance <- zone4_balance %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_4 = sum(n_structure,na.rm=T))

zone6_check_balance <- zone6_balance %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_6 = sum(n_structure,na.rm=T))

zone7_check_balance <- zone7_balance %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_7 = sum(n_structure,na.rm=T))

zone8_check_balance <- zone8_balance %>%
  st_drop_geometry() %>% 
  group_by(team, enum) %>%
  summarise(total_structure_8 = sum(n_structure,na.rm=T))

zone4_team_balance <- zone4_check_balance %>% 
  group_by(team) %>% 
  summarize(total_team4 = sum(total_structure_4))
zone6_team_balance <- zone6_check_balance %>% 
  group_by(team) %>% 
  summarize(total_team6 = sum(total_structure_6))
zone7_team_balance <- zone7_check_balance %>% 
  group_by(team) %>% 
  summarize(total_team7 = sum(total_structure_7))
zone8_team_balance <- zone8_check_balance %>% 
  group_by(team) %>% 
  summarize(total_team8 = sum(total_structure_8))

list_team <- list(zone1_team,zone2_team,zone3_team,zone4_team_balance,
                  zone5_team,zone6_team_balance,zone7_team_balance,zone8_team_balance)

check_team_balance <- reduce(list_team, ~ full_join(.x, .y, by = "team"))


check_team_balance <- check_team_balance %>% 
  ungroup() %>% 
  mutate(sum = rowSums(select(., starts_with("total_team")), na.rm = TRUE)) %>% 
  mutate(diff_structure = sum - mean(sum))


# remove unecessary df 
rm(table_order,check_enum,check_team,check_team_balance,list_datasets,list_team,zone1_check,zone1_team,
   zone2_check,zone2_team,zone3_check,zone3_team,zone4,zone4_check,zone4_check_balance,
   zone4_team,zone4_team_balance,zone5_check,zone5_team,zone6,zone6_check,zone6_check_balance,zone6_team,zone6_team_balance,
   zone7,zone7_check,zone7_check_balance,zone7_team,zone7_team_balance,zone8,zone8_check,zone8_check_balance,zone8_team,zone8_team_balance)

## Assign buildings to enum -----------------------------------------------------
assign_zone_buildings <- function(zone_sf, buildings_sf, zone_number) {
  zone_info <- zone_sf %>%
    st_drop_geometry()
  
  zone_assignments <- buildings_sf %>%
    left_join(zone_info, by = c("ilot", "quartier", "id")) %>%
    filter(zone == zone_number) %>%
    select(zone, id, quartier, ilot, team, enum, build_id) %>% 
    arrange(team,enum)
  
  return(zone_assignments)
}
## Apply assign building function to the 8 work zones ---------------------------
zone1_assignments <- assign_zone_buildings(zone1, buildings, 1)
zone2_assignments <- assign_zone_buildings(zone2, buildings, 2)
zone3_assignments <- assign_zone_buildings(zone3, buildings, 3)
zone4_assignments <- assign_zone_buildings(zone4_balance, buildings, 4)
zone5_assignments <- assign_zone_buildings(zone5, buildings, 5)
zone6_assignments <- assign_zone_buildings(zone6_balance, buildings, 6)
zone7_assignments <- assign_zone_buildings(zone7_balance, buildings, 7)
zone8_assignments <- assign_zone_buildings(zone8_balance, buildings, 8)

all_assignments <- bind_rows(zone1_assignments,zone2_assignments,zone3_assignments,zone4_assignments,
                             zone5_assignments,zone6_assignments,zone7_assignments, zone8_assignments)

all_assignments <- all_assignments %>% 
  rename(quartier_id=id,
         enum_assigned=enum,
         input_building_id=build_id)

assignments_12 <- bind_rows(zone1_assignments,zone2_assignments)

assignments_12 <- assignments_12 %>% 
  rename(quartier_id=id,
         enum_assigned=enum,
         input_building_id=build_id)

# Save assignments
write_sf(all_assignments,"D:/Dropbox/5. SHARED Dropbox ASE/3. Mapping/7.Sampling/Assignments/assignments.shp")

write_sf(assignments_12,"D:/Dropbox/5. SHARED Dropbox ASE/3. Mapping/7.Sampling/Assignments/assignments_12.shp")
