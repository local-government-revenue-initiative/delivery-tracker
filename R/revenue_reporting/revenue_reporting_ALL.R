################################################################################
# VISUAL ANALYSIS OF PROPERTY TAX PAYMENTS
# Multiple Cities, Sierra Leone (2021-2025)
# 
# Author: Robin Benabid Jegaden
# Date: October 2025
# 
# This script creates publication-quality visualizations for multiple cities
################################################################################

# Load required packages
library(tidyverse)
library(lubridate)
library(scales)
library(patchwork)
library(viridis)
library(ggridges)
library(plotly)
library(gganimate)
library(ggthemes)
library(treemapify)
library(ggrepel)
library(cowplot)
library(sf)
library(nnet)
library(broom)
library(stargazer)
library(haven)

# Set global theme
theme_set(theme_minimal(base_size = 12, base_family = "sans"))

# Custom color palette
fcc_colors <- c(
  primary = "#2C3E50",
  secondary = "#E74C3C",
  tertiary = "#27AE60",
  quaternary = "#F39C12",
  quinary = "#8E44AD"
)

# Custom theme for consistency
theme_fcc <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(size = 16, face = "bold", color = fcc_colors["primary"]),
      plot.subtitle = element_text(size = 11, color = "grey40", margin = margin(b = 10)),
      plot.caption = element_text(size = 8, color = "grey50", hjust = 0),
      axis.title = element_text(size = 10, face = "bold"),
      axis.text = element_text(size = 9),
      legend.position = "right",
      legend.title = element_text(size = 10, face = "bold"),
      legend.text = element_text(size = 9),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA)
    )
}

################################################################################
# DEFINE CITIES AND BASE PATHS
################################################################################

cities <- c("Freetown", "Kenema", "Makeni")
base_path <- "D:/Dropbox/LoGRI/Sierra_Leone"

# Define budget targets for 2025 by city
budget_targets <- list(
  Freetown = list(
    property = 40036397.69,
    business = 14055715.39
  ),
  Kenema = list(
    property = 5000000,  # Ajuster selon les vrais budgets
    business = 2000000
  ),
  Makeni = list(
    property = 4000000,  # Ajuster selon les vrais budgets
    business = 1500000
  )
)

################################################################################
# MAIN LOOP FOR EACH CITY
################################################################################

for (city in cities) {
  
  cat("\n", rep("=", 80), "\n", sep = "")
  cat("PROCESSING: ", city, "\n")
  cat(rep("=", 80), "\n\n", sep = "")
  
  # Define paths for current city
  data_path <- file.path(base_path, "data/3_Final/revenue_reporting", city)
  output_path <- file.path(base_path, "output/revenue_reporting", city)
  raw_path <- file.path(base_path, "data/1_Raw/revenue_reporting", city)
  
  # Create output directory if it doesn't exist
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  
  # Load data
  cat("Loading data for", city, "...\n")
  df <- read_dta(file.path(data_path, paste0(city, "_revenue_analysis.dta")))
  
  ################################################################################
  # DATA CLEANING AND PREPARATION
  ################################################################################
  
  df_clean <- df %>%
    mutate(
      date = as.Date(date, origin = "1960-01-01"),
      year = year(date),
      month = month(date, label = TRUE, abbr = TRUE),
      month_num = month(date),
      week = week(date),
      quarter = quarter(date),
      year_month = floor_date(date, "month"),
      year_week = floor_date(date, "week"),
      day_of_year = yday(date),
      bank = str_trim(bank),
      payment_category = case_when(
        payment < 0 ~ "Negative (Refund?)",
        payment <= 100 ~ "0-100 Le",
        payment <= 500 ~ "100-500 Le",
        payment <= 1000 ~ "500-1,000 Le",
        payment <= 5000 ~ "1,000-5,000 Le",
        payment <= 10000 ~ "5,000-10,000 Le",
        TRUE ~ "10,000+ Le"
      ),
      payment_category = factor(payment_category, levels = c(
        "Negative (Refund?)", "0-100 Le", "100-500 Le", "500-1,000 Le",
        "1,000-5,000 Le", "5,000-10,000 Le", "10,000+ Le"
      ))
    ) %>%
    filter(!is.na(payment))
  
  ################################################################################
  # PART 1: TEMPORAL EVOLUTION - ANNUAL ANALYSIS
  ################################################################################
  
  cat("Creating annual visualizations...\n")
  
  annual_summary <- df_clean %>%
    group_by(year, type) %>%
    summarise(
      total_revenue = sum(payment, na.rm = TRUE),
      payment_count = n(),
      avg_payment = mean(payment, na.rm = TRUE),
      median_payment = median(payment, na.rm = TRUE),
      .groups = "drop"
    )
  
  # 1.1 Annual Revenue
  p1 <- ggplot(annual_summary, aes(x = factor(year), y = total_revenue / 1e6, fill = type)) +
    geom_col(alpha = 0.8, width = 0.7, position = "dodge") +
    geom_text(aes(label = paste0(round(total_revenue / 1e6, 2), "M")),
              vjust = -0.5, size = 4, fontface = "bold", position = position_dodge(width = 0.7)) +
    scale_fill_brewer(palette = "Dark2") +
    scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                       expand = expansion(mult = c(0, 0.1))) +
    labs(
      title = paste("Total Revenue by Year -", city),
      subtitle = paste(city, "City Council Property Tax Collection (2021-2025)"),
      x = NULL,
      y = "Total Revenue (Millions Le)",
      caption = paste("Source:", city, "Property Tax Database | Note: Data through December 12, 2025")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "01_annual_revenue.png"), p1, width = 10, height = 6, dpi = 300)
  
  # 1.2 Weekly Time Series by Year
  years <- 2021:2025
  
  for (y in years) {
    weekly_summary_year <- df_clean %>%
      filter(year == y) %>%
      group_by(year_week, type) %>%
      summarise(
        total_revenue = sum(payment, na.rm = TRUE),
        payment_count = n(),
        avg_payment = mean(payment, na.rm = TRUE),
        .groups = "drop"
      )
    
    p_weekly <- ggplot(weekly_summary_year, aes(x = year_week, y = total_revenue / 1e6, 
                                                color = type, fill = type, group = type)) +
      geom_area(alpha = 0.3, position = "identity") +
      geom_line(linewidth = 1) +
      geom_point(size = 2) +
      geom_smooth(method = "loess", se = TRUE, linewidth = 0.8, linetype = "dashed", alpha = 0.05) +
      scale_color_brewer(palette = "Dark2") +
      scale_fill_brewer(palette = "Dark2") +
      scale_x_date(date_breaks = "1 month", date_labels = "%b") +
      scale_y_continuous(labels = label_number(suffix = "M", scale = 1)) +
      labs(
        title = paste0("Weekly Revenue Evolution - ", y, " (", city, ")"),
        subtitle = "Trend analysis with LOESS smoothing by week",
        x = NULL,
        y = "Total Revenue (Millions Le)",
        caption = paste("Source:", city, "Property Tax Database | Dashed line shows smoothed trend")
      ) +
      theme_fcc()
    
    ggsave(file.path(output_path, paste0("04_weekly_revenue_series_", y, ".png")), 
           p_weekly, width = 14, height = 6, dpi = 300)
  }
  
  # 1.3 Annual Payment Count
  p2 <- ggplot(annual_summary, aes(x = factor(year), y = payment_count / 1000, fill = type)) +
    geom_col(alpha = 0.8, width = 0.7, position = "dodge") +
    geom_text(aes(label = paste0(round(payment_count / 1000, 1), "K")),
              vjust = -0.5, size = 4, fontface = "bold", position = position_dodge(width = 0.7)) +
    scale_fill_brewer(palette = "Dark2") +
    scale_y_continuous(labels = label_number(suffix = "K", scale = 1),
                       expand = expansion(mult = c(0, 0.1))) +
    labs(
      title = paste("Number of Payments by Year -", city),
      subtitle = "Annual transaction volume trends",
      x = NULL,
      y = "Number of Payments (Thousands)",
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "02_annual_payment_count.png"), p2, width = 10, height = 6, dpi = 300)
  
  # 1.4 Average Payment by Type Over Time
  p3 <- ggplot(annual_summary, aes(x = factor(year), y = avg_payment / 1000, 
                                   color = type, group = type)) +
    geom_line(size = 1.2) +
    geom_point(size = 3) +
    geom_text(aes(label = paste0(round(avg_payment / 1000, 1), "K")),
              vjust = -1, size = 3.5, fontface = "bold") +
    scale_color_brewer(palette = "Dark2") +
    scale_y_continuous(labels = label_number(suffix = "K", scale = 1),
                       expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = paste("Average Payment by Type Over Time -", city),
      subtitle = "Evolution of mean payment amounts (2021-2025)",
      x = NULL,
      y = "Average Payment (Thousands Le)",
      color = "Type",
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "03_avg_payment_by_type.png"), p3, width = 10, height = 6, dpi = 300)
  
  ################################################################################
  # PART 2: TEMPORAL EVOLUTION - MONTHLY ANALYSIS
  ################################################################################
  
  cat("Creating monthly time series visualizations...\n")
  
  monthly_summary <- df_clean %>%
    group_by(year_month, type) %>%
    summarise(
      total_revenue = sum(payment, na.rm = TRUE),
      payment_count = n(),
      avg_payment = mean(payment, na.rm = TRUE),
      .groups = "drop"
    )
  
  p4 <- ggplot(monthly_summary, aes(x = year_month, y = total_revenue / 1e6, 
                                    color = type, fill = type, group = type)) +
    geom_area(alpha = 0.3, position = "identity") +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    geom_smooth(method = "loess", se = TRUE, linewidth = 0.8, linetype = "dashed", alpha = 0.05) +
    scale_color_brewer(palette = "Dark2") +
    scale_fill_brewer(palette = "Dark2") +
    scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
    scale_y_continuous(labels = label_number(suffix = "M", scale = 1)) +
    labs(
      title = paste("Monthly Revenue Evolution -", city),
      subtitle = "Trend analysis with LOESS smoothing (January 2021 - December 2025)",
      x = NULL,
      y = "Total Revenue (Millions Le)",
      caption = paste("Source:", city, "Property Tax Database | Dashed line shows smoothed trend")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "04_monthly_revenue_series.png"), p4, width = 14, height = 6, dpi = 300)
  
  # Monthly Payment Count
  p5 <- ggplot(monthly_summary, aes(x = year_month, y = payment_count, 
                                    color = type, group = type)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    geom_smooth(method = "loess", se = TRUE, linewidth = 0.8, linetype = "dashed", alpha = 0.05) +
    scale_color_brewer(palette = "Dark2") +
    scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
    scale_y_continuous(labels = label_comma()) +
    labs(
      title = paste("Monthly Payment Count Evolution -", city),
      subtitle = "Transaction volume trends over time",
      x = NULL,
      y = "Number of Payments",
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "05_monthly_count_series.png"), p5, width = 14, height = 6, dpi = 300)
  
  ################################################################################
  # BUDGET COMPARISON FOR 2025
  ################################################################################
  
  cat("Creating budget vs actual revenue comparison for 2025...\n")
  
  # Get budget for current city
  city_budget <- budget_targets[[city]]
  
  budget_2025 <- data.frame(
    type = c("Property Tax", "Business License"),
    budget = c(city_budget$property, city_budget$business)
  )
  
  actual_2025 <- df_clean %>%
    filter(year == 2025) %>%
    group_by(type) %>%
    summarise(actual = sum(payment, na.rm = TRUE), .groups = "drop") %>%
    mutate(type = case_when(
      type == "property" ~ "Property Tax",
      type == "business" ~ "Business License",
      TRUE ~ type
    ))
  
  budget_comparison <- budget_2025 %>%
    left_join(actual_2025, by = "type") %>%
    mutate(
      actual = replace_na(actual, 0),
      remaining = budget - actual,
      pct_achieved = (actual / budget) * 100,
      status = ifelse(pct_achieved >= 100, "Exceeded", "Below Target")
    )
  
  budget_comparison_with_total <- budget_comparison %>%
    bind_rows(
      budget_comparison %>%
        summarise(
          type = "Total",
          budget = sum(budget),
          actual = sum(actual),
          remaining = sum(remaining),
          pct_achieved = (sum(actual) / sum(budget)) * 100,
          status = ifelse(pct_achieved >= 100, "Exceeded", "Below Target")
        )
    ) %>%
    mutate(type = factor(type, levels = c("Property Tax", "Business License", "Total")))
  
  budget_long <- budget_comparison_with_total %>%
    select(type, budget, actual, remaining) %>%
    pivot_longer(cols = c(actual, remaining), names_to = "category", values_to = "amount") %>%
    mutate(category = factor(category, levels = c("remaining", "actual"),
                             labels = c("Remaining", "Collected")))
  
  p_budget <- ggplot(budget_long, aes(x = type, y = amount / 1e6, fill = category)) +
    geom_col(alpha = 0.9, width = 0.6) +
    geom_text(data = budget_comparison_with_total,
              aes(x = type, y = (actual / 1e6) / 2, 
                  label = paste0(format(round(actual / 1e6, 2), big.mark = ","), "M")),
              fontface = "bold", size = 4, color = "white", inherit.aes = FALSE) +
    geom_text(data = budget_comparison_with_total, 
              aes(x = type, y = budget / 1e6, label = paste0(round(pct_achieved, 1), "%\nachieved")),
              vjust = -0.5, fontface = "bold", size = 4, inherit.aes = FALSE) +
    geom_hline(data = budget_comparison_with_total, aes(yintercept = budget / 1e6), 
               linetype = "dashed", color = "black", linewidth = 0.8) +
    scale_fill_manual(values = c("Collected" = "#006400", "Remaining" = "#8B0000"), name = NULL) +
    scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                       expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = paste("2025 Budget Performance: Actual vs Target -", city),
      subtitle = "Revenue collected vs budget targets (January - December 2025)",
      x = NULL,
      y = "Revenue (Millions Le)",
      caption = paste("Source:", city, "Property Tax Database | Dashed line = Budget target")
    ) +
    theme_fcc() +
    theme(legend.position = "top")
  
  ggsave(file.path(output_path, "budget_vs_actual_2025.png"), 
         p_budget, width = 12, height = 7, dpi = 300)
  
  ################################################################################
  # PART 3: SEASONALITY ANALYSIS
  ################################################################################
  
  cat("Creating seasonality visualizations...\n")
  
  seasonal_summary <- df_clean %>%
    group_by(month, type) %>%
    summarise(
      total_revenue = sum(payment, na.rm = TRUE),
      payment_count = n(),
      avg_payment = mean(payment, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(month)
  
  p7 <- ggplot(seasonal_summary, aes(x = month, y = total_revenue / 1e6, fill = total_revenue)) +
    geom_col(show.legend = FALSE) +
    geom_text(aes(label = paste0(round(total_revenue / 1e6, 2), "M")),
              vjust = -0.5, size = 3.5, fontface = "bold") +
    scale_fill_gradient(low = fcc_colors["primary"], high = fcc_colors["secondary"]) +
    scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                       expand = expansion(mult = c(0, 0.15))) +
    facet_wrap(~type, scales = "free_y") +
    labs(
      title = paste("Revenue Seasonality Pattern -", city),
      subtitle = "Total revenue by month (all years combined, 2021-2025)",
      x = NULL,
      y = "Total Revenue (Millions Le)",
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "07_seasonality_revenue.png"), p7, width = 12, height = 6, dpi = 300)
  
  # Heatmap Year × Month
  heatmap_data <- df_clean %>%
    group_by(year, month_num) %>%
    summarise(total_revenue = sum(payment, na.rm = TRUE), .groups = "drop")
  
  p8 <- ggplot(heatmap_data, aes(x = month_num, y = factor(year), fill = total_revenue / 1e6)) +
    geom_tile(color = "white", linewidth = 1) +
    geom_text(aes(label = round(total_revenue / 1e6, 2)), 
              color = "white", fontface = "bold", size = 3.5) +
    scale_fill_viridis_c(option = "plasma", name = "Revenue\n(Millions Le)",
                         labels = label_number(scale = 1)) +
    scale_x_continuous(breaks = 1:12, labels = month.abb, expand = c(0, 0)) +
    scale_y_discrete(expand = c(0, 0)) +
    labs(
      title = paste("Revenue Heatmap: Year × Month -", city),
      subtitle = "Identify peak collection periods and trends",
      x = NULL,
      y = NULL,
      caption = paste("Source:", city, "Property Tax Database | Note: 2025 data through December 12")
    ) +
    theme_fcc() +
    theme(panel.grid = element_blank(), axis.text.x = element_text(angle = 0))
  
  ggsave(file.path(output_path, "08_heatmap_year_month.png"), p8, width = 12, height = 6, dpi = 300)
  
  ################################################################################
  # PART 4: GEOGRAPHIC ANALYSIS - WARDS
  ################################################################################
  
  cat("Creating ward visualizations...\n")
  
  ward_summary <- df_clean %>%
    filter(!is.na(ward) & ward != "") %>%
    group_by(ward) %>%
    summarise(
      total_revenue = sum(payment, na.rm = TRUE),
      payment_count = n(),
      avg_payment = mean(payment, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(total_revenue))
  
  # Top and Bottom 10 Wards by Revenue
  top_bottom_wards <- bind_rows(
    ward_summary %>% slice_head(n = 10) %>% mutate(category = "Top 10"),
    ward_summary %>% slice_tail(n = 10) %>% mutate(category = "Bottom 10")
  )
  
  p10 <- top_bottom_wards %>%
    mutate(ward = fct_reorder(ward, total_revenue),
           category = factor(category, levels = c("Top 10", "Bottom 10"))) %>%
    ggplot(aes(x = total_revenue / 1e6, y = ward, color = category)) +
    geom_segment(aes(x = 0, xend = total_revenue / 1e6, y = ward, yend = ward), linewidth = 1.5) +
    geom_point(size = 5) +
    geom_text(aes(label = paste0(round(total_revenue / 1e6, 2), "M")),
              hjust = -0.3, size = 3.5, fontface = "bold", color = "black") +
    scale_color_manual(values = c("Top 10" = "#006400", "Bottom 10" = "#8B0000")) +
    scale_x_continuous(labels = label_number(suffix = "M", scale = 1),
                       expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = paste("Top 10 and Bottom 10 Wards by Total Revenue -", city),
      subtitle = "Period: 2021-2025",
      x = "Total Revenue (Millions Le)",
      y = NULL,
      color = NULL,
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc() +
    theme(panel.grid.major.y = element_blank())
  
  ggsave(file.path(output_path, "10_top_bottom_wards_revenue.png"), p10, width = 10, height = 10, dpi = 300)
  
  # Top and Bottom 10 Wards by Payment Count
  ward_summary_count <- df_clean %>%
    filter(!is.na(ward) & ward != "") %>%
    group_by(ward) %>%
    summarise(
      total_revenue = sum(payment, na.rm = TRUE),
      payment_count = n(),
      avg_payment = mean(payment, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(payment_count))
  
  top_bottom_wards_count <- bind_rows(
    ward_summary_count %>% slice_head(n = 10) %>% mutate(category = "Top 10"),
    ward_summary_count %>% slice_tail(n = 10) %>% mutate(category = "Bottom 10")
  )
  
  p10_count <- top_bottom_wards_count %>%
    mutate(ward = fct_reorder(ward, payment_count),
           category = factor(category, levels = c("Top 10", "Bottom 10"))) %>%
    ggplot(aes(x = payment_count, y = ward, color = category)) +
    geom_segment(aes(x = 0, xend = payment_count, y = ward, yend = ward), linewidth = 1.5) +
    geom_point(size = 5) +
    geom_text(aes(label = scales::comma(payment_count)),
              hjust = -0.3, size = 3.5, fontface = "bold", color = "black") +
    scale_color_manual(values = c("Top 10" = "#006400", "Bottom 10" = "#8B0000")) +
    scale_x_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = paste("Top 10 and Bottom 10 Wards by Payment Count -", city),
      subtitle = "Period: 2021-2025",
      x = "Number of Payments",
      y = NULL,
      color = NULL,
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc() +
    theme(panel.grid.major.y = element_blank())
  
  ggsave(file.path(output_path, "10_top_bottom_wards_payment_count.png"), 
         p10_count, width = 10, height = 10, dpi = 300)
  
  # Ward Evolution Over Years - Top 10
  ward_year_summary <- df_clean %>%
    filter(!is.na(ward)) %>%
    group_by(ward) %>%
    mutate(ward_total = sum(payment, na.rm = TRUE)) %>%
    ungroup() %>%
    filter(ward %in% (ward_summary %>% slice_head(n = 10) %>% pull(ward))) %>%
    group_by(ward, year) %>%
    summarise(total_revenue = sum(payment, na.rm = TRUE), .groups = "drop")
  
  ward_pct_change <- ward_year_summary %>%
    filter(year %in% c(2021, 2025)) %>%
    pivot_wider(names_from = year, values_from = total_revenue, names_prefix = "year_") %>%
    mutate(
      pct_change = ((year_2025 - year_2021) / year_2021) * 100,
      ward_label = paste0(ward, " (", ifelse(pct_change > 0, "+", ""), round(pct_change, 1), "%)")
    )
  
  ward_year_summary <- ward_year_summary %>%
    left_join(ward_pct_change %>% select(ward, ward_label), by = "ward")
  
  p12 <- ggplot(ward_year_summary, aes(x = factor(year), y = total_revenue / 1e6, fill = ward_label)) +
    geom_col(position = "dodge", alpha = 0.9) +
    scale_fill_viridis_d(option = "turbo", name = "Ward (% change 2021-2025)") +
    scale_y_continuous(labels = label_number(suffix = "M", scale = 1),
                       expand = expansion(mult = c(0, 0.1))) +
    labs(
      title = paste("Annual Revenue Evolution by Ward (Top 10) -", city),
      subtitle = "Year-over-year comparison with % change from 2021 to 2025",
      x = NULL,
      y = "Total Revenue (Millions Le)",
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "12_ward_evolution_years.png"), p12, width = 14, height = 7, dpi = 300)
  
  # Ward Bubble Chart
  p13 <- ward_summary %>%
    ggplot(aes(x = payment_count, y = avg_payment, size = total_revenue, fill = total_revenue)) +
    geom_point(alpha = 0.7, shape = 21, color = "white", stroke = 1) +
    geom_text_repel(aes(label = ward), size = 3, fontface = "bold", max.overlaps = 15) +
    scale_size_continuous(
      range = c(5, 25),
      name = "Total Revenue (Le)",
      labels = label_number(scale_cut = cut_short_scale())
    ) +
    scale_fill_viridis_c(
      option = "plasma",
      name = "Total Revenue (Le)",
      labels = label_number(scale_cut = cut_short_scale())
    ) +
    guides(size = guide_legend(order = 1), fill = guide_legend(order = 1)) +
    scale_x_continuous(labels = label_comma()) +
    scale_y_continuous(labels = label_comma()) +
    labs(
      title = paste("Ward Performance Metrics -", city),
      subtitle = "Payment count vs. average payment (bubble size = total revenue)",
      x = "Number of Payments",
      y = "Average Payment (Le)",
      caption = paste("Source:", city, "Property Tax Database | All wards shown")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "13_ward_bubble_chart.png"), p13, width = 12, height = 8, dpi = 300)
  
  # All Wards by Average Payment
  ward_avg_summary <- df_clean %>%
    filter(!is.na(ward) & ward != "") %>%
    group_by(ward) %>%
    summarise(
      total_revenue = sum(payment, na.rm = TRUE),
      payment_count = n(),
      avg_payment = mean(payment, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(avg_payment))
  
  p_ward_avg <- ward_avg_summary %>%
    mutate(ward = fct_reorder(ward, avg_payment)) %>%
    ggplot(aes(x = avg_payment / 1000, y = ward, color = avg_payment)) +
    geom_segment(aes(x = 0, xend = avg_payment / 1000, y = ward, yend = ward), linewidth = 1.5) +
    geom_point(size = 3) +
    geom_text(aes(label = paste0(round(avg_payment / 1000, 1), "K")),
              hjust = -0.5, size = 3, fontface = "bold", color = "black") +
    scale_color_viridis_c(option = "plasma", guide = "none") +
    scale_x_continuous(labels = label_number(suffix = "K", scale = 1),
                       expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = paste("All Wards by Average Payment -", city),
      subtitle = "Period: 2021-2025",
      x = "Average Payment (Thousands Le)",
      y = NULL,
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc() +
    theme(panel.grid.major.y = element_blank())
  
  ggsave(file.path(output_path, "ward_all_avg_payment.png"), p_ward_avg, width = 10, height = 20, dpi = 300)
  
  ################################################################################
  # PART 5: BANK ANALYSIS
  ################################################################################
  
  cat("Creating bank visualizations...\n")
  
  bank_summary <- df_clean %>%
    filter(!is.na(bank)) %>%
    group_by(bank) %>%
    summarise(
      total_revenue = sum(payment, na.rm = TRUE),
      payment_count = n(),
      avg_payment = mean(payment, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(desc(total_revenue)) %>%
    mutate(percentage = total_revenue / sum(total_revenue) * 100)
  
  bank_colors_dynamic <- viridis::viridis(n = nrow(bank_summary), option = "viridis")
  names(bank_colors_dynamic) <- bank_summary$bank
  
  # Bank Revenue Bar Chart
  p16_bar <- bank_summary %>%
    mutate(bank = fct_reorder(bank, total_revenue)) %>%
    ggplot(aes(x = total_revenue / 1e6, y = bank, fill = bank)) +
    geom_col(alpha = 0.9, show.legend = FALSE) +
    geom_text(aes(label = paste0(round(total_revenue / 1e6, 2), "M")),
              hjust = -0.2, size = 3.5, fontface = "bold") +
    scale_fill_manual(values = bank_colors_dynamic) +
    scale_x_continuous(labels = label_number(suffix = "M", scale = 1),
                       expand = expansion(mult = c(0, 0.15))) +
    labs(
      title = paste("Revenue Collected by Bank -", city),
      subtitle = "Total collection per banking partner (2021-2025)",
      x = "Total Revenue (Millions Le)",
      y = NULL
    ) +
    theme_fcc()
  
  # Donut Chart for Market Share
  p16_donut <- bank_summary %>%
    mutate(ymax = cumsum(percentage),
           ymin = c(0, head(ymax, n = -1)),
           labelPosition = (ymax + ymin) / 2,
           label = paste0(bank, "\n", round(percentage, 1), "%")) %>%
    ggplot(aes(ymax = ymax, ymin = ymin, xmax = 4, xmin = 3, fill = bank)) +
    geom_rect(alpha = 0.9) +
    geom_text(aes(x = 4.5, y = labelPosition, label = label), size = 3.5, fontface = "bold") +
    scale_fill_manual(values = bank_colors_dynamic) +
    coord_polar(theta = "y") +
    xlim(c(2, 4.5)) +
    labs(
      title = "Market Share by Bank",
      subtitle = "Percentage of total revenue"
    ) +
    theme_void() +
    theme(legend.position = "none",
          plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
          plot.subtitle = element_text(hjust = 0.5, size = 11))
  
  p16_combined <- p16_bar + p16_donut + 
    plot_annotation(
      caption = paste("Source:", city, "Property Tax Database"),
      theme = theme(plot.caption = element_text(hjust = 1, size = 9))
    )
  
  ggsave(file.path(output_path, "16_banks_revenue_combined.png"), 
         p16_combined, width = 16, height = 8, dpi = 300)
  
  ################################################################################
  # PART 6: PAYMENT DISTRIBUTION
  ################################################################################
  
  cat("Creating payment distribution visualizations...\n")
  
  p21 <- df_clean %>%
    filter(payment > 0, payment < 50000) %>%
    ggplot(aes(x = payment)) +
    geom_histogram(aes(y = after_stat(density)), bins = 100, 
                   fill = fcc_colors["primary"], alpha = 0.7, color = "white") +
    geom_density(color = fcc_colors["secondary"], linewidth = 1.5) +
    scale_x_log10(labels = label_comma()) +
    labs(
      title = paste("Payment Amount Distribution -", city),
      subtitle = "Histogram with density overlay (0 < payment < 50,000 Le, log scale)",
      x = "Payment Amount (Le, log scale)",
      y = "Density",
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "21_payment_distribution.png"), p21, width = 12, height = 7, dpi = 300)
  
  # Payment Categories Over Time
  payment_cat_time <- df_clean %>%
    filter(payment > 0) %>%
    group_by(year_month, payment_category) %>%
    summarise(payment_count = n(), .groups = "drop")
  
  p22 <- ggplot(payment_cat_time, aes(x = year_month, y = payment_count, fill = payment_category)) +
    geom_area(alpha = 0.8, position = "stack") +
    scale_fill_viridis_d(option = "turbo", name = "Payment\nCategory") +
    scale_x_date(date_breaks = "3 months", date_labels = "%b\n%Y") +
    scale_y_continuous(labels = label_comma()) +
    labs(
      title = paste("Payment Volume by Category Over Time -", city),
      subtitle = "Stacked area chart showing transaction size distribution",
      x = NULL,
      y = "Number of Payments",
      caption = paste("Source:", city, "Property Tax Database")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "22_payment_categories_time.png"), p22, width = 14, height = 7, dpi = 300)
  
  ################################################################################
  # PART 7: CUMULATIVE REVENUE
  ################################################################################
  
  cat("Creating cumulative revenue analysis...\n")
  
  cumulative_data <- df_clean %>%
    group_by(year) %>%
    arrange(date) %>%
    mutate(
      day_of_year = yday(date),
      cumulative_revenue = cumsum(payment)
    ) %>%
    ungroup()
  
  p27 <- ggplot(cumulative_data, aes(x = day_of_year, y = cumulative_revenue / 1e6,
                                     color = factor(year))) +
    geom_line(linewidth = 1.2, alpha = 0.8) +
    scale_color_viridis_d(option = "plasma", name = "Year") +
    scale_x_continuous(breaks = c(1, 91, 182, 274, 365),
                       labels = c("Jan 1", "Apr 1", "Jul 1", "Oct 1", "Dec 31")) +
    scale_y_continuous(labels = label_number(suffix = "M", scale = 1)) +
    labs(
      title = paste("Cumulative Revenue Progression by Year -", city),
      subtitle = "Comparing collection pace across years",
      x = "Day of Year",
      y = "Cumulative Revenue (Millions Le)",
      caption = paste("Source:", city, "Property Tax Database | Note: 2025 data through December 12")
    ) +
    theme_fcc()
  
  ggsave(file.path(output_path, "27_cumulative_revenue.png"), p27, width = 14, height = 7, dpi = 300)
  
  ################################################################################
  # TRY TO LOAD SPATIAL DATA FOR MAPS (if available)
  ################################################################################
  
  tryCatch({
    cat("Attempting to create ward maps...\n")
    
    # Try to find spatial data file
    gpkg_path <- file.path(raw_path, "Ward")
    gpkg_files <- list.files(gpkg_path, pattern = "\\.gpkg$", full.names = TRUE)
    
    if (length(gpkg_files) > 0) {
      wards_spatial <- st_read(gpkg_files[1])
      
      # Average Payment Map
      ward_avg_payment <- df_clean %>%
        filter(!is.na(ward) & ward != "") %>%
        group_by(ward) %>%
        summarise(
          avg_payment = mean(payment, na.rm = TRUE),
          total_revenue = sum(payment, na.rm = TRUE),
          payment_count = n(),
          .groups = "drop"
        )
      
      wards_map <- wards_spatial %>%
        mutate(Ward_No = as.character(Ward_No)) %>%
        left_join(ward_avg_payment, by = c("Ward_No" = "ward"))
      
      sf_use_s2(FALSE)
      wards_centroids <- st_centroid(wards_map, of_largest_polygon = TRUE)
      
      p_ward_map <- ggplot(wards_map) +
        geom_sf(aes(fill = avg_payment / 1000), color = "white", linewidth = 0.3) +
        geom_sf_text(data = wards_centroids, aes(label = Ward_No), 
                     size = 2, color = "white", fontface = "bold") +
        scale_fill_viridis_c(option = "plasma", 
                             name = "Average Payment\n(Thousands Le)",
                             na.value = "grey90",
                             labels = label_number(suffix = "K", scale = 1)) +
        labs(
          title = paste("Average Payment by Ward -", city),
          subtitle = "Geographic distribution of average payments (2021-2025)",
          caption = paste("Source:", city, "Property Tax Database")
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
          plot.subtitle = element_text(size = 12, hjust = 0.5),
          plot.caption = element_text(hjust = 1, size = 9),
          axis.text = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank()
        )
      
      ggsave(file.path(output_path, "ward_map_avg_payment.png"), 
             p_ward_map, width = 12, height = 10, dpi = 300)
      
      # Total Revenue Map
      p_ward_map_revenue <- ggplot(wards_map) +
        geom_sf(aes(fill = total_revenue / 1e6), color = "white", linewidth = 0.3) +
        geom_sf_text(data = wards_centroids, aes(label = Ward_No), 
                     size = 2, color = "white", fontface = "bold") +
        scale_fill_viridis_c(option = "plasma", 
                             name = "Total Revenue\n(Millions Le)",
                             na.value = "grey90",
                             labels = label_number(suffix = "M", scale = 1)) +
        labs(
          title = paste("Total Revenue by Ward -", city),
          subtitle = "Geographic distribution of total revenue (2021-2025)",
          caption = paste("Source:", city, "Property Tax Database")
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
          plot.subtitle = element_text(size = 12, hjust = 0.5),
          plot.caption = element_text(hjust = 1, size = 9),
          axis.text = element_blank(),
          axis.ticks = element_blank(),
          panel.grid = element_blank()
        )
      
      ggsave(file.path(output_path, "ward_map_total_revenue.png"), 
             p_ward_map_revenue, width = 12, height = 10, dpi = 300)
      
      cat("Ward maps created successfully!\n")
    } else {
      cat("No spatial data found for", city, "- skipping ward maps\n")
    }
  }, error = function(e) {
    cat("Could not create ward maps for", city, ":", e$message, "\n")
  })
  
  cat("\n✓", city, "analysis completed successfully!\n")
  cat(rep("=", 80), "\n\n", sep = "")
}

################################################################################
# END OF SCRIPT
################################################################################

cat("\n✓ All cities processed successfully!\n")
cat("================================================================================\n")