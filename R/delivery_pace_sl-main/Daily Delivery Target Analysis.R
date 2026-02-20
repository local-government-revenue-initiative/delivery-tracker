################################################################################
#                                                                              #
#                    Daily Delivery Target Data Analysis                       #
#                          Freetown, Kenema, Makeni                            #
#                                                                              #
#                           To Be Used With Files:                             #
# mcc_2025, kcc_2024, kcc_2025, fcc_2021_team_1-3, fcc_2021_team_1-3,          #
# fcc_2021_team_4-6, fcc_2022_team_1-3, fcc_2022_team_4-6,  fcc_2023_team_1-3, #
# fcc_2023_team_4-6, fcc_2024_internal_staff,fcc_2024_team_1-3,fcc_2024_team_4-6, 
# fcc_2025_rnd1_team_1-3, fcc_2025_rnd1_team_4-6                               #
#                                                                              #
#                              By: Lorena Edah                                 #
#                                                                              #
################################################################################

# Summary ----------------------------------------------------------------------

# Objective: 
# To determine a realistic and accurate daily delivery pace for each city—Freetown,
# Kenema, and Makeni—based on past delivery data.

# Methodology:
#1.Looking at Unfiltered Data: For each city and year, I looked at all the deliveries 
# (inaccurate and accurate) made by enumerators and ran through steps 3-6 before looking
# at the filter data to be able to compare both and see if there are substantial 
# differences.

#2. Filtering for Accuracy: For each city and year, I filtered the dataset to 
# include only deliveries that occurred within 80 meters or less of the assigned 
# property. This 80m threshold serves as a proxy for accurately completed deliveries.

#3. Grouping by Enumerator and Date: After filtering, I grouped the data by 
# enumerator and date to calculate the number of accurate deliveries made by each 
# enumerator on each day.

#4. Aggregating by Date: These counts were then aggregated by date only, 
# resulting in the average number of accurate deliveries made per day.

#5. Removing Outliers: To avoid skewed results, I removed statistical outliers 
# using the Interquartile Range (IQR) method, ensuring only typical delivery 
# days were included.

#6. Calculating the Mean: Finally, I calculated the mean daily delivery target 
# across the cleaned dataset, providing a benchmark for setting realistic delivery targets in each city.


# Key Findings:

################################################################################


# Loading the necessary packages -----------------------------------------------
library(tidyverse)
library(janitor)
library(skimr)
library(ggthemes)

################################################################################
#                           Makeni 2025 Delivery Data  (new)                   #
################################################################################

# Loading and cleaning the data ------------------------------------------------
mcc_2025 <- read_csv("mcc_2025.csv") |> 
  clean_names() # standardize column names 

# Transforming: unfiltered data (all deliveries, regardless of accuracy)--------
mcc_2025_unfiltered <- mcc_2025 |> 
  mutate(date = as_date(delivered_on)) |> # create a proper date column
  count(date, mobile_user_username, name = "enum_daily_deliv") |> # count deliveries per enumerator per day
  group_by(date) |> # # group all enumerators together by date
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> # average across enumerators per day
  mutate( # Removing outliers using the IQR method
  Q1 = quantile(daily_avg, 0.25),
  Q3 = quantile(daily_avg, 0.75),
  IQR = Q3 - Q1
) |>
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Transforming: filtered data (only accurate deliveries <= 80m) ----------------
mcc_2025_filtered <- mcc_2025 |> 
  filter(distance <= 80) |> # keep only accurate deliveries (<= 80m threshold)
  mutate(date = as_date(delivered_on)) |> 
  count(date, mobile_user_username, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate( 
  Q1 = quantile(daily_avg, 0.25),
  Q3 = quantile(daily_avg, 0.75),
  IQR = Q3 - Q1
) |>
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Summary statistics -----------------------------------------------------------
makeni_stats_unfiltered <- mcc_2025_unfiltered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),    # average daily pace
    median = median(daily_avg, na.rm = TRUE),  # middle point (robust to outliers)
    sd     = sd(daily_avg, na.rm = TRUE),      # variation
    iqr    = IQR(daily_avg, na.rm = TRUE),     # spread of typical days
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE), # 80th percentile (ambitious target)
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)  # 90th percentile (high benchmark)
  )

makeni_stats_filtered <- mcc_2025_filtered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),    
    median = median(daily_avg, na.rm = TRUE),  
    sd     = sd(daily_avg, na.rm = TRUE),      
    iqr    = IQR(daily_avg, na.rm = TRUE),     
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE), 
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)  
  )

# Compare unfiltered vs filtered averages --------------------------------------
makeni_comparison_2025 <- tibble(
  unfiltered_mean = mean(mcc_2025_unfiltered$daily_avg, na.rm = TRUE), 
  filtered_mean   = mean(mcc_2025_filtered$daily_avg, na.rm = TRUE) 
) |> 
  mutate(
    diff_percent = (unfiltered_mean - filtered_mean) / unfiltered_mean * 100 # % difference: all deliveries vs. accurate deliveries only
  )

# Looking at How Time of Day & Day of Week Affects Delivery Pace----------------
mcc_2025_tod_dow <- mcc_2025 |> 
  mutate(
    date = as_date(delivered_on), # convert to proper date format
    dow = wday(date, label = TRUE, abbr = TRUE), # extract day of week as abbreviated labels (Mon, Tue, etc.)
    hour = hour(delivered_on), # extract hour of day from timestamp
    tod = case_when( # create time-of-day brackets (3-hour periods)
      hour >= 6  & hour < 9  ~ "06–08", # early morning shift
      hour >= 9  & hour < 12 ~ "09–11", # mid-morning shift
      hour >= 12 & hour < 15 ~ "12–14", # early afternoon shift
      hour >= 15 & hour < 18 ~ "15–17", # late afternoon shift
      TRUE ~ "Other (Night/Early Morning)" # unusual hours
    )
  )

# Calculate average delivery pace by time of day
mcc_2025_delivery_pace_tod <- mcc_2025_tod_dow |> 
  count(date, tod, mobile_user_username, name = "enum_deliv") |> # count deliveries per enumerator per time of day (tod)
  group_by(tod) |> # group by day of week
  summarise(
    avg_daily_pace_tod = mean(enum_deliv),
    .groups = "drop" 
  )

# Calculate average delivery pace by day of week
mcc_2025_delivery_pace_dow <- mcc_2025_tod_dow |> 
  count(date, dow, mobile_user_username, name = "enum_deliv") |> # count deliveries per enumerator per day of the week (dow)
  group_by(dow) |> # group by day of week
  summarise(
    avg_daily_pace_dow = mean(enum_deliv),
    .groups = "drop" 
  )

# Calculate average delivery pace by both day of week and time of day
mcc_2025_delivery_pace_tod_dow <- mcc_2025_tod_dow |> 
  count(date, dow, tod, mobile_user_username, name = "enum_deliv") |> 
  group_by(dow, tod) |> 
  summarise(
    avg_daily_pace_tod_dow = mean(enum_deliv), 
    .groups = "drop" 
  )
      
# Visualizations ---------------------------------------------------------------
      
# (a) Time-series plot (daily delivery averages over time)
mcc_2025_unfiltered |> 
  ggplot(aes(x = date, y = daily_avg)) + 
  geom_line(color = "blue", linewidth = 1) + 
  geom_point(size = 1.5, color = "black") +  
  labs(                                      
    title = "Makeni 2025: Average Accurate Daily Deliveries", 
    x = "Date",                            
    y = "Average Accurate Daily Deliveries"
  ) 
ggsave("makeni_2025_timeseries.png")     
      
# (b) Histogram + density curve (distribution shape)
mcc_2025_filtered |> 
  ggplot(aes(x = daily_avg)) +            
  geom_histogram(aes(y = after_stat(density)), 
                  bins = 15, fill = "lightgreen", alpha = 0.6, color = "black") + 
  geom_density(color = "darkgreen", linewidth = 1) + 
  labs(                                     
    title = "Distribution of Daily Delivery Pace (Makeni 2025)", 
    x = "Deliveries per Day",              
    y = "Density"                         
  )
ggsave("makeni_2025_distribution.png")  
      
# (c) Delivery pace by day of week and time of day bracket
mcc_2025_delivery_pace_tod_dow |>                
  ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, fill = tod)) + 
  geom_col(position = "dodge") +        
  labs(                                 
    title = "Makeni 2025: Delivery Pace by Day of Week & Time of Day", # Chart title
    x = "Day of the Week",              
    y = "Average Deliveries per Enumerator", 
    fill = "Time of Day (3-hour brackets)" 
  )
ggsave("makeni_2025_pace_dow_tod.png") 


################################################################################
#                           Kenema 2025 Delivery Data                          #
################################################################################

# Loading and cleaning the data ------------------------------------------------
kcc_2025 <- read_csv("kcc_2025.csv") |> 
  clean_names() 
    
# Transforming: unfiltered data (all deliveries, regardless of accuracy)--------
kcc_2025_unfiltered <- kcc_2025 |> 
  mutate(date = as_date(mdy_hm(delivered_on))) |>
  count(date, user_name, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate( 
  Q1 = quantile(daily_avg, 0.25),
  Q3 = quantile(daily_avg, 0.75),
  IQR = Q3 - Q1
) |>
  filter(
  daily_avg >= Q1 - 1.5 * IQR,
  daily_avg <= Q3 + 1.5 * IQR
  )
    
# Transforming: filtered data (only accurate deliveries <= 80m) ----------------
kcc_2025_filtered <- kcc_2025 |> 
  filter(distance <= 80) |> 
  mutate(date = as_date(mdy_hm(delivered_on))) |> 
  count(date, user_name, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate( 
  Q1 = quantile(daily_avg, 0.25),
  Q3 = quantile(daily_avg, 0.75),
  IQR = Q3 - Q1
) |>
  filter(
  daily_avg >= Q1 - 1.5 * IQR,
  daily_avg <= Q3 + 1.5 * IQR
  )
    
# Summary statistics -----------------------------------------------------------
kenema_stats_unfiltered <- kcc_2025_unfiltered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),    
    median = median(daily_avg, na.rm = TRUE),  
    sd     = sd(daily_avg, na.rm = TRUE),      
    iqr    = IQR(daily_avg, na.rm = TRUE),     
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE) 
  )
    
kenema_stats_filtered <- kcc_2025_filtered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),    
    median = median(daily_avg, na.rm = TRUE),  
    sd     = sd(daily_avg, na.rm = TRUE),      
    iqr    = IQR(daily_avg, na.rm = TRUE),     
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE), 
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)  
  )
    
# Compare unfiltered vs filtered averages --------------------------------------
kenema_comparison_2025 <- tibble(
  unfiltered_mean = mean(kcc_2025_unfiltered$daily_avg, na.rm = TRUE),
  filtered_mean   = mean(kcc_2025_filtered$daily_avg, na.rm = TRUE)
) |> 
  mutate(
    diff_percent = (unfiltered_mean - filtered_mean) / unfiltered_mean * 100
  )
    
# Looking at How Time of Day & Day of Week Affects Delivery Pace----------------
kcc_2025_tod_dow <- kcc_2025 |> 
  mutate(
    datetime = mdy_hm(delivered_on),          
    date = as_date(datetime),                 
    dow = wday(date, label = TRUE, abbr = TRUE), 
    hour = hour(datetime),                     
    tod = case_when(                          
      hour >= 6  & hour < 9  ~ "06–08",
      hour >= 9  & hour < 12 ~ "09–11",
      hour >= 12 & hour < 15 ~ "12–14",
      hour >= 15 & hour < 18 ~ "15–17",
      TRUE ~ "Other (Night/Early Morning)"
    )
  )
    
# Count deliveries per enumerator per day & time bracket
kcc_2025_delivery_pace_tod <- kcc_2025_tod_dow |> 
  count(date, tod, user_name, name = "enum_deliv") |> 
  group_by(tod) |> 
  summarise(
    avg_daily_pace_tod = mean(enum_deliv), 
    .groups = "drop"
  )
    
kcc_2025_delivery_pace_dow <- kcc_2025_tod_dow |> 
  count(date, dow, user_name, name = "enum_deliv") |> 
  group_by(dow) |> 
  summarise(
    avg_daily_pace_dow = mean(enum_deliv), 
    .groups = "drop"
  )
    
kcc_2025_delivery_pace_tod_dow <- kcc_2025_tod_dow |> 
  count(date, dow, tod, user_name, name = "enum_deliv") |> 
  group_by(dow, tod) |> 
  summarise(
    avg_daily_pace_tod_dow = mean(enum_deliv), 
    .groups = "drop"
  )
    
# Visualizations ---------------------------------------------------------------
    
# (a) Time-series plot (performance over time)
kcc_2025_filtered |> 
      ggplot(aes(x = date, y = daily_avg)) +
      geom_line(color = "blue", linewidth = 1) + 
      geom_point(size = 1.5, color = "black") +       
      labs(
        title = "Kenema 2025: Average Accurate Daily Deliveries",
        x = "Date",
        y = "Average Accurate Daily Deliveries"
      ) 
ggsave("kenema_2025_timeseries.png")
    
    
# (b) Histogram + density curve (distribution shape)
kcc_2025_filtered |> 
      ggplot(aes(x = daily_avg)) +
      geom_histogram(aes(y = after_stat(density)), 
                     bins = 15, fill = "pink", alpha = 0.6, color = "black") +
      geom_density(color = "red", linewidth = 1) +
      labs(
        title = "Distribution of Daily Delivery Pace (Kenema 2025)",
        x = "Deliveries per Day",
        y = "Density"
      ) 
ggsave("kenema_2025_distribution.png")
    
    
# (c) Delivery pace by day of week and time of day bracket
kcc_2025_delivery_pace_tod_dow |> 
      ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, fill = tod)) +
      geom_col(position = "dodge") +
      labs(
        title = "Kenema 2025: Delivery Pace by Day of Week & Time of Day",
        x = "Day of the Week",
        y = "Average Deliveries per Enumerator",
        fill = "Time of Day (3-hour brackets)"
      ) 
ggsave("kenema_2025_pace_dow_tod.png")

    
################################################################################
#                           Kenema 2024 Delivery Data                          #
################################################################################

# Loading & cleaning the data---------------------------------------------------
kcc_2024 <- read_csv("kcc_2024.csv")

# Split property_type into multiple rows (each counts as a delivery)
kcc_2024 <- kcc_2024 |> 
  separate_rows(property_type, sep = ",\\s*")

# Transforming: unfiltered data (all deliveries)--------------------------------
kcc_2024_unfiltered <- kcc_2024 |> 
  filter(!is.na(time_delivery_date)) |> # getting rid of missing delivery date data (ex. rejected deliveries for military barracks)
  mutate(
    datetime = dmy_hms(time_delivery_date),
    date = as_date(datetime)
  ) |> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Transforming: filtered data (accurate deliveries ≤ 0.08 km)-------------------
kcc_2024_filtered <- kcc_2024 |> 
  filter(time_gps_distance_original <= 0.08) |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = dmy_hms(time_delivery_date),
    date = as_date(datetime)
  ) |> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Summary statistics
kenema_stats_unfiltered <- kcc_2024_unfiltered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

kenema_stats_filtered <- kcc_2024_filtered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

# Comparison
kenema_comparison_2024 <- tibble(
  unfiltered_mean = mean(kcc_2024_unfiltered$daily_avg, na.rm = TRUE),
  filtered_mean   = mean(kcc_2024_filtered$daily_avg, na.rm = TRUE)
) |> 
  mutate(
    diff_percent = (unfiltered_mean - filtered_mean) / unfiltered_mean * 100
  )

# Time of day & day of week
kcc_2024_tod_dow <- kcc_2024 |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = dmy_hms(time_delivery_date),
    date = as_date(datetime),
    dow = wday(date, label = TRUE, abbr = TRUE),
    hour = hour(datetime),
    tod = case_when(
      hour >= 6  & hour < 9  ~ "06–08",
      hour >= 9  & hour < 12 ~ "09–11",
      hour >= 12 & hour < 15 ~ "12–14",
      hour >= 15 & hour < 18 ~ "15–17",
      TRUE ~ "Other (Night/Early Morning)"
    )
  )

# Delivery pace by time of day, day of week
kcc_2024_delivery_pace_tod <- kcc_2024_tod_dow |> 
  count(date, tod, enteredby, name = "enum_deliv") |> 
  group_by(tod) |> 
  summarise(avg_daily_pace_tod = mean(enum_deliv), .groups = "drop")

kcc_2024_delivery_pace_dow <- kcc_2024_tod_dow |> 
  count(date, dow, enteredby, name = "enum_deliv") |> 
  group_by(dow) |> 
  summarise(avg_daily_pace_dow = mean(enum_deliv), .groups = "drop")

kcc_2024_delivery_pace_tod_dow <- kcc_2024_tod_dow |> 
  count(date, dow, tod, enteredby, name = "enum_deliv") |> 
  group_by(dow, tod) |> 
  summarise(avg_daily_pace_tod_dow = mean(enum_deliv), .groups = "drop")

# Visualizations

# (a) Time-series plot
kcc_2024_filtered |> 
  ggplot(aes(x = date, y = daily_avg)) +
  geom_line(color = "blue", linewidth = 1) +
  geom_point(size = 1.5, color = "black") +
  labs(title = "Average Accurate Daily Deliveries (KCC 2024)", x = "Date", y = "Average Deliveries") 
ggsave("kenema_2024_timeseries.png")

# (b) Histogram + density curve
kcc_2024_filtered |> 
  ggplot(aes(x = daily_avg)) +
  geom_histogram(aes(y = after_stat(density)), bins = 15, fill = "pink", alpha = 0.6, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  labs(title = "Distribution of Daily Delivery Pace (KCC 2024)", x = "Deliveries per Day", y = "Density") 
ggsave("kenema_2024_distribution.png")

# (c) Delivery pace by day of week & time of day
kcc_2024_delivery_pace_tod_dow |> 
  ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, fill = tod)) +
  geom_col(position = "dodge") +
  labs(title = "Delivery Pace by Day of Week & Time of Day (KCC 2024)",
       x = "Day of the Week", y = "Average Deliveries per Enumerator", fill = "Time of Day") 
ggsave("kenema_2024_pace_dow_tod.png")


################################################################################
#               Freetown 2025 Delivery Data (Round 1)                          #
################################################################################

# Loading and cleaning the data: merging the 2 datatsets for FCC 2025 Round 1 (i.e fcc_2025_rnd1_team_1-3 & fcc_2025_rnd1_team_4-6)
fcc_2025 <- bind_rows(
  read_csv("fcc_2025_rnd1_team_1-3.csv"),
  read_csv("fcc_2025_rnd1_team_4-6.csv")
) |> 
  clean_names()
# Split property_type into multiple rows (each counts as a delivery)
fcc_2025 <- fcc_2025 |> 
  separate_rows(property_type, sep = ",\\s*")

# Transforming: unfiltered data (all deliveries)--------------------------------
fcc_2025_unfiltered <- fcc_2025 |> 
  filter(!is.na(time_delivery_date)) |> # getting rid of missing delivery date data (ex. rejected deliveries for military barracks)
  mutate(
    datetime = dmy_hms(time_delivery_date),
    date = as_date(datetime)
  ) |> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Transforming: filtered data (accurate deliveries ≤ 0.08 km)-------------------
fcc_2025_filtered <- fcc_2025 |> 
  filter(time_gps_distance_original <= 0.08) |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = dmy_hms(time_delivery_date),
    date = as_date(datetime)
  ) |> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Summary statistics
freetown_stats_unfiltered <- fcc_2025_unfiltered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

freetown_stats_filtered <- fcc_2025_filtered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

# Comparison
freetown_comparison_2025 <- tibble(
  unfiltered_mean = mean(fcc_2025_unfiltered$daily_avg, na.rm = TRUE),
  filtered_mean   = mean(fcc_2025_filtered$daily_avg, na.rm = TRUE)
) |> 
  mutate(
    diff_percent = (unfiltered_mean - filtered_mean) / unfiltered_mean * 100
  )

# Time of day & day of week
fcc_2025_tod_dow <- fcc_2025 |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = dmy_hms(time_delivery_date),
    date = as_date(datetime),
    dow = wday(date, label = TRUE, abbr = TRUE),
    hour = hour(datetime),
    tod = case_when(
      hour >= 6  & hour < 9  ~ "06–08",
      hour >= 9  & hour < 12 ~ "09–11",
      hour >= 12 & hour < 15 ~ "12–14",
      hour >= 15 & hour < 18 ~ "15–17",
      TRUE ~ "Other (Night/Early Morning)"
    )
  )

# Delivery pace by time of day, day of week
fcc_2025_delivery_pace_tod <- fcc_2025_tod_dow |> 
  count(date, tod, enteredby, name = "enum_deliv") |> 
  group_by(tod) |> 
  summarise(avg_daily_pace_tod = mean(enum_deliv), .groups = "drop")

fcc_2025_delivery_pace_dow <- fcc_2025_tod_dow |> 
  count(date, dow, enteredby, name = "enum_deliv") |> 
  group_by(dow) |> 
  summarise(avg_daily_pace_dow = mean(enum_deliv), .groups = "drop")

fcc_2025_delivery_pace_tod_dow <- fcc_2025_tod_dow |> 
  count(date, dow, tod, enteredby, name = "enum_deliv") |> 
  group_by(dow, tod) |> 
  summarise(avg_daily_pace_tod_dow = mean(enum_deliv), .groups = "drop")

# Visualizations

# (a) Time-series plot
fcc_2025_unfiltered |> 
  ggplot(aes(x = date, y = daily_avg)) +
  geom_line(color = "blue", linewidth = 1) +
  geom_point(size = 1.5, color = "black") +
  labs(title = "Average Accurate Daily Deliveries (FCC 2025)", x = "Date", y = "Average Deliveries") 
ggsave("freetown_2025_timeseries.png")

# (b) Histogram + density curve
fcc_2025_unfiltered |> 
  ggplot(aes(x = daily_avg)) +
  geom_histogram(aes(y = after_stat(density)), bins = 15, fill = "pink", alpha = 0.6, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  labs(title = "Distribution of Daily Delivery Pace (FCC 2025)", x = "Deliveries per Day", y = "Density") 
ggsave("freetown_2025_distribution.png")

# (c) Delivery pace by day of week & time of day
fcc_2025_delivery_pace_tod_dow |> 
  ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, fill = tod)) +
  geom_col(position = "dodge") +
  labs(title = "Delivery Pace by Day of Week & Time of Day (FCC 2025)",
       x = "Day of the Week", y = "Average Deliveries per Enumerator", fill = "Time of Day") 
ggsave("freetown_2025_pace_dow_tod.png")
    

################################################################################
#               Freetown 2024 Delivery Data                                    #
################################################################################  

# Loading and cleaning the data: merging the 2 datasets for FCC 2024 (i.e fcc_2024_team_1-3 & fcc_2024_team_4-6)-----
fcc_2024 <- bind_rows(
  read_csv("fcc_2024_team_1-3.csv"),
  read_csv("fcc_2024_team_4-6.csv")
) |> 
  clean_names()

bad_dates <- fcc_2024 |>  # checking to see which dates are formatted differently (some failed to parse below)
  mutate(datetime = dmy_hms(time_delivery_date)) |> 
  filter(is.na(datetime) & !is.na(time_delivery_date)) |> 
  distinct(time_delivery_date)
bad_dates

fcc_2024 <- fcc_2024 |> # cleaning up the time_delivery_date column to ensure formatting consistency
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    )
  )


fcc_2024 <- fcc_2024 |> # split property_type column values into multiple rows (each counts as a delivery)
  separate_rows(property_type, sep = ",\\s*") 

# Transforming: unfiltered data (all deliveries)--------------------------------
fcc_2024_unfiltered <- fcc_2024 |> 
  filter(!is.na(time_delivery_date)) |> # getting rid of missing delivery date data (ex. rejected deliveries for military barracks)
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime)
  )|> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Transforming: filtered data (accurate deliveries ≤ 0.08 km)-------------------
fcc_2024_filtered <- fcc_2024 |> 
  filter(time_gps_distance_original <= 0.08) |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime)
  ) |> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Summary statistics
freetown_stats_unfiltered <- fcc_2024_unfiltered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

freetown_stats_filtered <- fcc_2024_filtered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

# Comparison
freetown_comparison_2024 <- tibble(
  unfiltered_mean = mean(fcc_2024_unfiltered$daily_avg, na.rm = TRUE),
  filtered_mean   = mean(fcc_2024_filtered$daily_avg, na.rm = TRUE)
) |> 
  mutate(
    diff_percent = (unfiltered_mean - filtered_mean) / unfiltered_mean * 100
  )

# Time of day & day of week
fcc_2024_tod_dow <- fcc_2024 |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime),
    dow = wday(date, label = TRUE, abbr = TRUE),
    hour = hour(datetime),
    tod = case_when(
      hour >= 6  & hour < 9  ~ "06–08",
      hour >= 9  & hour < 12 ~ "09–11",
      hour >= 12 & hour < 15 ~ "12–14",
      hour >= 15 & hour < 18 ~ "15–17",
      TRUE ~ "Other (Night/Early Morning)"
    )
  )

# Delivery pace by time of day, day of week
fcc_2024_delivery_pace_tod <- fcc_2024_tod_dow |> 
  count(date, tod, enteredby, name = "enum_deliv") |> 
  group_by(tod) |> 
  summarise(avg_daily_pace_tod = mean(enum_deliv), .groups = "drop")

fcc_2024_delivery_pace_dow <- fcc_2024_tod_dow |> 
  count(date, dow, enteredby, name = "enum_deliv") |> 
  group_by(dow) |> 
  summarise(avg_daily_pace_dow = mean(enum_deliv), .groups = "drop")

fcc_2024_delivery_pace_tod_dow <- fcc_2024_tod_dow |> 
  count(date, dow, tod, enteredby, name = "enum_deliv") |> 
  group_by(dow, tod) |> 
  summarise(avg_daily_pace_tod_dow = mean(enum_deliv), .groups = "drop")

# Visualizations

# (a) Time-series plot
fcc_2024_unfiltered |> 
  ggplot(aes(x = date, y = daily_avg)) +
  geom_line(color = "blue", linewidth = 1) +
  geom_point(size = 1.5, color = "black") +
  labs(title = "Average Accurate Daily Deliveries (FCC 2024)", x = "Date", y = "Average Deliveries") 
ggsave("freetown_2024_timeseries.png")

# (b) Histogram + density curve
fcc_2024_unfiltered |> 
  ggplot(aes(x = daily_avg)) +
  geom_histogram(aes(y = after_stat(density)), bins = 15, fill = "pink", alpha = 0.6, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  labs(title = "Distribution of Daily Delivery Pace (FCC 2024)", x = "Deliveries per Day", y = "Density") 
ggsave("freetown_2024_distribution.png")

# (c) Delivery pace by day of week & time of day
fcc_2024_delivery_pace_tod_dow |> 
  ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, fill = tod)) +
  geom_col(position = "dodge") +
  labs(title = "Delivery Pace by Day of Week & Time of Day (FCC 2024)",
       x = "Day of the Week", y = "Average Deliveries per Enumerator", fill = "Time of Day") 
ggsave("freetown_2024_pace_dow_tod.png")


################################################################################
#                        Freetown 2023 Delivery Data                           #
################################################################################

# Loading and cleaning the data: merging the 2 datasets for FCC 2023 (i.e fcc_2023_team_1-3 & fcc_2023_team_4-6)-----
fcc_2023 <- bind_rows(
  read_csv("fcc_2023_team_1-3.csv"),
  read_csv("fcc_2023_team_4-6.csv")
) |> 
  clean_names()

bad_dates <- fcc_2023 |>  # checking to see which dates are formatted differently (some failed to parse below)
  mutate(datetime = dmy_hms(time_delivery_date)) |> 
  filter(is.na(datetime) & !is.na(time_delivery_date)) |> 
  distinct(time_delivery_date)
bad_dates

fcc_2023 <- fcc_2023 |> # cleaning up the time_delivery_date column to ensure formatting consistency
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    )
  )

fcc_2023 <- fcc_2023 |> # split property_type column values into multiple rows (each counts as a delivery)
  separate_rows(property_type, sep = ",\\s*") 

# Transforming: unfiltered data (all deliveries)--------------------------------
fcc_2023_unfiltered <- fcc_2023 |> 
  filter(!is.na(time_delivery_date)) |> 
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime)
  )|> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Transforming: filtered data (accurate deliveries ≤ 0.08 km)-------------------
fcc_2023_filtered <- fcc_2023 |> 
  filter(time_gps_distance_original <= 0.08) |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime)
  ) |> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Summary statistics
freetown_stats_unfiltered <- fcc_2023_unfiltered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

freetown_stats_filtered <- fcc_2023_filtered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

# Comparison
freetown_comparison_2023 <- tibble(
  unfiltered_mean = mean(fcc_2023_unfiltered$daily_avg, na.rm = TRUE),
  filtered_mean   = mean(fcc_2023_filtered$daily_avg, na.rm = TRUE)
) |> 
  mutate(
    diff_percent = (unfiltered_mean - filtered_mean) / unfiltered_mean * 100
  )

# Time of day & day of week
fcc_2023_tod_dow <- fcc_2023 |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime),
    dow = wday(date, label = TRUE, abbr = TRUE),
    hour = hour(datetime),
    tod = case_when(
      hour >= 6  & hour < 9  ~ "06–08",
      hour >= 9  & hour < 12 ~ "09–11",
      hour >= 12 & hour < 15 ~ "12–14",
      hour >= 15 & hour < 18 ~ "15–17",
      TRUE ~ "Other (Night/Early Morning)"
    )
  )

# Delivery pace by time of day, day of week
fcc_2023_delivery_pace_tod <- fcc_2023_tod_dow |> 
  count(date, tod, enteredby, name = "enum_deliv") |> 
  group_by(tod) |> 
  summarise(avg_daily_pace_tod = mean(enum_deliv), .groups = "drop")

fcc_2023_delivery_pace_dow <- fcc_2023_tod_dow |> 
  count(date, dow, enteredby, name = "enum_deliv") |> 
  group_by(dow) |> 
  summarise(avg_daily_pace_dow = mean(enum_deliv), .groups = "drop")

fcc_2023_delivery_pace_tod_dow <- fcc_2023_tod_dow |> 
  count(date, dow, tod, enteredby, name = "enum_deliv") |> 
  group_by(dow, tod) |> 
  summarise(avg_daily_pace_tod_dow = mean(enum_deliv), .groups = "drop")

# Visualizations

# (a) Time-series plot
fcc_2023_unfiltered |> 
  ggplot(aes(x = date, y = daily_avg)) +
  geom_line(color = "blue", linewidth = 1) +
  geom_point(size = 1.5, color = "black") +
  labs(title = "Average Accurate Daily Deliveries (FCC 2023)", x = "Date", y = "Average Deliveries") 
ggsave("freetown_2023_timeseries.png")

# (b) Histogram + density curve
fcc_2023_unfiltered |> 
  ggplot(aes(x = daily_avg)) +
  geom_histogram(aes(y = after_stat(density)), bins = 15, fill = "pink", alpha = 0.6, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  labs(title = "Distribution of Daily Delivery Pace (FCC 2023)", x = "Deliveries per Day", y = "Density") 
ggsave("freetown_2023_distribution.png")

# (c) Delivery pace by day of week & time of day
fcc_2023_delivery_pace_tod_dow |> 
  ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, fill = tod)) +
  geom_col(position = "dodge") +
  labs(title = "Delivery Pace by Day of Week & Time of Day (FCC 2023)",
       x = "Day of the Week", y = "Average Deliveries per Enumerator", fill = "Time of Day") 
ggsave("freetown_2023_pace_dow_tod.png")


################################################################################
#                        Freetown 2022 Delivery Data                           #
################################################################################

# Loading and cleaning the data: merging the 2 datasets for FCC 2022 (i.e fcc_2022_team_1-3 & fcc_2022_team_4-6)-----
fcc_2022 <- bind_rows(
  read_csv("fcc_2022_team_1-3.csv"),
  read_csv("fcc_2022_team_4-6.csv")
) |> 
  clean_names()

bad_dates <- fcc_2022 |>  # checking which dates failed to parse
  mutate(datetime = dmy_hms(time_delivery_date)) |> 
  filter(is.na(datetime) & !is.na(time_delivery_date)) |> 
  distinct(time_delivery_date)
bad_dates

fcc_2022 <- fcc_2022 |> # cleaning up the time_delivery_date column for uniform format
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    )
  )

fcc_2022 <- fcc_2022 |> # split property_type column values into multiple rows
  separate_rows(property_type, sep = ",\\s*") 

# Transforming: unfiltered data (all deliveries)--------------------------------
fcc_2022_unfiltered <- fcc_2022 |> 
  filter(!is.na(time_delivery_date)) |> 
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime)
  )|> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Transforming: filtered data (accurate deliveries ≤ 0.08 km)-------------------
fcc_2022_filtered <- fcc_2022 |> 
  filter(time_gps_distance_original <= 0.08) |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime)
  ) |> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Summary statistics
freetown_stats_unfiltered <- fcc_2022_unfiltered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

freetown_stats_filtered <- fcc_2022_filtered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

# Comparison
freetown_comparison_2022 <- tibble(
  unfiltered_mean = mean(fcc_2022_unfiltered$daily_avg, na.rm = TRUE),
  filtered_mean   = mean(fcc_2022_filtered$daily_avg, na.rm = TRUE)
) |> 
  mutate(
    diff_percent = (unfiltered_mean - filtered_mean) / unfiltered_mean * 100
  )

# Time of day & day of week
fcc_2022_tod_dow <- fcc_2022 |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime),
    dow = wday(date, label = TRUE, abbr = TRUE),
    hour = hour(datetime),
    tod = case_when(
      hour >= 6  & hour < 9  ~ "06–08",
      hour >= 9  & hour < 12 ~ "09–11",
      hour >= 12 & hour < 15 ~ "12–14",
      hour >= 15 & hour < 18 ~ "15–17",
      TRUE ~ "Other (Night/Early Morning)"
    )
  )

# Delivery pace by time of day, day of week
fcc_2022_delivery_pace_tod <- fcc_2022_tod_dow |> 
  count(date, tod, enteredby, name = "enum_deliv") |> 
  group_by(tod) |> 
  summarise(avg_daily_pace_tod = mean(enum_deliv), .groups = "drop")

fcc_2022_delivery_pace_dow <- fcc_2022_tod_dow |> 
  count(date, dow, enteredby, name = "enum_deliv") |> 
  group_by(dow) |> 
  summarise(avg_daily_pace_dow = mean(enum_deliv), .groups = "drop")

fcc_2022_delivery_pace_tod_dow <- fcc_2022_tod_dow |> 
  count(date, dow, tod, enteredby, name = "enum_deliv") |> 
  group_by(dow, tod) |> 
  summarise(avg_daily_pace_tod_dow = mean(enum_deliv), .groups = "drop")

# Visualizations

# (a) Time-series plot
fcc_2022_unfiltered |> 
  ggplot(aes(x = date, y = daily_avg)) +
  geom_line(color = "blue", linewidth = 1) +
  geom_point(size = 1.5, color = "black") +
  labs(title = "Average Accurate Daily Deliveries (FCC 2022)", x = "Date", y = "Average Deliveries") 
ggsave("freetown_2022_timeseries.png")

# (b) Histogram + density curve
fcc_2022_unfiltered |> 
  ggplot(aes(x = daily_avg)) +
  geom_histogram(aes(y = after_stat(density)), bins = 15, fill = "pink", alpha = 0.6, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  labs(title = "Distribution of Daily Delivery Pace (FCC 2022)", x = "Deliveries per Day", y = "Density") 
ggsave("freetown_2022_distribution.png")

# (c) Delivery pace by day of week & time of day
fcc_2022_delivery_pace_tod_dow |> 
  ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, fill = tod)) +
  geom_col(position = "dodge") +
  labs(title = "Delivery Pace by Day of Week & Time of Day (FCC 2022)",
       x = "Day of the Week", y = "Average Deliveries per Enumerator", fill = "Time of Day") 
ggsave("freetown_2022_pace_dow_tod.png")


################################################################################
#                        Freetown 2021 Delivery Data                           #
################################################################################

# Loading and cleaning the data: merging the 2 datasets for FCC 2021 (i.e fcc_2021_team_1-3 & fcc_2021_team_4-6)-----
fcc_2021 <- bind_rows(
  read_csv("fcc_2021_team_1-3.csv"),
  read_csv("fcc_2021_team_4-6.csv")
) |> 
  clean_names()

bad_dates <- fcc_2021 |>  # checking which dates failed to parse
  mutate(datetime = dmy_hms(time_delivery_date)) |> 
  filter(is.na(datetime) & !is.na(time_delivery_date)) |> 
  distinct(time_delivery_date)
bad_dates

fcc_2021 <- fcc_2021 |> # cleaning up the time_delivery_date column for uniform format
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    )
  )

fcc_2021 <- fcc_2021 |> # split property_type column values into multiple rows
  separate_rows(property_type, sep = ",\\s*") 

# Transforming: unfiltered data (all deliveries)--------------------------------
fcc_2021_unfiltered <- fcc_2021 |> 
  filter(!is.na(time_delivery_date)) |> 
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime)
  )|> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Transforming: filtered data (accurate deliveries ≤ 0.08 km)-------------------
fcc_2021_filtered <- fcc_2021 |> 
  filter(time_gps_distance_original <= 0.08) |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime)
  ) |> 
  count(date, enteredby, name = "enum_daily_deliv") |> 
  group_by(date) |> 
  summarise(daily_avg = mean(enum_daily_deliv), .groups = "drop") |> 
  mutate(
    Q1 = quantile(daily_avg, 0.25),
    Q3 = quantile(daily_avg, 0.75),
    IQR = Q3 - Q1
  ) |> 
  filter(
    daily_avg >= Q1 - 1.5 * IQR,
    daily_avg <= Q3 + 1.5 * IQR
  )

# Summary statistics
freetown_stats_unfiltered <- fcc_2021_unfiltered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

freetown_stats_filtered <- fcc_2021_filtered |> 
  summarise(
    mean   = mean(daily_avg, na.rm = TRUE),
    median = median(daily_avg, na.rm = TRUE),
    sd     = sd(daily_avg, na.rm = TRUE),
    iqr    = IQR(daily_avg, na.rm = TRUE),
    p80    = quantile(daily_avg, 0.80, na.rm = TRUE),
    p90    = quantile(daily_avg, 0.90, na.rm = TRUE)
  )

# Comparison
freetown_comparison_2021 <- tibble(
  unfiltered_mean = mean(fcc_2021_unfiltered$daily_avg, na.rm = TRUE),
  filtered_mean   = mean(fcc_2021_filtered$daily_avg, na.rm = TRUE)
) |> 
  mutate(
    diff_percent = (unfiltered_mean - filtered_mean) / unfiltered_mean * 100
  )

# Time of day & day of week
fcc_2021_tod_dow <- fcc_2021 |> 
  filter(!is.na(time_delivery_date)) |>
  mutate(
    datetime = parse_date_time(
      time_delivery_date,
      orders = c("dmy HMS", "mdy HMS", "dmy HM", "mdy HM")
    ),
    date = as_date(datetime),
    dow = wday(date, label = TRUE, abbr = TRUE),
    hour = hour(datetime),
    tod = case_when(
      hour >= 6  & hour < 9  ~ "06–08",
      hour >= 9  & hour < 12 ~ "09–11",
      hour >= 12 & hour < 15 ~ "12–14",
      hour >= 15 & hour < 18 ~ "15–17",
      TRUE ~ "Other (Night/Early Morning)"
    )
  )

# Delivery pace by time of day, day of week
fcc_2021_delivery_pace_tod <- fcc_2021_tod_dow |> 
  count(date, tod, enteredby, name = "enum_deliv") |> 
  group_by(tod) |> 
  summarise(avg_daily_pace_tod = mean(enum_deliv), .groups = "drop")

fcc_2021_delivery_pace_dow <- fcc_2021_tod_dow |> 
  count(date, dow, enteredby, name = "enum_deliv") |> 
  group_by(dow) |> 
  summarise(avg_daily_pace_dow = mean(enum_deliv), .groups = "drop")

fcc_2021_delivery_pace_tod_dow <- fcc_2021_tod_dow |> 
  count(date, dow, tod, enteredby, name = "enum_deliv") |> 
  group_by(dow, tod) |> 
  summarise(avg_daily_pace_tod_dow = mean(enum_deliv), .groups = "drop")

# Visualizations

# (a) Time-series plot
fcc_2021_unfiltered |> 
  ggplot(aes(x = date, y = daily_avg)) +
  geom_line(color = "blue", linewidth = 1) +
  geom_point(size = 1.5, color = "black") +
  labs(title = "Average Accurate Daily Deliveries (FCC 2021)", x = "Date", y = "Average Deliveries") 
ggsave("freetown_2021_timeseries.png")

# (b) Histogram + density curve
fcc_2021_unfiltered |> 
  ggplot(aes(x = daily_avg)) +
  geom_histogram(aes(y = after_stat(density)), bins = 15, fill = "pink", alpha = 0.6, color = "black") +
  geom_density(color = "red", linewidth = 1) +
  labs(title = "Distribution of Daily Delivery Pace (FCC 2021)", x = "Deliveries per Day", y = "Density") 
ggsave("freetown_2021_distribution.png")

# (c) Delivery pace by day of week & time of day
fcc_2021_delivery_pace_tod_dow |> 
  ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, fill = tod)) +
  geom_col(position = "dodge") +
  labs(title = "Delivery Pace by Day of Week & Time of Day (FCC 2021)",
       x = "Day of the Week", y = "Average Deliveries per Enumerator", fill = "Time of Day") 
ggsave("freetown_2021_pace_dow_tod.png")



################################################################################
#     Combined Data: Looking at General Delivery Trends & Insights             #
################################################################################

# Filtered vs. unfiltered Data for delivery accuracy insights-------------------

# Adding city & year to unfiltered datasets
makeni_2025_unfiltered   <- mcc_2025_unfiltered   |> mutate(city = "Makeni", year = 2025, dataset = "Unfiltered")
kenema_2025_unfiltered   <- kcc_2025_unfiltered   |> mutate(city = "Kenema", year = 2025, dataset = "Unfiltered")
kenema_2024_unfiltered   <- kcc_2024_unfiltered   |> mutate(city = "Kenema", year = 2024, dataset = "Unfiltered")
freetown_2025_unfiltered <- fcc_2025_unfiltered   |> mutate(city = "Freetown", year = 2025, dataset = "Unfiltered")
freetown_2024_unfiltered <- fcc_2024_unfiltered   |> mutate(city = "Freetown", year = 2024, dataset = "Unfiltered")
freetown_2023_unfiltered <- fcc_2023_unfiltered   |> mutate(city = "Freetown", year = 2023, dataset = "Unfiltered")
freetown_2022_unfiltered <- fcc_2022_unfiltered |> mutate(city = "Freetown", year = 2022, dataset = "Unfiltered")
freetown_2021_unfiltered <- fcc_2021_unfiltered |> mutate(city = "Freetown", year = 2021, dataset = "Unfiltered")


# Adding city & year to filtered datasets
makeni_2025_filtered   <- mcc_2025_filtered   |> mutate(city = "Makeni", year = 2025, dataset = "Filtered")
kenema_2025_filtered   <- kcc_2025_filtered   |> mutate(city = "Kenema", year = 2025, dataset = "Filtered")
kenema_2024_filtered   <- kcc_2024_filtered   |> mutate(city = "Kenema", year = 2024, dataset = "Filtered")
freetown_2025_filtered <- fcc_2025_filtered   |> mutate(city = "Freetown", year = 2025, dataset = "Filtered")
freetown_2024_filtered <- fcc_2024_filtered   |> mutate(city = "Freetown", year = 2024, dataset = "Filtered")
freetown_2023_filtered <- fcc_2023_filtered   |> mutate(city = "Freetown", year = 2023, dataset = "Filtered")
freetown_2022_filtered <- fcc_2022_filtered |> mutate(city = "Freetown", year = 2022, dataset = "Filtered")
freetown_2021_filtered <- fcc_2021_filtered |> mutate(city = "Freetown", year = 2021, dataset = "Filtered")

# Combining all datasets
all_deliveries <- bind_rows(
  makeni_2025_filtered, kenema_2025_filtered, kenema_2024_filtered,
  freetown_2025_filtered, freetown_2024_filtered, freetown_2023_filtered, 
  freetown_2022_filtered, freetown_2021_filtered, makeni_2025_unfiltered, 
  kenema_2025_unfiltered, kenema_2024_unfiltered,freetown_2025_unfiltered, 
  freetown_2024_unfiltered, freetown_2023_unfiltered, freetown_2022_unfiltered, freetown_2021_unfiltered
)

# Summary characteristics by city, year, dataset
summary_all <- all_deliveries |>
  group_by(city, year, dataset) |>
  summarise(
    mean_daily = mean(daily_avg, na.rm = TRUE),
    median_daily = median(daily_avg, na.rm = TRUE),
    p80 = quantile(daily_avg, 0.8, na.rm = TRUE),
    p90 = quantile(daily_avg, 0.9, na.rm = TRUE),
    .groups = "drop"
  )

# Visualizations

# (a) Distribution: filtered vs unfiltered
all_deliveries |>
  ggplot(aes(x = daily_avg, fill = dataset)) +
  geom_histogram(aes(y = after_stat(density)), bins = 20, alpha = 0.5, position = "identity") +
  geom_density(aes(color = dataset), linewidth = 1) +
  facet_grid(year ~ city) +
  labs(
    title = "Distribution of Daily Delivery Pace: Filtered vs Unfiltered",
    x = "Deliveries per Day",
    y = "Density"
  )
  ggsave("filtered vs. unfiltered: comparing_pace_all_cities_distribution.png")

# (b) Summary bar chart
summary_all |>
  ggplot(aes(x = factor(year), y = mean_daily, fill = dataset)) +
  geom_col(position = "dodge") +
  facet_wrap(~city) +
  labs(
    title = "Mean Daily Deliveries: Filtered vs Unfiltered",
    x = "Year",
    y = "Mean Deliveries per Day"
  ) 
  ggsave("filtered vs. unfiltered: comparing_pace_all_cities_bar.png")

    
# Time of Day & Day of Week Insights -------------------------------------------

# Combine all cities and years tod_dow summaries into one dataset
all_delivery_pace_tod_dow <- bind_rows(
  fcc_2021_delivery_pace_tod_dow |> mutate(city = "Freetown", year = 2021),
  fcc_2022_delivery_pace_tod_dow |> mutate(city = "Freetown", year = 2022),
  fcc_2023_delivery_pace_tod_dow |> mutate(city = "Freetown", year = 2023),
  fcc_2024_delivery_pace_tod_dow |> mutate(city = "Freetown", year = 2024),
  fcc_2025_delivery_pace_tod_dow |> mutate(city = "Freetown", year = 2025),
  kcc_2024_delivery_pace_tod_dow |> mutate(city = "Kenema", year = 2024),
  kcc_2025_delivery_pace_tod_dow |> mutate(city = "Kenema", year = 2025),
  mcc_2025_delivery_pace_tod_dow |> mutate(city = "Makeni", year = 2025)
)

all_delivery_pace_tod_dow |> 
  ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, fill = tod)) +
  geom_col(position = "dodge") +
  facet_grid(city ~ year) +
  scale_x_discrete(labels = c("Mon","Tue","Wed","Thu","Fri","Sat","Sun")) +
  labs(
    title = "Delivery Pace by Day of Week & Time of Day (All Cities, All Years)",
    x = "Day of the Week",
    y = "Average Deliveries per Enumerator",
    fill = "Time of Day"
  ) 
ggsave("tod and dow: comparing_pace_all_cities_bar.png")

all_delivery_pace_tod_dow |> 
  ggplot(aes(x = dow, y = avg_daily_pace_tod_dow, color = tod, group = tod)) +
  geom_point(alpha = 0.6) +
  geom_line(linewidth = 1) +
  facet_grid(city ~ year) +
  scale_x_discrete(labels = c("Mon","Tue","Wed","Thu","Fri","Sat","Sun")) +
  labs(
    title = "Delivery Pace Trends by Day of Week & Time of Day",
    x = "Day of the Week",
    y = "Average Deliveries per Enumerator",
    color = "Time of Day"
  ) 
ggsave("tod and dow: comparing_pace_all_cities_trend.png")
