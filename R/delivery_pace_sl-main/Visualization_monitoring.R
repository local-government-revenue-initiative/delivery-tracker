#*******************************************************************************
#* Project: Delivery Pace - Analysis Review
#* Author:  Robin Benabid Jegaden
#* Date:    Sep 29, 2025
#* Title:   Visualization_monitoring.R
#* Desc:    Suggestions for Visualization and monitoring
#*******************************************************************************

# Set Up ----
#setwd("D:\Dropbox\LoGRI\Sierra_Leone\code\R\delivery_pace_sl-main")
library(tidyverse)
library(scales)
library(lubridate)
library(prophet)


# ***************
#  Visualization 
# ***************

# 1. Year-over-year growth visualization ---------------------------------------

summary_all <- readRDS("summary_all.rds") 

metric <- "mean_daily"
summary_change <- summary_all |>
  mutate(year = as.integer(year)) |>
  arrange(city, dataset, year) |>
  group_by(city, dataset) |>
  mutate(prev = dplyr::lag(.data[[metric]]),
         pct_change = ifelse(!is.na(prev) & prev != 0,
                             (.data[[metric]] - prev) / prev * 100, NA_real_)) |>
  ungroup()

growth_viz <- summary_change |>
  filter(!is.na(pct_change)) |>
  ggplot(aes(x = year, y = pct_change, color = city)) +
  geom_line(linewidth = 1.5) +
  geom_point(size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed", alpha = 0.5) +
  facet_wrap(~dataset) +
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  labs(title = "Year-over-year growth in delivery performance",
       subtitle = "Comparing filtered vs unfiltered data trends",
       x = "Year", y = "Percentage change from previous year") +
  theme_minimal()

ggsave("yoy_growth_performance.png", growth_viz, width = 10, height = 6, dpi = 300)

# 2. Enumerator performance distribution ---------------------------------------

# mcc_2025 <- read_csv("mcc_2025.csv")|>
#  janitor::clean_names()
#
# performance_dist <- mcc_2025 |>
#  mutate(date = as_date(delivered_on)) |>
#  count(date, mobile_user_username, name = "deliveries") |>
#  ggplot(aes(x = deliveries)) +
#  geom_histogram(bins = 30, fill = "steelblue", alpha = 0.7) +
#  geom_vline(xintercept = c(33, 50), # Proposed targets
#             color = "red", linetype = "dashed") +
#  facet_wrap(~mobile_user_username, scales = "free_y") +
#  labs(
#    title = "Individual Enumerator Performance Distribution",
#    subtitle = "Red lines indicate proposed 2026 targets (33-50 deliveries)",
#    x = "Daily Deliveries",
#    y = "Frequency"
#  )
#
#ggsave("enumerator_performance_distribution.png", performance_dist, width = 12, height = 8, dpi = 300)


# 3.1 Heatmap of performance by day/time by city (year specific) ---------------

all_delivery_pace_tod_dow <- readRDS("all_delivery_pace_tod_dow.rds")

# Define the cities to be plotted.
cities <- c("Freetown", "Kenema", "Makeni")

for (c in cities) {
  
  heatmap_plot <- all_delivery_pace_tod_dow |>
    filter(city == c, year == 2025) |>
    # weekly days ordering
    mutate(dow = factor(dow, levels = c("Mon","Tue","Wed","Thu","Fri","Sat","Sun"))) |>
    ggplot(aes(x = dow, y = tod, fill = avg_daily_pace_tod_dow)) +
    geom_tile(color = "grey80") +
    scale_fill_gradient2(
      low = "blue", mid = "white", high = "red",
      midpoint = median(all_delivery_pace_tod_dow$avg_daily_pace_tod_dow, na.rm = TRUE)
    ) +
    geom_text(aes(label = round(avg_daily_pace_tod_dow, 1)),
              color = "black", size = 3) +
    labs(
      title = paste("Delivery performance heatmap –", c, "2025"),
      x = "Day of week",
      y = "Time of day",
      fill = "Avg deliveries"
    ) +
    theme_minimal()
  
  ggsave(
    paste0(tolower(c), "_2025_heatmap.png"),
    heatmap_plot,
    width = 8, height = 6, dpi = 300
  )
}


# 3.2. Heatmap of performance by day/time all city (average) ------------------- 

all_delivery_pace_tod_dow <- readRDS("all_delivery_pace_tod_dow.rds")

# ordre des axes
tod_levels <- c("06–08","09–11","12–14","15–17","Other (Night/Early Morning)")

city_avg <- all_delivery_pace_tod_dow |>
  group_by(city, dow, tod) |>
  summarise(avg_deliv = mean(avg_daily_pace_tod_dow, na.rm = TRUE), .groups = "drop") |>
  mutate(
    dow = factor(dow, levels = c("Mon","Tue","Wed","Thu","Fri","Sat","Sun")),
    tod = factor(tod, levels = tod_levels)
  )

midpt <- median(city_avg$avg_deliv, na.rm = TRUE)

p <- city_avg |>
  ggplot(aes(x = dow, y = tod, fill = avg_deliv)) +
  geom_tile(color = "grey80") +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red", midpoint = midpt) +
  geom_text(aes(label = round(avg_deliv, 1)), size = 3) +
  facet_wrap(~ city) +
  labs(
    title = "Delivery performance heatmap - multi-year average",
    subtitle = "Average by city, all available years",
    x = "Day of week", y = "Time of day", fill = "Avg deliveries"
  ) +
  theme_minimal()

ggsave("heatmap_multi_year_by_city.png", p, width = 12, height = 8, dpi = 300)


# ***************
# Monitoring
# ***************


# 4. Predictive model ----------------------------------------------------------


#  forecasting_freetown.R

# fcc_2021_unfiltered <- readRDS("fcc_2021_unfiltered.rds")
# fcc_2022_unfiltered <- readRDS("fcc_2022_unfiltered.rds")
# fcc_2023_unfiltered <- readRDS("fcc_2023_unfiltered.rds")
# fcc_2024_unfiltered <- readRDS("fcc_2024_unfiltered.rds")
# fcc_2025_unfiltered <- readRDS("fcc_2025_unfiltered.rds")
# prepare_prophet_data <- function(city_data) {
city_data |>
  select(date, daily_avg) |>
  arrange(date) |>
  rename(ds = date, y = daily_avg)
}

# concatenate the daily series (already aggregated by date in your main script)
#freetown_all <- bind_rows(
#  fcc_2021_unfiltered |> mutate(year = 2021),
#  fcc_2022_unfiltered |> mutate(year = 2022),
#  fcc_2023_unfiltered |> mutate(year = 2023),
#  fcc_2024_unfiltered |> mutate(year = 2024),
#  fcc_2025_unfiltered |> mutate(year = 2025)
#)

# (recommended) fill in the missing dates for Prophet
#full_seq <- tibble(ds = seq(min(freetown_all$date), max(freetown_all$date), by = "day"))
#prophet_data <- prepare_prophet_data(freetown_all) |>
#  right_join(full_seq, by = "ds") |>
#  mutate(y = as.numeric(y))  # NA allowed

# model
#m <- prophet(prophet_data,
#             yearly.seasonality = TRUE,
#             weekly.seasonality = TRUE)  # useful for day/week dynamics
#
#future <- make_future_dataframe(m, periods = 366)   # the entire year 2026
#fcst <- predict(m, future)

# aggregates 2026
#predictions_2026 <- fcst |>
#  filter(year(ds) == 2026) |>
#  summarise(
#    predicted_mean = mean(yhat, na.rm = TRUE),
#    lower_bound    = mean(yhat_lower, na.rm = TRUE),
#    upper_bound    = mean(yhat_upper, na.rm = TRUE)
#  )

# visualization
# png("prophet_freetown_forecast.png", width = 1200, height = 700, res = 150)
# print(plot(m, fcst))
# dev.off()

# png("prophet_freetown_components.png", width = 1200, height = 700, res = 150)
# print(prophet_plot_components(m, fcst))
# dev.off()


# 5. Quality Metrics Dashboard -------------------------------------------------

# mcc_2025_unfiltered <- readRDS("mcc_2025_unfiltered.rds")
# mcc_2025_filtered   <- readRDS("mcc_2025_filtered.rds")
# kcc_2025_unfiltered <- readRDS("kcc_2025_unfiltered.rds")
# kcc_2025_filtered   <- readRDS("kcc_2025_filtered.rds")
# fcc_2025_unfiltered <- readRDS("fcc_2025_unfiltered.rds")
# fcc_2025_filtered   <- readRDS("fcc_2025_filtered.rds")

# Quality dashboard

# create_quality_dashboard <- function(unf_df, fil_df, city_name, year) {
# keep only date + daily_avg and rename
# unf <- unf_df |>
#   select(date, daily_avg) |>
#   rename(daily_unf = daily_avg)
# 
# fil <- fil_df |>
#   select(date, daily_avg) |>
#   rename(daily_fil = daily_avg)
# 
# # joint on date
# both <- full_join(unf, fil, by = "date")
# 
# # global average
# mu_unf <- mean(both$daily_unf, na.rm = TRUE)
# mu_fil <- mean(both$daily_fil, na.rm = TRUE)
# 
# # accuracy rate = share of “accurate” deliveries vs total deliveries (in %)
# accuracy_rate <- if (is.finite(mu_unf) && mu_unf > 0) (mu_fil / mu_unf) * 100 else NA_real_
# #accuracy_rate <- mean(both$daily_fil / both$daily_unf, na.rm = TRUE) * 100
# 
# 
# # metrics on the unfiltered series (consistent with Lorenah current usage)
# cv_unf   <- if (is.finite(mu_unf) && mu_unf != 0) sd(both$daily_unf, na.rm = TRUE) / mu_unf * 100 else NA_real_
# p90_unf  <- quantile(both$daily_unf, 0.90, na.rm = TRUE, names = FALSE)
# p10_unf  <- quantile(both$daily_unf, 0.10, na.rm = TRUE, names = FALSE)
# 
# tibble::tibble(
#   City = city_name,
#   Year = year,
#   `Average Daily Pace (unfiltered)` = mu_unf,
#   `Average Daily Pace (filtered)`   = mu_fil,
#   `Accuracy Rate (%)`               = accuracy_rate,
#   `Consistency (CV, %)`             = cv_unf,
#   `Peak Performance (P90)`          = p90_unf,
#     `Minimum Acceptable (P10)`        = p10_unf
#   )
# }
# 
# Application 2025

# dashboard_data <- dplyr::bind_rows(
#   create_quality_dashboard(mcc_2025_unfiltered, mcc_2025_filtered, "Makeni",   2025),
#   create_quality_dashboard(kcc_2025_unfiltered, kcc_2025_filtered, "Kenema",   2025),
#   create_quality_dashboard(fcc_2025_unfiltered, fcc_2025_filtered, "Freetown", 2025)
# )

# (optional) export
# readr::write_csv(dashboard_data, "quality_dashboard_2025.csv")

